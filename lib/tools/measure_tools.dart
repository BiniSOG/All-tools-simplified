import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

/// Subscribes to sensor streams and cleans them up; flags [failed] when the
/// phone lacks the sensor so the tool can say so instead of showing zeros.
mixin SensorSubs<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<dynamic>> _subs = [];
  bool failed = false;

  void sub<E>(Stream<E> Function() open, void Function(E) onData) {
    void fail(Object _) {
      if (mounted) setState(() => failed = true);
    }

    try {
      _subs.add(
        open().listen(
          (e) {
            if (mounted) setState(() => onData(e));
          },
          onError: fail,
          cancelOnError: true,
        ),
      );
    } catch (e) {
      failed = true;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

Widget _missing(String what) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text('This phone does not have $what, so this tool cannot work here.', textAlign: TextAlign.center),
  ),
);

/// Centred, scrollable read-out layout shared by the meter-style tools.
Widget _meter(List<Widget> children) => Center(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: children),
  ),
);

const _huge = TextStyle(fontSize: 56, fontWeight: FontWeight.w300);
const _small = TextStyle(fontSize: 13);

/// Rolling line chart of recent readings.
class _Spark extends CustomPainter {
  _Spark(this.values, this.maxValue, this.color);
  final List<double> values;
  final double maxValue;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), Paint()..color = color.withValues(alpha: 0.1));
    if (values.length < 2) return;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - (values[i] / maxValue).clamp(0.0, 1.0));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_Spark old) => true;
}

// --------------------------------------------------------------------- Ruler
class RulerTool extends StatefulWidget {
  const RulerTool({super.key});
  @override
  State<RulerTool> createState() => _RulerState();
}

class _RulerState extends State<RulerTool> {
  // Screens report only a nominal density, so the scale can be corrected by the user.
  double _scale = (double.tryParse(Store.str('ruler.scale')) ?? 1).clamp(0.6, 1.6);
  bool _calibrating = false;

  @override
  Widget build(BuildContext context) {
    final pxPerMm = 160 / 25.4 * _scale; // logical pixels per millimetre
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: _calibrating
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Hold a bank card against the screen and move the slider until the bar is exactly as wide as the card’s short side (54 mm).', textAlign: TextAlign.center),
                      ),
                      Container(width: 53.98 * pxPerMm, height: 60, color: cs.primary),
                    ],
                  ),
                )
              : CustomPaint(painter: _RulerPainter(pxPerMm, cs.onSurface), size: Size.infinite),
        ),
        Material(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                TextButton(onPressed: () => setState(() => _calibrating = !_calibrating), child: Text(_calibrating ? 'Done' : 'Calibrate')),
                if (_calibrating)
                  Expanded(
                    child: Slider(
                      value: _scale,
                      min: 0.6,
                      max: 1.6,
                      onChanged: (v) {
                        setState(() => _scale = v);
                        Store.setStr('ruler.scale', '$v');
                      },
                    ),
                  )
                else
                  const Expanded(child: Text('cm on the left, inches on the right. Calibrate once for accuracy.', style: _small)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.pxPerMm, this.color);
  final double pxPerMm;
  final Color color;

  void _label(Canvas c, String s, Offset at) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: color, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(0, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const top = 8.0;
    for (var mm = 0; top + mm * pxPerMm < size.height; mm++) {
      final y = top + mm * pxPerMm;
      final len = mm % 10 == 0 ? 34.0 : (mm % 5 == 0 ? 22.0 : 12.0);
      canvas.drawLine(Offset(0, y), Offset(len, y), p);
      if (mm % 10 == 0) _label(canvas, '${mm ~/ 10}', Offset(len + 6, y));
    }
    final pxPerInch = pxPerMm * 25.4;
    for (var i = 0; top + i * pxPerInch / 16 < size.height; i++) {
      final y = top + i * pxPerInch / 16;
      final len = i % 16 == 0 ? 34.0 : (i % 8 == 0 ? 24.0 : (i % 4 == 0 ? 16.0 : 9.0));
      canvas.drawLine(Offset(size.width, y), Offset(size.width - len, y), p);
      if (i % 16 == 0) _label(canvas, '${i ~/ 16}', Offset(size.width - len - 18, y));
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => old.pxPerMm != pxPerMm || old.color != color;
}

// ---------------------------------------------------------------- Protractor
class ProtractorTool extends StatefulWidget {
  const ProtractorTool({super.key});
  @override
  State<ProtractorTool> createState() => _ProtractorState();
}

class _ProtractorState extends State<ProtractorTool> {
  double _deg = 45;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text('${_deg.toStringAsFixed(1)}°', style: _huge),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) {
              final origin = Offset(box.maxWidth / 2, box.maxHeight - 24);
              void drag(Offset p) {
                final v = p - origin;
                if (v.distance < 10) return;
                setState(() => _deg = (atan2(-v.dy, v.dx) * 180 / pi).clamp(0.0, 180.0));
              }

              return GestureDetector(
                onPanDown: (d) => drag(d.localPosition),
                onPanUpdate: (d) => drag(d.localPosition),
                child: CustomPaint(painter: _ProtractorPainter(_deg, cs.primary, cs.onSurface), size: Size.infinite),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Put the corner of the object on the dot at the bottom, one edge along the base line, then drag the arm onto the other edge.', textAlign: TextAlign.center, style: _small),
        ),
      ],
    );
  }
}

