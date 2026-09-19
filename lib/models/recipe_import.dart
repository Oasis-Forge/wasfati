import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import 'quantity/arabic_text.dart';

/// A recipe read from a page or text, before the user saves it (IMP-5).
class ImportedRecipe {
  const ImportedRecipe({
    required this.title,
    this.imageUrl,
    this.servings,
    this.prepMinutes,
    this.cookMinutes,
    this.ingredients = const [],
    this.steps = const [],
    this.sourceUrl,
  });

  final String title;
  final String? imageUrl;
  final int? servings;
  final int? prepMinutes;
  final int? cookMinutes;

  /// Groups of ingredient lines, as written (IMP-6, REC-4).
  final List<(String? name, List<String> lines)> ingredients;

  /// Groups of steps (REC-6).
  final List<(String? name, List<String> steps)> steps;
  final String? sourceUrl;
}

/// Reads schema.org `Recipe` data from a page (IMP-2, IMP-11): JSON-LD
/// anywhere (a single object, a list, or inside `@graph`), or microdata.
/// Uses an HTML parser, so an unquoted `type` attribute still works. Returns
/// null when there is no recipe with ingredients: that page needs AI import.
ImportedRecipe? parseRecipePage(String page, Uri url) {
  final doc = html.parse(page);
  for (final script in doc.querySelectorAll('script')) {
    final type = (script.attributes['type'] ?? '').trim().toLowerCase();
    if (type != 'application/ld+json') continue;
    Object? json;
    try {
      json = jsonDecode(script.text.trim());
    } catch (_) {
      continue; // a broken block on the page; try the next one
    }
    final recipe = _findRecipe(json);
    if (recipe != null) {
      final r = _fromJsonLd(recipe, url);
      if (r != null) return r;
    }
  }
  return _fromMicrodata(doc, url);
}

Map<String, Object?>? _findRecipe(Object? json) {
  if (json is List) {
    for (final item in json) {
      final r = _findRecipe(item);
      if (r != null) return r;
    }
  } else if (json is Map) {
    final m = json.cast<String, Object?>();
    final type = m['@type'];
    final isRecipe =
        type == 'Recipe' || (type is List && type.contains('Recipe'));
    if (isRecipe) return m;
    if (m['@graph'] != null) return _findRecipe(m['@graph']);
    if (m['mainEntity'] != null) return _findRecipe(m['mainEntity']);
  }
  return null;
}

ImportedRecipe? _fromJsonLd(Map<String, Object?> r, Uri url) {
  final lines = _strings(r['recipeIngredient'] ?? r['ingredients']);
  if (lines.isEmpty) return null; // no ingredients: not usable (IMP-11)
  final title = _clean(_string(r['name']));
  return ImportedRecipe(
    title: title.isEmpty ? url.host : title,
    imageUrl: _image(r['image'], url),
    servings: parseYield(r['recipeYield']),
    prepMinutes: isoMinutes(_string(r['prepTime'])),
    cookMinutes:
        isoMinutes(_string(r['cookTime'])) ??
        (isoMinutes(_string(r['prepTime'])) == null
            ? isoMinutes(_string(r['totalTime']))
            : null),
    ingredients: groupIngredients(lines),
    steps: _instructions(r['recipeInstructions']),
    sourceUrl: url.toString(),
  );
}

ImportedRecipe? _fromMicrodata(dom.Document doc, Uri url) {
  final scope = doc
      .querySelectorAll('[itemtype]')
      .where(
        (e) => (e.attributes['itemtype'] ?? '').toLowerCase().endsWith(
          'schema.org/recipe',
        ),
      );
  for (final e in scope) {
    String? prop(String name) {
      final p = e.querySelector('[itemprop="$name"]');
      if (p == null) return null;
      return p.attributes['content'] ?? p.text;
    }

    final lines = [
      for (final p in e.querySelectorAll(
        '[itemprop="recipeIngredient"], [itemprop="ingredients"]',
      ))
        _clean(p.attributes['content'] ?? p.text),
    ].where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) continue; // SEO-only markup (mawdoo3 in S2)
    final steps = [
      for (final p in e.querySelectorAll('[itemprop="recipeInstructions"]'))
        ..._splitText(p.text),
    ];
    final img = e.querySelector('[itemprop="image"]');
    return ImportedRecipe(
      title: _clean(prop('name') ?? url.host),
      imageUrl: img == null
          ? null
          : _absolute(img.attributes['src'] ?? img.attributes['content'], url),
      servings: parseYield(prop('recipeYield')),
      prepMinutes: isoMinutes(
        e.querySelector('[itemprop="prepTime"]')?.attributes['content'],
      ),
      cookMinutes: isoMinutes(
        e.querySelector('[itemprop="cookTime"]')?.attributes['content'],
      ),
      ingredients: groupIngredients(lines),
      steps: steps.isEmpty ? const [] : [(null, _splitLong(steps))],
      sourceUrl: url.toString(),
    );
  }
  return null;
}

