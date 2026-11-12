import 'dart:async';
import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../core/store.dart';
import '../core/ui.dart';
import 'text_tools.dart' show Torch;

// ---------------------------------------------------------------- Flashlight
class FlashlightTool extends StatefulWidget {
  const FlashlightTool({super.key});
  @override
  State<FlashlightTool> createState() => _FlashlightState();
}

class _FlashlightState extends State<FlashlightTool> {
  bool _on = false, _led = true;
  Color _screen = Colors.white;

  @override
  void dispose() {
    if (_on) Torch.set(false);
    super.dispose();
  }

  Future<void> _toggle() async {
    final want = !_on;
    final ok = await Torch.set(want);
    if (!mounted) return;
    // No LED (or an old Android version): light the screen instead.
    setState(() {
      _on = want;
      _led = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenLight = _on && !_led;
    return Container(
      color: screenLight ? _screen : null,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _on ? Colors.amber : Colors.grey.shade700,
                boxShadow: [if (_on) const BoxShadow(color: Colors.amber, blurRadius: 40)],
              ),
              child: Icon(_on ? Icons.flashlight_on : Icons.flashlight_off, size: 64, color: Colors.white),
            ),
          ),
          gap(20),
          Text(!_on ? 'Tap to turn on' : (_led ? 'Camera light is on' : 'Using the screen as a light'), style: TextStyle(color: screenLight ? Colors.black54 : null)),
          if (screenLight) ...[
            gap(),
            Wrap(
              spacing: 10,
              children: [
                for (final c in [Colors.white, Colors.red, Colors.yellow, Colors.lightBlueAccent])
                  GestureDetector(
                    onTap: () => setState(() => _screen = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black38),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------- shared sensor plumbing
mixin _Sensors<T extends StatefulWidget> on State<T> {
  final List<StreamSubscription<dynamic>> _subs = [];
  bool sensorError = false;
  List<double> acc = [0, 0, 9.8], mag = [0, 0, 0];

  // Low-pass filter so needles and bubbles do not jitter.
  List<double> _mix(List<double> o, double x, double y, double z) => [o[0] + (x - o[0]) * 0.15, o[1] + (y - o[1]) * 0.15, o[2] + (z - o[2]) * 0.15];

  void listen({bool accelerometer = false, bool magnetometer = false}) {
    void fail(Object _) {
      if (mounted) setState(() => sensorError = true);
    }

    try {
      if (accelerometer) {
        _subs.add(accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) => setState(() => acc = _mix(acc, e.x, e.y, e.z)), onError: fail, cancelOnError: true));
      }
      if (magnetometer) {
        _subs.add(magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) => setState(() => mag = _mix(mag, e.x, e.y, e.z)), onError: fail, cancelOnError: true));
      }
    } catch (e) {
      sensorError = true;
    }
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Widget unavailable(String what) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text('This phone does not have $what, so this tool cannot work here.', textAlign: TextAlign.center),
    ),
  );
}

/// Tilt-compensated compass heading in degrees (0 = north), or null if unknown.
double? headingFrom(List<double> a, List<double> m) {
  // East = M × A, North = A × East (same construction as Android's rotation matrix).
  final hx = m[1] * a[2] - m[2] * a[1], hy = m[2] * a[0] - m[0] * a[2], hz = m[0] * a[1] - m[1] * a[0];
  final hn = sqrt(hx * hx + hy * hy + hz * hz), an = sqrt(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);
  if (hn < 1e-6 || an < 1e-6) return null;
  final ey = hy / hn;
  final ny = (a[2] * hx - a[0] * hz) / (an * hn);
  return (atan2(ey, ny) * 180 / pi + 360) % 360;
}

// ------------------------------------------------------------------- Compass
class CompassTool extends StatefulWidget {
  const CompassTool({super.key});
  @override
  State<CompassTool> createState() => _CompassState();
}

class _CompassState extends State<CompassTool> with _Sensors {
  @override
  void initState() {
    super.initState();
    listen(accelerometer: true, magnetometer: true);
  }