class _ProtractorPainter extends CustomPainter {
  _ProtractorPainter(this.deg, this.accent, this.ink);
  final double deg;
  final Color accent, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final o = Offset(size.width / 2, size.height - 24);
    final r = min(size.width / 2 - 12, size.height - 40);
    if (r <= 0) return;
    final line = Paint()
      ..color = ink
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCircle(center: o, radius: r), pi, pi, false, line);
    canvas.drawLine(o - Offset(r, 0), o + Offset(r, 0), line);
    for (var a = 0; a <= 180; a += 5) {
      final rad = a * pi / 180, dir = Offset(cos(rad), -sin(rad));
      final len = a % 30 == 0 ? 18.0 : (a % 10 == 0 ? 12.0 : 6.0);
      canvas.drawLine(o + dir * r, o + dir * (r - len), line);
      if (a % 30 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$a',
            style: TextStyle(color: ink, fontSize: 11),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o + dir * (r - 32) - Offset(tp.width / 2, tp.height / 2));
      }
    }
    final rad = deg * pi / 180;
    canvas.drawArc(Rect.fromCircle(center: o, radius: 44), -rad, rad, true, Paint()..color = accent.withValues(alpha: 0.25));
    canvas.drawLine(
      o,
      o + Offset(cos(rad), -sin(rad)) * r,
      Paint()
        ..color = accent
        ..strokeWidth = 3,
    );
    canvas.drawCircle(o, 6, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_ProtractorPainter old) => old.deg != deg || old.accent != accent || old.ink != ink;
}

// ------------------------------------------------------------------- G-Meter
class GMeterTool extends StatefulWidget {
  const GMeterTool({super.key});
  @override
  State<GMeterTool> createState() => _GMeterState();
}

class _GMeterState extends State<GMeterTool> with SensorSubs {
  double _x = 0, _y = 0, _z = 1, _max = 0;

  @override
  void initState() {
    super.initState();
    sub(() => accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval), (e) {
      _x = e.x / 9.80665;
      _y = e.y / 9.80665;
      _z = e.z / 9.80665;
      _max = max(_max, sqrt(_x * _x + _y * _y + _z * _z));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _missing('a motion sensor');
    final g = sqrt(_x * _x + _y * _y + _z * _z);
    return _meter([
      Text('${g.toStringAsFixed(2)} g', style: _huge),
      Text('Peak ${_max.toStringAsFixed(2)} g'),
      gap(16),
      Row(children: [Stat('X', _x.toStringAsFixed(2)), Stat('Y', _y.toStringAsFixed(2)), Stat('Z', _z.toStringAsFixed(2))]),
      gap(16),
      OutlinedButton(onPressed: () => setState(() => _max = 0), child: const Text('Reset peak')),
      gap(),
      const Text('1 g is normal gravity while the phone is still. Braking, cornering or shaking pushes it higher.', textAlign: TextAlign.center, style: _small),
    ]);
  }
}

// ---------------------------------------------------------------- Vibrometer
class VibrometerTool extends StatefulWidget {
  const VibrometerTool({super.key});
  @override
  State<VibrometerTool> createState() => _VibrometerState();
}

class _VibrometerState extends State<VibrometerTool> with SensorSubs {
  final List<double> _hist = [];
  double _now = 0, _max = 0;

