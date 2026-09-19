import 'quantity/arabic_text.dart';

/// Finds cooking durations in a step (COOK-4): "15 دقيقة", "ساعة ونصف",
/// "دقيقتين", "نص ساعة", "10-15 min" (the upper end), "1 hour 20 minutes"
/// (one timer), Eastern Arabic digits too. Returns each once, in order.
List<Duration> findDurations(String text) {
  final tokens = normalizeArabic(westernDigits(text))
      // "و20" is "and 20".
      .replaceAllMapped(RegExp(r'(^|\s)و(?=\d)'), (m) => '${m[1]}و ')
      .split(RegExp(r'[^\p{L}\p{N}.\-–]+', unicode: true))
      .map((t) => t.replaceAll(RegExp(r'\.+$'), '')) // "mins." → "mins"
      .where((t) => t.isNotEmpty)
      .toList();
  final found = <(int start, int end, Duration d)>[];

  for (var i = 0; i < tokens.length; i++) {
    final hit = _durationAt(tokens, i);
    if (hit == null) continue;
    final (end, d) = hit;
    // "1 hour 20 minutes", "ساعة و20 دقيقة": join a smaller unit that
    // follows directly into the same timer.
    if (found.isNotEmpty) {
      final (s, e, prev) = found.last;
      final gap = tokens.sublist(e, i);
      if ((gap.isEmpty || (gap.length == 1 && _and.contains(gap.single))) &&
          d < prev) {
        found[found.length - 1] = (s, end, prev + d);
        i = end - 1;
        continue;
      }
    }
    found.add((i, end, d));
    i = end - 1;
  }
  final seen = <Duration>{};
  return [
    for (final (_, _, d) in found)
      if (d > Duration.zero && d <= const Duration(hours: 24) && seen.add(d)) d,
  ];
}

const _and = {'و', 'and'};

const _minutes = {
  'دقيقه',
  'دقائق',
  'دقايق',
  'دقيقه.',
  'min',
  'mins',
  'minute',
  'minutes',
};
const _hours = {'ساعه', 'ساعات', 'hour', 'hours', 'hr', 'hrs'};
const _seconds = {'ثانيه', 'ثواني', 'ثوان', 'sec', 'secs', 'second', 'seconds'};
const _dualMinutes = {'دقيقتين', 'دقيقتان'};
const _dualHours = {'ساعتين', 'ساعتان'};

/// Words that make a bare unit mean one ("لمدة ساعة", "for an hour").
const _lead = {'لمده', 'مده', 'حوالي', 'تقريبا', 'for', 'about', 'an', 'a'};

const _words = {
  'واحد': 1.0,
  'واحده': 1.0,
  'اثنين': 2.0,
  'ثلاث': 3.0,
  'ثلاثه': 3.0,
  'اربع': 4.0,
  'اربعه': 4.0,
  'خمس': 5.0,
  'خمسه': 5.0,
  'ست': 6.0,
  'سته': 6.0,
  'سبع': 7.0,
  'سبعه': 7.0,
  'عشر': 10.0,
  'عشره': 10.0,
  'عشرين': 20.0,
  'ثلاثين': 30.0,
  'اربعين': 40.0,
  'خمسين': 50.0,
  'ستين': 60.0,
  'نص': 0.5,
  'نصف': 0.5,
  'ربع': 0.25,
};

double? _number(String t) {
  final range = RegExp(r'^(\d+(?:\.\d+)?)[-–](\d+(?:\.\d+)?)$').firstMatch(t);
  if (range != null) return double.parse(range[2]!); // the upper end
  return double.tryParse(t) ?? _words[t];
}

Duration? _unit(String t, double n) {
  if (_minutes.contains(t)) return _of(n * 60);
  if (_hours.contains(t)) return _of(n * 3600);
  if (_seconds.contains(t)) return _of(n);
  return null;
}

Duration _of(double seconds) => Duration(seconds: seconds.round());

/// A duration starting at token [i]: (next index, duration).
(int, Duration)? _durationAt(List<String> t, int i) {
  // Dual forms stand alone: "دقيقتين", "ساعتين ونص".
  if (_dualMinutes.contains(t[i]) || _dualHours.contains(t[i])) {
    final base = _dualHours.contains(t[i]) ? 3600.0 : 60.0;
    var d = _of(2 * base);
    var j = i + 1;
    final half = _halfAt(t, j);
    if (half != null) {
      d += _of(base / 2);
      j = half;
    }
    return (j, d);
  }

  var n = _number(t[i]);
  var j = i + 1;
  if (n != null) {
    // "10 الى 15 دقيقة", "2 أو 3 ساعات": the upper end.
    if (j + 1 < t.length &&
        {'الي', 'او', 'to', 'or', '-', '–'}.contains(t[j])) {
      final upper = _number(t[j + 1]);
      if (upper != null) {
        n = upper;
        j += 2;
      }
    }
    if (j >= t.length) return null;
    final d = _unit(t[j], n);
    if (d == null) return null;
    j++;
    final half = _halfAt(t, j);
    if (half != null) {
      return (half, d + _of(_unitSeconds(t[j - 1]) / 2));
    }
    return (j, d);
  }

  // A bare unit after "لمدة", before "ونص", or before "و20 دقيقة" means
  // one of it.
  final lead = i > 0 && _lead.contains(t[i - 1]);
  final half = _halfAt(t, i + 1);
  final andMore =
      i + 2 < t.length && _and.contains(t[i + 1]) && _number(t[i + 2]) != null;
  if (lead || half != null || andMore) {
    final d = _unit(t[i], 1);
    if (d == null) return null;
    if (half != null) return (half, d + _of(_unitSeconds(t[i]) / 2));
    return (i + 1, d);
  }
  return null;
}

double _unitSeconds(String unit) => _hours.contains(unit)
    ? 3600
    : _minutes.contains(unit)
    ? 60
    : 1;

/// "ونص", "ونصف", "و نص", "and a half": the index after it, or null.
int? _halfAt(List<String> t, int j) {
  if (j < t.length && (t[j] == 'ونص' || t[j] == 'ونصف')) return j + 1;
  if (j + 1 < t.length &&
      t[j] == 'و' &&
      (t[j + 1] == 'نص' || t[j + 1] == 'نصف')) {
    return j + 2;
  }
  if (j + 2 < t.length &&
      t[j] == 'and' &&
      t[j + 1] == 'a' &&
      t[j + 2] == 'half') {
    return j + 3;
  }
  return null;
}

/// "1:30:00" or "15:00", for a timer's remaining time.
String clockText(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
}
