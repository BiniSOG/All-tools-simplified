/// Pure calculation logic, kept free of Flutter imports so it is unit-testable.
library;

import 'dart:math';

/// Formats a number for display: trims float noise, adds thousands separators.
String fmtNum(double n) {
  if (n.isNaN) return '—';
  if (n.isInfinite) return 'Cannot divide by zero';
  final v = double.parse(n.toStringAsPrecision(12));
  final a = v.abs();
  if (a != 0 && (a >= 1e15 || a < 1e-6)) return v.toStringAsExponential(6);
  var s = v.toString();
  if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
  final parts = s.split('.');
  parts[0] = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return parts.join('.');
}

/// Evaluates an arithmetic expression with + - * / % ( ) and unary minus.
/// Throws [FormatException] on malformed input.
double evaluate(String source) {
  final s = source.replaceAll(' ', '');
  var i = 0;
  String peek() => i < s.length ? s[i] : '';
  late double Function() expr;

  double factor() {
    final c = peek();
    double v;
    if (c == '-') {
      i++;
      return -factor();
    }
    if (c == '(') {
      i++;
      v = expr();
      if (peek() == ')') i++;
    } else {
      final st = i;
      while (RegExp(r'[0-9.]').hasMatch(peek())) {
        i++;
      }
      if (st == i) throw const FormatException('number expected');
      v = double.parse(s.substring(st, i));
    }
    while (peek() == '%') {
      i++;
      v /= 100;
    }
    return v;
  }

  double term() {
    var v = factor();
    while (peek() == '*' || peek() == '/') {
      final o = s[i++];
      final r = factor();
      v = o == '*' ? v * r : v / r;
    }
    return v;
  }

  expr = () {
    var v = term();
    while (peek() == '+' || peek() == '-') {
      final o = s[i++];
      final r = term();
      v = o == '+' ? v + r : v - r;
    }
    return v;
  };

  final r = expr();
  if (i < s.length) throw const FormatException('unexpected input');
  return r;
}

/// Unit tables: factor to the category's base unit.
const Map<String, Map<String, double>> units = {
  'Length': {'mm': 0.001, 'cm': 0.01, 'm': 1, 'km': 1000, 'inch': 0.0254, 'foot': 0.3048, 'yard': 0.9144, 'mile': 1609.344},
  'Weight': {'mg': 1e-6, 'g': 0.001, 'kg': 1, 'tonne': 1000, 'ounce': 0.028349523125, 'pound': 0.45359237, 'stone': 6.35029318},
  'Temperature': {'°C': 1, '°F': 1, 'K': 1},
  'Area': {'cm²': 1e-4, 'm²': 1, 'hectare': 1e4, 'km²': 1e6, 'ft²': 0.09290304, 'acre': 4046.8564224},
  'Volume': {'mL': 0.001, 'L': 1, 'm³': 1000, 'teaspoon': 0.00492892159, 'tablespoon': 0.0147867648, 'cup (US)': 0.2365882365, 'gallon (US)': 3.785411784},
  'Speed': {'m/s': 1, 'km/h': 1 / 3.6, 'mph': 0.44704, 'knot': 0.514444},
  'Time': {'second': 1, 'minute': 60, 'hour': 3600, 'day': 86400, 'week': 604800},
  'Data': {'B': 1, 'KB': 1024, 'MB': 1048576, 'GB': 1073741824, 'TB': 1099511627776},
};

double convert(String cat, double v, String from, String to) {
  if (cat == 'Temperature') {
    final c = from == '°C' ? v : (from == '°F' ? (v - 32) * 5 / 9 : v - 273.15);
    return to == '°C' ? c : (to == '°F' ? c * 9 / 5 + 32 : c + 273.15);
  }
  return v * units[cat]![from]! / units[cat]![to]!;
}

double bmi(double kg, double cm) => kg / pow(cm / 100, 2);