  @override
  Widget build(BuildContext context) {
    if (sensorError) return unavailable('a compass sensor');
    final h = headingFrom(acc, mag);
    const names = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(h == null ? '—' : '${h.round()}° ${names[((h + 22.5) ~/ 45) % 8]}', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w300)),
            gap(16),
            Center(
              child: SizedBox(
                width: 260,
                height: 260,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.rotate(
                      angle: -(h ?? 0) * pi / 180,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: cs.primary, width: 4),
                          color: cs.surfaceContainerHighest,
                        ),
                        child: Stack(
                          children: [
                            for (final d in const [('N', Alignment.topCenter), ('E', Alignment.centerRight), ('S', Alignment.bottomCenter), ('W', Alignment.centerLeft)])
                              Align(
                                alignment: d.$2,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Text(
                                    d.$1,
                                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: d.$1 == 'N' ? Colors.red : null),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Icon(Icons.navigation, size: 64, color: cs.primary),
                  ],
                ),
              ),
            ),
            gap(16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Hold the phone flat. If it looks off, wave it in a figure-8 and keep it away from magnets and metal.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Level
class LevelTool extends StatefulWidget {
  const LevelTool({super.key});
  @override
  State<LevelTool> createState() => _LevelState();
}

class _LevelState extends State<LevelTool> with _Sensors {
  @override
  void initState() {
    super.initState();
    listen(accelerometer: true);
  }

  @override
  Widget build(BuildContext context) {
    if (sensorError) return unavailable('a motion sensor');
    final g = sqrt(acc[0] * acc[0] + acc[1] * acc[1] + acc[2] * acc[2]);
    final nx = g == 0 ? 0.0 : (acc[0] / g).clamp(-1.0, 1.0), ny = g == 0 ? 0.0 : (acc[1] / g).clamp(-1.0, 1.0);
    final tiltX = asin(nx) * 180 / pi, tiltY = asin(ny) * 180 / pi;
    final level = tiltX.abs() < 1 && tiltY.abs() < 1;
    final color = level ? Colors.green : Colors.orange;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text('X ${tiltX.toStringAsFixed(1)}°   Y ${tiltY.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w300)),
            gap(16),
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(color: color, width: 4),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2),
                      ),
                    ),
                    // The bubble floats to the high side, like a real spirit level.
                    Align(
                      alignment: Alignment((nx * 3).clamp(-1.0, 1.0), (-ny * 3).clamp(-1.0, 1.0)),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            gap(16),
            Text(level ? 'Level!' : 'Lay the phone flat on the surface', style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Metal detector
class MetalTool extends StatefulWidget {
  const MetalTool({super.key});
  @override
  State<MetalTool> createState() => _MetalState();
}

class _MetalState extends State<MetalTool> with _Sensors {
  @override
  void initState() {
    super.initState();
    listen(magnetometer: true);
  }

  @override
  Widget build(BuildContext context) {
    if (sensorError) return unavailable('a magnetic sensor');
    final ut = sqrt(mag[0] * mag[0] + mag[1] * mag[1] + mag[2] * mag[2]);
    // Earth's field is roughly 25–65 µT; well above that means metal or a magnet is near.
    final strong = ut > 80;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${ut.toStringAsFixed(0)} µT',
          style: TextStyle(fontSize: 56, fontWeight: FontWeight.w300, color: strong ? Colors.red : null),
        ),
        gap(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: (ut / 200).clamp(0.0, 1.0), minHeight: 18, color: strong ? Colors.red : Colors.green),
          ),
        ),
        gap(16),
        Text(strong ? 'Metal or a magnet is close!' : 'Move the top of the phone near an object', style: const TextStyle(fontSize: 15)),
        gap(),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Reads the magnetic field, so it reacts to iron and steel but not to gold, silver or aluminium.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- Random
class RandomTool extends StatefulWidget {
  const RandomTool({super.key});
  @override
  State<RandomTool> createState() => _RandomState();
}

class _RandomState extends State<RandomTool> {
  final _r = Random();
  final _min = TextEditingController(text: '1'), _max = TextEditingController(text: '100');
  List<int> _dice = [1, 1];
  String _coin = '—', _num = '—';

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          const Text('Dice', style: TextStyle(fontWeight: FontWeight.w600)),
          gap(8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _dice)
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Text('$d', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          gap(8),
          Center(child: Text('Total: ${_dice.fold(0, (a, b) => a + b)}')),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline), tooltip: 'Fewer dice', onPressed: _dice.length > 1 ? () => setState(() => _dice.removeLast()) : null),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _dice = [for (final _ in _dice) _r.nextInt(6) + 1]);
                  },
                  child: const Text('Roll'),
                ),
              ),
              IconButton(icon: const Icon(Icons.add_circle_outline), tooltip: 'More dice', onPressed: _dice.length < 6 ? () => setState(() => _dice.add(1)) : null),
            ],
          ),
        ],
      ),
      Panel(
        children: [
          const Text('Coin', style: TextStyle(fontWeight: FontWeight.w600)),
          Center(child: Text(_coin, style: const TextStyle(fontSize: 30))),
          gap(8),
          FilledButton(onPressed: () => setState(() => _coin = _r.nextBool() ? 'Heads' : 'Tails'), child: const Text('Flip')),
        ],
      ),
      Panel(
        children: [
          const Text('Number', style: TextStyle(fontWeight: FontWeight.w600)),
          gap(8),
          Row(
            children: [
              Expanded(child: numField(_min, 'From', () {})),
              gap(8),
              Expanded(child: numField(_max, 'To', () {})),
            ],
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_num, style: const TextStyle(fontSize: 30)),
            ),
          ),
          FilledButton(
            onPressed: () {
              final a = numOf(_min)?.round(), b = numOf(_max)?.round();
              if (a == null || b == null) return toast(context, 'Enter both numbers');
              final lo = min(a, b), hi = max(a, b);
              setState(() => _num = '${lo + _r.nextInt(hi - lo + 1)}');
            },
            child: const Text('Pick'),
          ),
        ],
      ),
    ],
  );
}