  @override
  void initState() {
    super.initState();
    // "User" acceleration has gravity removed, leaving only movement.
    sub(() => userAccelerometerEventStream(samplingPeriod: SensorInterval.uiInterval), (e) {
      _now = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      _max = max(_max, _now);
      _hist.add(_now);
      if (_hist.length > 120) _hist.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _missing('a motion sensor');
    final label = _now < 0.15 ? 'Still' : (_now < 1 ? 'Light vibration' : (_now < 4 ? 'Strong vibration' : 'Violent shaking'));
    return _meter([
      Text('${_now.toStringAsFixed(2)} m/s²', style: _huge.copyWith(fontSize: 44)),
      Text('$label · peak ${_max.toStringAsFixed(2)}'),
      gap(16),
      SizedBox(
        height: 140,
        width: double.infinity,
        child: CustomPaint(painter: _Spark(_hist, max(2, _max), Theme.of(context).colorScheme.primary)),
      ),
      gap(16),
      OutlinedButton(onPressed: () => setState(() => _max = 0), child: const Text('Reset peak')),
      gap(),
      const Text('Lay the phone on the surface you want to check.', style: _small),
    ]);
  }
}

// -------------------------------------------------------------- Air pressure
class PressureTool extends StatefulWidget {
  const PressureTool({super.key});
  @override
  State<PressureTool> createState() => _PressureState();
}

class _PressureState extends State<PressureTool> with SensorSubs {
  double? _hpa;

  @override
  void initState() {
    super.initState();
    sub(() => barometerEventStream(), (e) => _hpa = e.pressure);
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _missing('a barometer');
    final p = _hpa;
    if (p == null) return const Center(child: Text('Waiting for the pressure sensor…'));
    final trend = p < 1000 ? 'Low pressure — unsettled weather is more likely' : (p > 1020 ? 'High pressure — settled weather is more likely' : 'Normal pressure');
    return _meter([
      Text('${p.toStringAsFixed(1)} hPa', style: _huge.copyWith(fontSize: 46)),
      Text(trend, textAlign: TextAlign.center),
      gap(16),
      Row(children: [Stat('mmHg', (p * 0.750062).toStringAsFixed(1)), Stat('inHg', (p * 0.02953).toStringAsFixed(2)), Stat('atm', (p / 1013.25).toStringAsFixed(3))]),
      gap(),
      Text('Height by pressure: about ${pressureAltitude(p).round()} m', style: _small),
    ]);
  }
}

// ------------------------------------------------------------------ location
/// Opens the GPS stream after checking the service and permission.
/// Returns a user-facing problem description, or null when it is running.
Future<String?> _startGps(void Function(Position) onFix, List<StreamSubscription<dynamic>> into) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Location is switched off. Turn it on in your phone settings.';
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return 'Location permission is needed. Allow it for this app in your phone settings.';
    }
    into.add(Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best)).listen(onFix, onError: (_) {}));
    return null;
  } catch (_) {
    return 'GPS is not available on this device.';
  }
}

// --------------------------------------------------------------- Speedometer
class SpeedometerTool extends StatefulWidget {
  const SpeedometerTool({super.key});
  @override
  State<SpeedometerTool> createState() => _SpeedometerState();
}

class _SpeedometerState extends State<SpeedometerTool> {
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _problem;
  Position? _last;
  double _speed = 0, _max = 0, _dist = 0;
  bool _mph = Store.flag('speed.mph'), _fix = false;

  @override
  void initState() {
    super.initState();
    _startGps(_onFix, _subs).then((p) {
      if (mounted) setState(() => _problem = p);
    });
  }

  void _onFix(Position p) {
    if (!mounted) return;
    setState(() {
      _fix = true;
      // Ignore jitter while standing still and fixes too vague to trust.
      _speed = p.speed.isFinite && p.speed > 0.5 ? p.speed : 0;
      _max = max(_max, _speed);
      final last = _last;
      if (p.accuracy <= 30) {
        if (last != null) {
          final d = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
          if (d > p.accuracy / 2) {
            _dist += d;
            _last = p;
          }
        } else {
          _last = p;
        }
      }
    });
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_problem != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_problem!, textAlign: TextAlign.center),
        ),
      );
    }
    final k = _mph ? 2.23694 : 3.6, unit = _mph ? 'mph' : 'km/h';
    final d = _mph ? _dist / 1609.344 : _dist / 1000;
    return _meter([
      Text((_speed * k).toStringAsFixed(0), style: _huge.copyWith(fontSize: 96)),
      Text(unit, style: const TextStyle(fontSize: 20)),
      gap(16),
      Row(children: [Stat('Top speed', '${(_max * k).toStringAsFixed(0)} $unit'), Stat('Distance', '${d.toStringAsFixed(2)} ${_mph ? 'mi' : 'km'}')]),
      gap(16),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton(
            onPressed: () => setState(() {
              _mph = !_mph;
              Store.setFlag('speed.mph', _mph);
            }),
            child: Text(_mph ? 'Show km/h' : 'Show mph'),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              _max = 0;
              _dist = 0;
              _last = null;
            }),
            child: const Text('Reset trip'),
          ),
        ],
      ),
      gap(),
      Text(_fix ? 'Using GPS. Works best outdoors.' : 'Waiting for a GPS signal… go outside or near a window.', style: _small),
    ]);
  }
}

