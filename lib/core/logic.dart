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

// ------------------------------------------------------------ measurement

/// Barometric altitude in metres for [hPa], given sea-level pressure [seaLevel].
double pressureAltitude(double hPa, [double seaLevel = 1013.25]) => 44330.0 * (1 - pow(hPa / seaLevel, 0.1903).toDouble());

/// Rotations per minute from the timestamps (ms) of successive taps, one tap per turn.
double? rpmFromTaps(List<int> taps) {
  if (taps.length < 2) return null;
  final span = taps.last - taps.first;
  return span <= 0 ? null : (taps.length - 1) * 60000 / span;
}

/// Counts steps from accelerometer magnitude: a step is a rise through
/// [high] after the signal has fallen below [low], at most one per 280 ms.
class StepDetector {
  StepDetector({this.high = 11.2, this.low = 9.6});
  final double high, low;
  double _smooth = 9.8;
  bool _armed = true;
  int _lastMs = -1000;
  int steps = 0;

  /// Feed one sample; returns true when it completes a step.
  bool add(double magnitude, int timeMs) {
    _smooth += (magnitude - _smooth) * 0.35;
    if (_smooth < low) _armed = true;
    if (_armed && _smooth > high && timeMs - _lastMs > 280) {
      _armed = false;
      _lastMs = timeMs;
      steps++;
      return true;
    }
    return false;
  }
}

/// Beats per minute from evenly sampled brightness values (finger on the lens).
/// Returns null until the signal has a clear, plausible pulse.
double? bpmFromSamples(List<double> v, double samplesPerSecond) {
  if (v.length < samplesPerSecond * 4) return null;
  // Remove slow drift with a one-second moving average, then count upward zero crossings.
  final w = samplesPerSecond.round().clamp(3, v.length);
  final d = <double>[];
  var sum = 0.0;
  for (var i = 0; i < v.length; i++) {
    sum += v[i];
    if (i >= w) sum -= v[i - w];
    d.add(v[i] - sum / min(i + 1, w));
  }
  final amp = d.skip(w).fold<double>(0, (a, b) => max(a, b.abs()));
  if (amp < 0.15) return null; // flat signal: no finger, or not enough light
  final crossings = <int>[];
  for (var i = w + 1; i < d.length; i++) {
    if (d[i - 1] < 0 && d[i] >= 0 && (crossings.isEmpty || i - crossings.last > samplesPerSecond * 0.27)) crossings.add(i);
  }
  if (crossings.length < 4) return null;
  final bpm = (crossings.length - 1) * 60 * samplesPerSecond / (crossings.last - crossings.first);
  return bpm >= 40 && bpm <= 200 ? bpm : null;
}

// ------------------------------------------------------------------ colour

/// Converts one YUV (BT.601) pixel to 8-bit RGB.
(int, int, int) yuvToRgb(int y, int u, int v) {
  final c = y.toDouble(), d = u - 128, e = v - 128;
  int k(double x) => x.round().clamp(0, 255);
  return (k(c + 1.402 * e), k(c - 0.344136 * d - 0.714136 * e), k(c + 1.772 * d));
}

/// CMYK percentages for an RGB colour.
(int, int, int, int) rgbToCmyk(int r, int g, int b) {
  final k = 1 - max(r, max(g, b)) / 255;
  if (k >= 1) return (0, 0, 0, 100);
  int p(int ch) => ((1 - ch / 255 - k) / (1 - k) * 100).round();
  return (p(r), p(g), p(b), (k * 100).round());
}

