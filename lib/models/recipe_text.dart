/// The editor's text boxes ↔ recipe sections (REC-4–REC-6).
///
/// One ingredient or step per line. A line ending with ":" starts a named
/// group ("للصلصة:"); "ملح: 1 ملعقة" is still an ingredient, because text
/// follows the colon. Lines keep their IDs when their text is unchanged, so
/// a backup merge sees an edit, not a delete and an insert (BAK-3).
///
/// An ingredient line whose text is unchanged also keeps what was read from
/// it; only a line the user edited is parsed again (REC-5). A translated
/// copy's lines (IMP-15) carry the original's amount, range and unit beside
/// text in another language, and saving the copy's preview must never
/// re-read those from the new words.
library;

import 'recipe.dart';

final _heading = RegExp(r'^(.+?)\s*[:：]\s*$');
final _stepNumber = RegExp(r'^\s*(?:[0-9٠-٩]+\s*[-.)،:]|[-•·*▪])\s*');

List<Section<IngredientLine>> ingredientsFromText(
  String text,
  List<Section<IngredientLine>> before,
  String Function() newId,
) {
  final oldLines = [for (final s in before) ...s.items];
  final used = <String>{};
  IngredientLine lineFor(String line) {
    for (final l in oldLines) {
      if (l.original == line && used.add(l.id)) return l;
    }
    return IngredientLine.parse(newId(), line);
  }

  return _group<IngredientLine>(text, before, newId, lineFor);
}

List<Section<RecipeStep>> stepsFromText(
  String text,
  List<Section<RecipeStep>> before,
  String Function() newId,
) {
  final oldSteps = [for (final s in before) ...s.items];
  final used = <String>{};
  return _group<RecipeStep>(text, before, newId, (line) {
    final t = line.replaceFirst(_stepNumber, '').trim();
    for (final s in oldSteps) {
      if (s.text == t && used.add(s.id)) return RecipeStep(id: s.id, text: t);
    }
    return RecipeStep(id: newId(), text: t);
  });
}

String ingredientsToText(List<Section<IngredientLine>> sections) =>
    _toText(sections, (l) => l.original);

String stepsToText(List<Section<RecipeStep>> sections) =>
    _toText(sections, (s) => s.text);

String _toText<T>(List<Section<T>> sections, String Function(T) line) {
  final out = <String>[];
  for (final s in sections) {
    if (s.name != null) {
      if (out.isNotEmpty) out.add('');
      out.add('${s.name}:');
    }
    out.addAll(s.items.map(line));
  }
  return out.join('\n');
}

List<Section<T>> _group<T>(
  String text,
  List<Section<T>> before,
  String Function() newId,
  T Function(String line) item,
) {
  final sections = <Section<T>>[];
  String? name;
  var items = <T>[];
  var index = 0;

  String sectionId(String? name, int index) {
    for (final s in before) {
      if (s.name == name && name != null) return s.id;
    }
    return index < before.length && before[index].name == name
        ? before[index].id
        : newId();
  }

  void close() {
    if (items.isEmpty && name == null) return;
    sections.add(Section(id: sectionId(name, index), name: name, items: items));
    index++;
    items = <T>[];
  }

  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final h = _heading.firstMatch(line);
    if (h != null) {
      close();
      name = h[1]!.trim();
      continue;
    }
    items.add(item(line));
  }
  close();
  // A named group with nothing in it is dropped.
  return sections.where((s) => s.items.isNotEmpty).toList();
}
