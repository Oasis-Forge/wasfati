/// Arabic text helpers shared by the quantity parser (QTY-1) and search
/// (ORG-4). Pure functions, no Flutter imports.
library;

/// Maps Eastern Arabic (٠–٩) and Persian (۰–۹) digits to Western digits, and
/// the Arabic decimal separator (٫) and fraction slash to `.` and `/`.
String westernDigits(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else if (r == 0x066B) {
      out.write('.');
    } else if (r == 0x2044 || r == 0x2215) {
      out.write('/');
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// Normalizes Arabic for matching (ORG-4): drops diacritics and tatweel,
/// unifies alef, taa marbuta, alef maqsura, hamza seats, and lowercases Latin.
String normalizeArabic(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if ((r >= 0x064B && r <= 0x065F) || r == 0x0670 || r == 0x0640) {
      continue; // harakat, superscript alef, tatweel
    }
    if (r == 0x200E || r == 0x200F || (r >= 0x2066 && r <= 0x2069)) {
      continue; // direction marks and isolates
    }
    switch (r) {
      case 0x0623 || 0x0625 || 0x0622 || 0x0671:
        out.writeCharCode(0x0627); // أ إ آ ٱ → ا
      case 0x0629:
        out.writeCharCode(0x0647); // ة → ه
      case 0x0649:
        out.writeCharCode(0x064A); // ى → ي
      case 0x0624:
        out.writeCharCode(0x0648); // ؤ → و
      case 0x0626:
        out.writeCharCode(0x064A); // ئ → ي
      default:
        out.writeCharCode(r);
    }
  }
  return out.toString().toLowerCase();
}

/// The search key (LANG-4, ORG-4): [normalizeArabic], and then what only
/// matching needs, never stored keys (a grocery item's or a tag's): Latin
/// accents and case (é → e, ß → ss), the Turkish dotted and dotless i
/// (İ ı → i), the Persian keyboard's yeh and kaf (ی ک → ي ك), Quranic and
/// other small Arabic marks, and digits in either style (٣ → 3). Applied to
/// both the query and the text.
String searchKey(String s) {
  final out = StringBuffer();
  for (final r in westernDigits(normalizeArabic(s)).runes) {
    if ((r >= 0x0300 && r <= 0x036F) || // combining accents (İ lowers to i̇)
        (r >= 0x0610 && r <= 0x061A) || // Arabic small signs
        (r >= 0x06D6 && r <= 0x06ED)) {
      // Quranic annotation marks
      continue;
    }
    switch (r) {
      case 0x06CC || 0x06D2:
        out.writeCharCode(0x064A); // ی ے → ي
      case 0x06A9:
        out.writeCharCode(0x0643); // ک → ك
      case 0x06C0:
        out.writeCharCode(0x0647); // ۀ → ه
      default:
        out.write(_latinFolds[r] ?? String.fromCharCode(r));
    }
  }
  return out.toString();
}

/// Lowercase Latin letters with an accent, and the letters that fold to two
/// (LANG-4). Uppercase is lowercased first, by [normalizeArabic].
final Map<int, String> _latinFolds = () {
  const groups = {
    'a': 'àáâãäåāăą',
    'c': 'çćĉċč',
    'd': 'ďđð',
    'e': 'èéêëēĕėęě',
    'g': 'ĝğġģ',
    'h': 'ĥħ',
    'i': 'ìíîïĩīĭįı',
    'j': 'ĵ',
    'k': 'ķ',
    'l': 'ĺļľŀł',
    'n': 'ñńņň',
    'o': 'òóôõöøōŏő',
    'r': 'ŕŗř',
    's': 'śŝşš',
    't': 'ţťŧ',
    'u': 'ùúûüũūŭůűų',
    'w': 'ŵ',
    'y': 'ýÿŷ',
    'z': 'źżž',
    'ae': 'æ',
    'oe': 'œ',
    'ss': 'ß',
    'th': 'þ',
  };
  return {
    for (final MapEntry(key: plain, value: accented) in groups.entries)
      for (final r in accented.runes) r: plain,
  };
}();

/// [s] kept left to right inside text of either direction (LANG-5): an
/// amount, a range such as "30–60", or a "×2".
String ltrIsolate(String s) =>
    '${String.fromCharCode(0x2066)}$s${String.fromCharCode(0x2069)}';

/// [s] in its own direction, whatever surrounds it (LANG-5): text the app
/// didn't write, such as a store's price.
String ownIsolate(String s) =>
    '${String.fromCharCode(0x2068)}$s${String.fromCharCode(0x2069)}';

/// Eastern Arabic digits for display (QTY-5), with the Arabic decimal mark
/// between two digits ("1.5" → "١٫٥", LANG-3).
String easternDigits(String s) {
  final out = StringBuffer();
  final runes = s.runes.toList();
  bool digit(int i) =>
      i >= 0 && i < runes.length && runes[i] >= 0x30 && runes[i] <= 0x39;
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (r >= 0x30 && r <= 0x39) {
      out.writeCharCode(0x0660 + r - 0x30);
    } else if (r == 0x2E && digit(i - 1) && digit(i + 1)) {
      out.writeCharCode(0x066B); // ٫
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// Whether [s] has any Arabic letter (the Arabic and Arabic Supplement
/// blocks, and the presentation forms).
bool hasArabic(String s) => s.runes.any(
  (r) =>
      (r >= 0x0600 && r <= 0x06FF) ||
      (r >= 0x0750 && r <= 0x077F) ||
      (r >= 0xFB50 && r <= 0xFDFF) ||
      (r >= 0xFE70 && r <= 0xFEFF),
);
