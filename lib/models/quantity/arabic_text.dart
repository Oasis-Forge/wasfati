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

/// Eastern Arabic digits for display (QTY-5).
String easternDigits(String s) {
  final out = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x30 && r <= 0x39) {
      out.writeCharCode(0x0660 + r - 0x30);
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