/// Monthly instalment for a loan of [principal] at [annualRatePct] over [months].
double emi(double principal, double annualRatePct, int months) {
  if (months <= 0) return double.nan;
  final r = annualRatePct / 12 / 100;
  if (r == 0) return principal / months;
  final f = pow(1 + r, months);
  return principal * r * f / (f - 1);
}

/// Whole years / months / days between two dates ([a] must not be after [b]).
({int years, int months, int days, int totalDays}) dateDiff(DateTime a, DateTime b) {
  var y = b.year - a.year, m = b.month - a.month, d = b.day - a.day;
  if (d < 0) {
    m--;
    d += DateTime(b.year, b.month, 0).day; // days in the month before b
  }
  if (m < 0) {
    y--;
    m += 12;
  }
  final total = DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  return (years: y, months: m, days: d, totalDays: total);
}

const Map<String, String> morseTable = {
  'A': '.-',
  'B': '-...',
  'C': '-.-.',
  'D': '-..',
  'E': '.',
  'F': '..-.',
  'G': '--.',
  'H': '....',
  'I': '..',
  'J': '.---',
  'K': '-.-',
  'L': '.-..',
  'M': '--',
  'N': '-.',
  'O': '---',
  'P': '.--.',
  'Q': '--.-',
  'R': '.-.',
  'S': '...',
  'T': '-',
  'U': '..-',
  'V': '...-',
  'W': '.--',
  'X': '-..-',
  'Y': '-.--',
  'Z': '--..',
  '0': '-----',
  '1': '.----',
  '2': '..---',
  '3': '...--',
  '4': '....-',
  '5': '.....',
  '6': '-....',
  '7': '--...',
  '8': '---..',
  '9': '----.',
  '.': '.-.-.-',
  ',': '--..--',
  '?': '..--..',
  '!': '-.-.--',
  '/': '-..-.',
  '@': '.--.-.',
  '-': '-....-',
  '=': '-...-',
  '+': '.-.-.',
  ':': '---...',
  "'": '.----.',
};

/// Text → Morse. Letters are separated by spaces, words by " / ".
String toMorse(String text) => text.toUpperCase().trim().split(RegExp(r'\s+')).map((w) => w.split('').map((c) => morseTable[c]).whereType<String>().join(' ')).where((w) => w.isNotEmpty).join(' / ');

/// Morse → text. Unknown symbols become "?".
String fromMorse(String code) {
  final rev = {for (final e in morseTable.entries) e.value: e.key};
  return code
      .trim()
      .replaceAll('_', '-')
      .split(RegExp(r'\s*/\s*|\s{2,}'))
      .map((w) => w.trim().split(RegExp(r'\s+')).where((c) => c.isNotEmpty).map((c) => rev[c] ?? '?').join())
      .where((w) => w.isNotEmpty)
      .join(' ');
}

String generatePassword(int length, {bool lower = true, bool upper = true, bool digits = true, bool symbols = false, Random? rng}) {
  final r = rng ?? Random.secure();
  final sets = [if (lower) 'abcdefghijkmnopqrstuvwxyz', if (upper) 'ABCDEFGHJKLMNPQRSTUVWXYZ', if (digits) '23456789', if (symbols) '!@#\$%^&*-_=+?'];
  if (sets.isEmpty || length <= 0) return '';
  final all = sets.join();
  // One character from every selected set, the rest from the union, then shuffle.
  final chars = [for (var i = 0; i < length; i++) i < sets.length ? sets[i][r.nextInt(sets[i].length)] : all[r.nextInt(all.length)]]..shuffle(r);
  return chars.join();
}

/// "m:ss" / "h:mm:ss" clock text, optionally with tenths.
String clockText(int ms, {bool tenths = false}) {
  final t = max(0, ms);
  final h = t ~/ 3600000, m = (t ~/ 60000) % 60, s = (t ~/ 1000) % 60;
  String p2(int n) => n.toString().padLeft(2, '0');
  return '${h > 0 ? '$h:' : ''}${p2(m)}:${p2(s)}${tenths ? '.${(t % 1000) ~/ 100}' : ''}';
}
