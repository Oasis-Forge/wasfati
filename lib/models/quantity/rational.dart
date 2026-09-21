/// An exact non-negative fraction, so amounts never drift when they are
/// parsed, scaled and shown again (QTY-4).
class Rational implements Comparable<Rational> {
  factory Rational(int numerator, [int denominator = 1]) {
    if (denominator == 0) {
      throw ArgumentError.value(denominator, 'denominator', 'must not be 0');
    }
    if (denominator < 0) {
      numerator = -numerator;
      denominator = -denominator;
    }
    final g = _gcd(numerator.abs(), denominator);
    return Rational._(numerator ~/ g, denominator ~/ g);
  }

  const Rational._(this.numerator, this.denominator);

  /// Parses a plain decimal such as `2.5` exactly, up to 6 places.
  factory Rational.fromDecimal(String text) {
    final parts = text.split('.');
    if (parts.length == 1) return Rational(int.parse(parts[0]));
    final frac = parts[1].length > 6 ? parts[1].substring(0, 6) : parts[1];
    var den = 1;
    for (var i = 0; i < frac.length; i++) {
      den *= 10;
    }
    final whole = parts[0].isEmpty ? 0 : int.parse(parts[0]);
    return Rational(whole * den + int.parse(frac), den);
  }

  static const zero = Rational._(0, 1);
  static const one = Rational._(1, 1);
  static const half = Rational._(1, 2);
  static const quarter = Rational._(1, 4);
  static const threeQuarters = Rational._(3, 4);
  static const third = Rational._(1, 3);
  static const twoThirds = Rational._(2, 3);
  static const eighth = Rational._(1, 8);

  bool operator >(Rational o) => compareTo(o) > 0;
  bool operator <(Rational o) => compareTo(o) < 0;

  // Metric factors for the unit table (SCALE-5): grams per kg, ml per litre,
  // ml per cup, tablespoon and teaspoon.
  static const thousand = Rational._(1000, 1);
  static const cupMl = Rational._(240, 1);
  static const tbspMl = Rational._(15, 1);
  static const tspMl = Rational._(5, 1);

  // QTY-3's oz, lb and fl oz (should-fix, adversary review), already in
  // lowest terms so they stay `const` in the unit table.
  static const ounceGrams = Rational._(45359237, 1600000); // 28.349523125 g
  static const poundGrams = Rational._(45359237, 100000); // 453.59237 g
  static const flOunceMl = Rational._(473176473, 16000000); // 29.5735295625 ml

  final int numerator;
  final int denominator;

  Rational operator +(Rational o) => Rational(
    numerator * o.denominator + o.numerator * denominator,
    denominator * o.denominator,
  );
  Rational operator *(Rational o) =>
      Rational(numerator * o.numerator, denominator * o.denominator);
  Rational operator /(Rational o) =>
      Rational(numerator * o.denominator, denominator * o.numerator);

  double toDouble() => numerator / denominator;
  bool get isWhole => denominator == 1;
  int get whole => numerator ~/ denominator;

  /// Rounds to the nearest multiple of [step], halves rounding up.
  Rational roundTo(Rational step) {
    final q = this / step;
    final n = (q.numerator * 2 + q.denominator) ~/ (q.denominator * 2);
    return Rational(n) * step;
  }

  @override
  int compareTo(Rational o) =>
      (numerator * o.denominator).compareTo(o.numerator * denominator);

  @override
  bool operator ==(Object other) =>
      other is Rational &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => isWhole ? '$numerator' : '$numerator/$denominator';

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = b;
      b = a % b;
      a = t;
    }
    return a == 0 ? 1 : a;
  }
}