/// Nearest everyday colour name.
String colorName(int r, int g, int b) {
  const names = <String, List<int>>{
    'Black': [0, 0, 0], 'White': [255, 255, 255], 'Gray': [128, 128, 128], 'Silver': [192, 192, 192], 'Red': [220, 30, 30],
    'Maroon': [128, 0, 0], 'Orange': [255, 140, 0], 'Yellow': [250, 225, 30], 'Olive': [128, 128, 0], 'Lime': [120, 220, 40],
    'Green': [30, 140, 50], 'Teal': [0, 128, 128], 'Cyan': [0, 220, 230], 'Sky blue': [110, 180, 240], 'Blue': [30, 70, 220],
    'Navy': [0, 0, 110], 'Purple': [128, 30, 160], 'Magenta': [230, 30, 200], 'Pink': [250, 160, 190], 'Brown': [130, 80, 40],
    'Beige': [235, 220, 185], //
  };
  var best = '', bestD = 1 << 30;
  names.forEach((n, c) {
    final d = (r - c[0]) * (r - c[0]) + (g - c[1]) * (g - c[1]) + (b - c[2]) * (b - c[2]);
    if (d < bestD) {
      bestD = d;
      best = n;
    }
  });
  return best;
}

// ------------------------------------------------------------------- audio

/// A mono 16-bit WAV file holding [seconds] of a [hz] tone.
/// The length is trimmed to whole cycles so the file loops without a click.
List<int> toneWav(double hz, {double seconds = 2, int rate = 44100, bool square = false, double volume = 0.6}) {
  final cycles = max(1, (hz * seconds).round());
  final n = (cycles * rate / hz).round();
  final data = <int>[];
  for (var i = 0; i < n; i++) {
    final s = sin(2 * pi * cycles * i / n);
    final v = ((square ? (s >= 0 ? 1.0 : -1.0) : s) * volume * 32767).round();
    data
      ..add(v & 0xFF)
      ..add((v >> 8) & 0xFF);
  }
  List<int> le(int v, int bytes) => [for (var i = 0; i < bytes; i++) (v >> (8 * i)) & 0xFF];
  return [
    ...'RIFF'.codeUnits, ...le(36 + data.length, 4), ...'WAVE'.codeUnits, ...'fmt '.codeUnits, ...le(16, 4), ...le(1, 2), ...le(1, 2), //
    ...le(rate, 4), ...le(rate * 2, 4), ...le(2, 2), ...le(16, 2), ...'data'.codeUnits, ...le(data.length, 4), ...data,
  ];
}

/// Slider position 0..1 ↔ frequency on a logarithmic scale (20 Hz – 20 kHz).
double sliderToHz(double t) => 20 * pow(1000, t).toDouble();
double hzToSlider(double hz) => log(hz / 20) / log(1000);

// ----------------------------------------------------------------- billing

class BillItem {
  BillItem(this.name, this.qty, this.price);
  String name;
  double qty, price;
  double get total => qty * price;
  Map<String, dynamic> toJson() => {'n': name, 'q': qty, 'p': price};
  static BillItem fromJson(Map<String, dynamic> j) => BillItem('${j['n']}', (j['q'] as num).toDouble(), (j['p'] as num).toDouble());
}

/// Subtotal, discount amount, tax amount and grand total for a bill.
({double subtotal, double discount, double tax, double total}) billTotals(List<BillItem> items, {double discountPct = 0, double taxPct = 0}) {
  final sub = items.fold<double>(0, (a, i) => a + i.total);
  final disc = sub * discountPct / 100;
  final tax = (sub - disc) * taxPct / 100;
  return (subtotal: sub, discount: disc, tax: tax, total: sub - disc + tax);
}

String money(double v) => fmtNum(double.parse(v.toStringAsFixed(2)));

// ----------------------------------------------------------------- network

/// Megabits per second for [bytes] moved in [ms].
double mbps(int bytes, int ms) => ms <= 0 ? 0 : bytes * 8 / 1e6 / (ms / 1000);

/// Makes a file name from another device safe to save: no folders, no odd characters.
String safeFileName(String raw) {
  var n = raw.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[^\w.\- ()]'), '_').trim();
  n = n.replaceAll(RegExp(r'^\.+'), '');
  if (n.length > 120) n = n.substring(n.length - 120);
  return n.isEmpty ? 'file' : n;
}

String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

/// Wi-Fi signal quality label for an RSSI in dBm.
String rssiLabel(int dbm) => dbm >= -55 ? 'Excellent' : (dbm >= -67 ? 'Good' : (dbm >= -75 ? 'Fair' : (dbm >= -85 ? 'Weak' : 'Very weak')));