/// `recipeInstructions` in every shape S2 found: one string (split on line
/// breaks), a list of strings, `HowToStep` items, or `HowToSection` groups
/// (IMP-11). Long steps are split at sentence ends (IMP-6).
List<(String?, List<String>)> _instructions(Object? v) {
  if (v == null) return const [];
  if (v is String) {
    final steps = _splitLong(_splitText(v));
    return steps.isEmpty ? const [] : [(null, steps)];
  }
  if (v is Map) return _instructions([v]);
  if (v is! List) return const [];
  final out = <(String?, List<String>)>[];
  var loose = <String>[];
  for (final item in v) {
    if (item is String) {
      loose.addAll(_splitText(item));
    } else if (item is Map) {
      final m = item.cast<String, Object?>();
      final type = m['@type'];
      if (type == 'HowToSection' || m['itemListElement'] != null) {
        if (loose.isNotEmpty) {
          out.add((null, _splitLong(loose)));
          loose = [];
        }
        final inner = _instructions(m['itemListElement']);
        final steps = [for (final (_, s) in inner) ...s];
        if (steps.isNotEmpty) {
          out.add((_nullIfEmpty(_clean(_string(m['name']))), steps));
        }
      } else {
        loose.addAll(_splitText(_string(m['text'] ?? m['name'])));
      }
    }
  }
  if (loose.isNotEmpty) out.add((null, _splitLong(loose)));
  return out;
}

List<String> _splitText(String text) => [
  for (final l in _clean(text, keepLines: true).split('\n'))
    if (l.trim().isNotEmpty) l.trim(),
];

/// IMP-6: a step over 400 characters is split at sentence ends (. ، ؛ ثم),
/// keeping pieces of roughly 200 characters together.
List<String> _splitLong(List<String> steps, {int max = 400}) => [
  for (final s in steps) ...(s.length <= max ? [s] : splitLongStep(s)),
];

List<String> splitLongStep(String step, {int target = 200}) {
  final pieces = step
      .split(RegExp(r'(?<=[.؛!?])\s+|\s+[,،]\s+|(?<=،)\s+|\s+(?=ثم\s)'))
      .map((p) => p.trim().replaceAll(RegExp(r'^[,،]\s*'), ''))
      .where((p) => p.isNotEmpty)
      .toList();
  final out = <String>[];
  var current = '';
  for (final p in pieces) {
    if (current.isEmpty) {
      current = p;
    } else if (current.length + p.length + 2 <= target) {
      current = '$current، $p'.replaceAll(RegExp(r'[.،]،'), '،');
    } else {
      out.add(current);
      current = p;
    }
  }
  if (current.isNotEmpty) out.add(current);
  return out;
}