// ------------------------------------------------------------------ Altitude
class AltitudeTool extends StatefulWidget {
  const AltitudeTool({super.key});
  @override
  State<AltitudeTool> createState() => _AltitudeState();
}

class _AltitudeState extends State<AltitudeTool> {
  final List<StreamSubscription<dynamic>> _subs = [];
  String? _problem;
  double? _gps, _acc, _hpa;

  @override
  void initState() {
    super.initState();
    _startGps((p) {
      if (mounted) {
        setState(() {
          _gps = p.altitude;
          _acc = p.accuracy;
        });
      }
    }, _subs).then((p) {
      if (mounted) setState(() => _problem = p);
    });
    try {
      _subs.add(
        barometerEventStream().listen(
          (e) {
            if (mounted) setState(() => _hpa = e.pressure);
          },
          onError: (_) {},
          cancelOnError: true,
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gps = _gps, hpa = _hpa;
    if (gps == null && hpa == null && _problem != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_problem!, textAlign: TextAlign.center),
        ),
      );
    }
    final shown = gps ?? (hpa == null ? null : pressureAltitude(hpa));
    return _meter([
      Text(shown == null ? '—' : '${shown.round()} m', style: _huge),
      Text(shown == null ? 'Waiting for a GPS signal…' : '${(shown * 3.28084).round()} ft above sea level'),
      gap(16),
      Row(
        children: [
          Stat('GPS', gps == null ? '—' : '${gps.round()} m'),
          Stat('Barometer', hpa == null ? '—' : '${pressureAltitude(hpa).round()} m'),
          Stat('GPS accuracy', _acc == null ? '—' : '±${_acc!.round()} m'),
        ],
      ),
      gap(),
      const Text('GPS height is rough (often ±10–30 m) and needs open sky. The barometer figure assumes standard weather.', textAlign: TextAlign.center, style: _small),
    ]);
  }
}

// ----------------------------------------------------------------------- RPM
class RpmTool extends StatefulWidget {
  const RpmTool({super.key});
  @override
  State<RpmTool> createState() => _RpmState();
}

class _RpmState extends State<RpmTool> {
  final List<int> _taps = [];