// ------------------------------------------------------------- Tally counter
class CounterTool extends StatefulWidget {
  const CounterTool({super.key});
  @override
  State<CounterTool> createState() => _CounterState();
}

class _CounterState extends State<CounterTool> {
  int _n = Store.integer('counter');

  void _set(int v) {
    HapticFeedback.selectionClick();
    setState(() => _n = v);
    Store.setInt('counter', v);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: InkWell(
          onTap: () => _set(_n + 1),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$_n', style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w200)),
                const Text('Tap anywhere to count'),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(onPressed: () => _set(0), child: const Text('Reset')),
            ),
            gap(8),
            Expanded(
              child: OutlinedButton(onPressed: () => _set(_n - 1), child: const Text('−1')),
            ),
          ],
        ),
      ),
    ],
  );
}

// --------------------------------------------------------------------- Color
class ColorTool extends StatefulWidget {
  const ColorTool({super.key});
  @override
  State<ColorTool> createState() => _ColorState();
}

class _ColorState extends State<ColorTool> {
  double _r = 63, _g = 81, _b = 181;

  @override
  Widget build(BuildContext context) {
    final c = Color.fromARGB(255, _r.round(), _g.round(), _b.round());
    final hsl = HSLColor.fromColor(c);
    String h2(double v) => v.round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final hex = '#${h2(_r)}${h2(_g)}${h2(_b)}';
    Widget slider(String l, double v, Color col, ValueChanged<double> f) => Row(
      children: [
        SizedBox(width: 20, child: Text(l)),
        Expanded(
          child: Slider(value: v, max: 255, activeColor: col, onChanged: (x) => setState(() => f(x))),
        ),
        SizedBox(width: 34, child: Text('${v.round()}', textAlign: TextAlign.end)),
      ],
    );
    return ToolList(
      children: [
        Panel(
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26),
              ),
            ),
            gap(),
            slider('R', _r, Colors.red, (x) => _r = x),
            slider('G', _g, Colors.green, (x) => _g = x),
            slider('B', _b, Colors.blue, (x) => _b = x),
            ResultBox(hex, sub: 'rgb(${_r.round()}, ${_g.round()}, ${_b.round()}) · hsl(${hsl.hue.round()}, ${(hsl.saturation * 100).round()}%, ${(hsl.lightness * 100).round()}%)'),
            gap(),
            FilledButton.icon(onPressed: () => copyText(context, hex), icon: const Icon(Icons.copy), label: const Text('Copy hex code')),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------- Paint
class PaintTool extends StatefulWidget {
  const PaintTool({super.key});
  @override
  State<PaintTool> createState() => _PaintState();
}

class _Stroke {
  _Stroke(this.color, this.width);
  final Color color;
  final double width;
  final List<Offset> points = [];
}

class _PaintState extends State<PaintTool> {
  static const _colors = [Colors.black, Colors.red, Colors.orange, Colors.green, Colors.blue, Colors.purple, Colors.white];
  final List<_Stroke> _strokes = [];
  final _repaint = ValueNotifier(0);
  Color _color = Colors.black;
  double _width = 4;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.black26),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: GestureDetector(
              onPanStart: (d) {
                _strokes.add(_Stroke(_color, _width)..points.add(d.localPosition));
                _repaint.value++;
              },
              onPanUpdate: (d) {
                _strokes.last.points.add(d.localPosition);
                _repaint.value++;
              },
              child: CustomPaint(painter: _PaintPainter(_strokes, _repaint), size: Size.infinite),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final c in _colors)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == c ? Theme.of(context).colorScheme.primary : Colors.black26, width: _color == c ? 3 : 1),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.line_weight, size: 20),
                Expanded(
                  child: Slider(value: _width, min: 2, max: 24, onChanged: (v) => setState(() => _width = v)),
                ),
                IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  onPressed: () {
                    if (_strokes.isNotEmpty) _strokes.removeLast();
                    _repaint.value++;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Clear',
                  onPressed: () {
                    _strokes.clear();
                    _repaint.value++;
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _PaintPainter extends CustomPainter {
  _PaintPainter(this.strokes, Listenable repaint) : super(repaint: repaint);
  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      final p = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawPoints(PointMode.points, s.points, p);
      } else {
        final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
        for (final pt in s.points.skip(1)) {
          path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  @override
  bool shouldRepaint(_PaintPainter old) => true;
}