/// IMP-6: a line like "مقادير صلصة الدقوس: 1 طماطم، 1 فلفل" becomes a named
/// group with one line per item; a line ending with ":" starts a group.
List<(String?, List<String>)> groupIngredients(List<String> lines) {
  final out = <(String?, List<String>)>[];
  String? name;
  var current = <String>[];
  void close() {
    if (current.isNotEmpty) out.add((name, current));
    current = [];
  }

  for (final raw in lines) {
    final line = _clean(raw);
    if (line.isEmpty) continue;
    final heading = RegExp(r'^(.{2,40}?)\s*[:：]\s*$').firstMatch(line);
    if (heading != null) {
      close();
      name = heading[1]!.trim();
      continue;
    }
    final sub = RegExp(
      r'^((?:مقادير|مكونات|لل|For |for )[^:：]{0,40})[:：]\s*(.+)$',
    ).firstMatch(line);
    if (sub != null && RegExp('[،,]').hasMatch(sub[2]!)) {
      close();
      name = sub[1]!.trim();
      current = [
        for (final part in sub[2]!.split(RegExp(r'\s*[،,]\s*')))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      close();
      name = null;
      continue;
    }
    current.add(line);
  }
  close();
  return out;
}

/// ISO 8601 durations as schema.org writes them: "PT1H30M" → 90.
int? isoMinutes(String? v) {
  if (v == null) return null;
  final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$')
      .firstMatch(v.trim().toUpperCase());
  if (m == null || v.trim().length <= 2) return null;
  int n(int i) => int.tryParse(m[i] ?? '') ?? 0;
  final minutes = n(1) * 1440 + n(2) * 60 + n(3) + (n(4) >= 30 ? 1 : 0);
  return minutes == 0 ? null : minutes;
}

/// "6", "6 servings", "٦ حصص", ["6", "6 حصص"] → 6 (REC-7: 1–100).
int? parseYield(Object? v) {
  if (v is num) return _servings(v.round());
  if (v is List) {
    for (final x in v) {
      final r = parseYield(x);
      if (r != null) return r;
    }
    return null;
  }
  if (v is! String) return null;
  final m = RegExp(r'\d+').firstMatch(westernDigits(v));
  return m == null ? null : _servings(int.parse(m[0]!));
}

int? _servings(int n) => n >= 1 && n <= 100 ? n : null;

const _tracking = {
  'fbclid',
  'gclid',
  'igsh',
  'igshid',
  'si',
  'ref',
  'ref_src',
  'mc_cid',
  'mc_eid',
  'feature',
  'share_id',
  'is_from_webapp',
  'sender_device',
};

/// IMP-9: the same page gets the same URL: no tracking parameters, no
/// "www.", no trailing slash or fragment, https.
String normalizeSourceUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !u.hasAuthority) return url.trim();
  final query = Map.of(u.queryParameters)
    ..removeWhere((k, _) => k.startsWith('utm_') || _tracking.contains(k));
  var path = u.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return Uri(
    scheme: 'https',
    host: u.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
    path: path,
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

/// The first http(s) link in shared text, if any.
String? findUrl(String text) =>
    RegExp(r'https?://[^\s<>"]+')
        .firstMatch(text)?[0]
        ?.replaceAll(RegExp(r'[).,،]+$'), '');

/// IMP-13: shared or pasted text, before AI import exists, becomes a draft
/// to edit: the first line is the title; lines after a heading like
/// "المقادير" are ingredients and after "طريقة التحضير" are steps; with no
/// headings everything goes to the ingredients.
ImportedRecipe draftFromText(String text) {
  final lines = [
    for (final l in text.split(RegExp(r'\r?\n')))
      if (l.trim().isNotEmpty) l.trim(),
  ];
  if (lines.isEmpty) return const ImportedRecipe(title: '');
  final title = lines.first.replaceAll(RegExp(r'[#📌✨🔴]+'), '').trim();
  final ingredients = <String>[];
  final steps = <String>[];
  var into = ingredients;
  final ingHead = RegExp(
    r'^(المقادير|المكونات|مقادير|مكونات|ingredients)(?=$|[\s:：])',
    caseSensitive: false,
  );
  final stepHead = RegExp(
    r'^(طريقه التحضير|طريقة التحضير|طريقه العمل|طريقة العمل|الطريقه|الطريقة|التحضير|method|instructions|directions|steps)(?=$|[\s:：])',
    caseSensitive: false,
  );
  for (final l in lines.skip(1)) {
    final plain = l.replaceAll(RegExp(r'^[^\p{L}]+', unicode: true), '');
    if (ingHead.hasMatch(plain) && plain.length < 30) {
      into = ingredients;
      continue;
    }
    if (stepHead.hasMatch(normalizeArabic(plain)) && plain.length < 30) {
      into = steps;
      continue;
    }
    if (RegExp(r'^#').hasMatch(l)) continue; // hashtags
    into.add(l);
  }
  return ImportedRecipe(
    title: title.length > 120 ? title.substring(0, 120) : title,
    ingredients: ingredients.isEmpty ? const [] : groupIngredients(ingredients),
    steps: steps.isEmpty ? const [] : [(null, _splitLong(steps))],
  );
}

String _string(Object? v) => switch (v) {
  String s => s,
  num n => '$n',
  List l when l.isNotEmpty => _string(l.first),
  Map m => _string(m['@value'] ?? m['text'] ?? m['name']),
  _ => '',
};

List<String> _strings(Object? v) => switch (v) {
  String s => [for (final l in _splitText(s)) l],
  List l => [
    for (final x in l)
      if (_clean(_string(x)).isNotEmpty) _clean(_string(x)),
  ],
  _ => const [],
};

String? _image(Object? v, Uri base) => switch (v) {
  String s => _absolute(s, base),
  List l when l.isNotEmpty => _image(l.first, base),
  Map m => _absolute(_string(m['url'] ?? m['contentUrl']), base),
  _ => null,
};

String? _absolute(String? u, Uri base) {
  if (u == null || u.trim().isEmpty) return null;
  return base.resolve(u.trim()).toString();
}

String? _nullIfEmpty(String s) => s.isEmpty ? null : s;

/// Decodes HTML entities and tidies whitespace.
String _clean(String s, {bool keepLines = false}) {
  var t = s.contains('&') || s.contains('<')
      ? html.parseFragment(s.replaceAll(RegExp(r'<br\s*/?>'), '\n')).text ?? s
      : s;
  t = t.replaceAll('\r\n', '\n').replaceAll(' ', ' ');
  if (!keepLines) t = t.replaceAll('\n', ' ');
  return t
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .trim();
}