  void _tap() {
    HapticFeedback.selectionClick();
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      // A pause of three seconds starts a fresh measurement.
      if (_taps.isNotEmpty && now - _taps.last > 3000) _taps.clear();
      _taps.add(now);
      if (_taps.length > 12) _taps.removeAt(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final rpm = rpmFromTaps(_taps);
    return Column(
      children: [
        Expanded(
          child: InkWell(
            onTap: _tap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rpm == null ? '—' : rpm.toStringAsFixed(0), style: _huge.copyWith(fontSize: 88)),
                  const Text('RPM', style: TextStyle(fontSize: 20)),
                  gap(),
                  Text(rpm == null ? 'Tap once for every full turn' : '${(rpm / 60).toStringAsFixed(2)} turns per second'),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Mark one spot on the spinning object and tap each time it passes. Works for anything slow enough to follow by eye; also handy for music tempo (BPM).',
            textAlign: TextAlign.center,
            style: _small,
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- Steps
class StepsTool extends StatefulWidget {
  const StepsTool({super.key});
  @override
  State<StepsTool> createState() => _StepsState();
}

class _StepsState extends State<StepsTool> with SensorSubs {
  final _det = StepDetector();
  final _height = TextEditingController(text: Store.str('steps.height', '170')), _weight = TextEditingController(text: Store.str('steps.weight', '70'));
  late final String _day = () {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }();
  late int _base = Store.str('steps.day') == _day ? Store.integer('steps.n') : 0;

  @override
  void initState() {
    super.initState();
    sub(() => accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval), (e) {
      if (_det.add(sqrt(e.x * e.x + e.y * e.y + e.z * e.z), DateTime.now().millisecondsSinceEpoch)) {
        Store.setStr('steps.day', _day);
        Store.setInt('steps.n', _base + _det.steps);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _missing('a motion sensor');
    final steps = _base + _det.steps;
    final h = numOf(_height) ?? 170, w = numOf(_weight) ?? 70;
    final km = steps * h * 0.415 / 100000; // stride ≈ 41.5% of height
    final kcal = km * w * 0.75; // rough walking cost per kg per km
    return ToolList(
      children: [
        Panel(
          children: [
            Center(child: Text('$steps', style: _huge.copyWith(fontSize: 72))),
            const Center(child: Text('steps today')),
            gap(),
            Row(children: [Stat('Distance', '${km.toStringAsFixed(2)} km'), Stat('Energy', '${kcal.round()} kcal')]),
            gap(),
            LinearProgressIndicator(value: (steps / 10000).clamp(0.0, 1.0), minHeight: 10, borderRadius: BorderRadius.circular(5)),
            gap(4),
            Text('${(steps / 100).clamp(0, 100).round()}% of a 10,000-step day', style: _small),
          ],
        ),
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: numField(_height, 'Height (cm)', () => setState(() => Store.setStr('steps.height', _height.text)))),
                gap(8),
                Expanded(child: numField(_weight, 'Weight (kg)', () => setState(() => Store.setStr('steps.weight', _weight.text)))),
              ],
            ),
            gap(),
            OutlinedButton(
              onPressed: () => setState(() {
                _base = 0;
                _det.steps = 0;
                Store.setInt('steps.n', 0);
              }),
              child: const Text('Reset today'),
            ),
            gap(8),
            const Text('Steps are counted while this screen is open with the phone in your hand or pocket. Distance and calories are estimates.', style: _small),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Light meter
class LightMeterTool extends StatefulWidget {
  const LightMeterTool({super.key});
  @override
  State<LightMeterTool> createState() => _LightMeterState();
}

class _LightMeterState extends State<LightMeterTool> with SensorSubs {
  double? _lux;
  double _max = 0;

  @override
  void initState() {
    super.initState();
    // Served by a small native handler on Android; iPhones do not expose this sensor.
    sub(() => const EventChannel('toolbox/light').receiveBroadcastStream(), (e) {
      _lux = (e as num).toDouble();
      _max = max(_max, _lux!);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (failed) return _missing('a light sensor that apps can read');
    final lux = _lux;
    if (lux == null) return const Center(child: Text('Waiting for the light sensor…'));
    final label = lux < 10 ? 'Dark' : (lux < 100 ? 'Dim room' : (lux < 500 ? 'Normal indoor light' : (lux < 2000 ? 'Bright room / overcast' : (lux < 20000 ? 'Daylight' : 'Direct sun'))));
    return _meter([
      Text(lux.toStringAsFixed(0), style: _huge.copyWith(fontSize: 80)),
      const Text('lux', style: TextStyle(fontSize: 20)),
      gap(),
      Text('$label · peak ${_max.toStringAsFixed(0)}'),
      gap(16),
      const Text('The sensor is next to the front camera. Reading or desk work is comfortable around 300–500 lux.', textAlign: TextAlign.center, style: _small),
    ]);
  }
}

// ----------------------------------------------------------- Signal strength
class SignalTool extends StatefulWidget {
  const SignalTool({super.key});
  @override
  State<SignalTool> createState() => _SignalState();
}

class _SignalState extends State<SignalTool> {
  static const _ch = MethodChannel('toolbox/wifi');
  Timer? _t;
  int? _rssi;
  bool _supported = true, _asked = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final v = await _ch.invokeMethod<int>('rssi');
      if (mounted) {
        setState(() {
          _rssi = v;
          _asked = true;
        });
      }
    } catch (_) {
      _t?.cancel();
      if (mounted) setState(() => _supported = false);
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('This phone’s system does not let apps read signal strength.', textAlign: TextAlign.center),
        ),
      );
    }
    final r = _rssi;
    if (r == null) return Center(child: Text(_asked ? 'Wi-Fi is off or not connected.' : 'Checking Wi-Fi…'));
    final bars = r >= -55 ? 4 : (r >= -67 ? 3 : (r >= -75 ? 2 : (r >= -85 ? 1 : 0)));
    final cs = Theme.of(context).colorScheme;
    return _meter([
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              width: 26,
              height: 26.0 + i * 22,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: i < bars ? cs.primary : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
            ),
        ],
      ),
      gap(16),
      Text('$r dBm', style: _huge.copyWith(fontSize: 44)),
      Text('Wi-Fi signal: ${rssiLabel(r)}'),
      gap(16),
      const Text('Walk around to find where your Wi-Fi is strongest. Closer to 0 is better; below −80 dBm is unreliable.', textAlign: TextAlign.center, style: _small),
    ]);
  }
}
