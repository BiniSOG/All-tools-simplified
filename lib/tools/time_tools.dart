import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

const _big = TextStyle(fontSize: 52, fontWeight: FontWeight.w300, fontFeatures: [FontFeature.tabularFigures()]);

// ----------------------------------------------------------------- Stopwatch
class StopwatchTool extends StatefulWidget {
  const StopwatchTool({super.key});
  @override
  State<StopwatchTool> createState() => _StopwatchState();
}

class _StopwatchState extends State<StopwatchTool> {
  // Stored as timestamps so the stopwatch keeps counting while other tools are open.
  int _base = Store.integer('sw.base'), _start = Store.integer('sw.start');
  List<int> _laps = Store.list('sw.laps').map(int.parse).toList();
  Timer? _t;

  int get _now => _base + (_start > 0 ? DateTime.now().millisecondsSinceEpoch - _start : 0);

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_start > 0) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _save() {
    Store.setInt('sw.base', _base);
    Store.setInt('sw.start', _start);
    Store.setList('sw.laps', _laps.map((e) => '$e').toList());
  }

  void _toggle() => setState(() {
    if (_start > 0) {
      _base = _now;
      _start = 0;
    } else {
      _start = DateTime.now().millisecondsSinceEpoch;
    }
    _save();
  });

  void _lapOrReset() => setState(() {
    if (_start > 0) {
      _laps.insert(0, _now);
    } else {
      _base = 0;
      _laps = [];
    }
    _save();
  });

  @override
  Widget build(BuildContext context) {
    final running = _start > 0;
    return ToolList(
      children: [
        Panel(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: Text(clockText(_now, tenths: true), style: _big)),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _lapOrReset, child: Text(running ? 'Lap' : 'Reset')),
                ),
                gap(8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: running ? Colors.red : Colors.green, foregroundColor: Colors.white),
                    onPressed: _toggle,
                    child: Text(running ? 'Stop' : 'Start'),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_laps.isNotEmpty)
          Panel(
            children: [
              for (var i = 0; i < _laps.length; i++)
                ListTile(
                  dense: true,
                  title: Text('Lap ${_laps.length - i}'),
                  trailing: Text('+${clockText(_laps[i] - (i + 1 < _laps.length ? _laps[i + 1] : 0), tenths: true)}    ${clockText(_laps[i], tenths: true)}'),
                ),
            ],
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------- Timer
class TimerTool extends StatefulWidget {
  const TimerTool({super.key});
  @override
  State<TimerTool> createState() => _TimerState();
}

class _TimerState extends State<TimerTool> {
  final _min = TextEditingController(text: Store.str('timer.m', '5')), _sec = TextEditingController(text: '0');
  int _end = 0; // epoch ms while running
  int _left = 0; // ms remaining while paused
  bool _done = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  int get _remaining => _end > 0 ? _end - DateTime.now().millisecondsSinceEpoch : _left;

  void _tick() {
    if (_end == 0) return;
    if (_remaining <= 0) {
      _end = 0;
      _left = 0;
      _done = true;
      // Alert with the system sound and a burst of vibration.
      for (var i = 0; i < 4; i++) {
        Future.delayed(Duration(milliseconds: 400 * i), () {
          SystemSound.play(SystemSoundType.alert);
          HapticFeedback.vibrate();
        });
      }
    }
    setState(() {});
  }

  void _toggle() {
    setState(() {
      _done = false;
      if (_end > 0) {
        _left = _remaining;
        _end = 0;
      } else {
        if (_left <= 0) {
          _left = (((numOf(_min) ?? 0) * 60 + (numOf(_sec) ?? 0)) * 1000).round();
          Store.setStr('timer.m', _min.text);
        }
        if (_left <= 0) {
          toast(context, 'Set a time first');
          return;
        }
        _end = DateTime.now().millisecondsSinceEpoch + _left;
      }
    });
  }

  void _reset([int? minutes]) => setState(() {
    _end = 0;
    _left = 0;
    _done = false;
    if (minutes != null) {
      _min.text = '$minutes';
      _sec.text = '0';
    }
  });

  @override
  Widget build(BuildContext context) {
    final running = _end > 0;
    final shown = ((_remaining.clamp(0, 1 << 40)) / 1000).ceil() * 1000;
    return ToolList(
      children: [
        Panel(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(_done ? 'Time is up!' : clockText(shown), style: _done ? _big.copyWith(fontSize: 36, color: Colors.red) : _big),
              ),
            ),
            Row(
              children: [
                Expanded(child: numField(_min, 'Minutes', () {})),
                gap(8),
                Expanded(child: numField(_sec, 'Seconds', () {})),
              ],
            ),
            gap(),
            Wrap(
              spacing: 8,
              children: [
                for (final m in [1, 3, 5, 10, 25]) ActionChip(label: Text('$m min'), onPressed: () => _reset(m)),
              ],
            ),
            gap(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(onPressed: _reset, child: const Text('Reset')),
                ),
                gap(8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: running ? Colors.red : Colors.green, foregroundColor: Colors.white),
                    onPressed: _toggle,
                    child: Text(running ? 'Pause' : (_left > 0 ? 'Resume' : 'Start')),
                  ),
                ),
              ],
            ),
          ],
        ),
        const Center(child: Text('Keep this screen open so the alarm can go off.', style: TextStyle(fontSize: 13))),
      ],
    );
  }
}

// --------------------------------------------------------------- World clock
class WorldClockTool extends StatefulWidget {
  const WorldClockTool({super.key});
  @override
  State<WorldClockTool> createState() => _WorldClockState();
}

class _WorldClockState extends State<WorldClockTool> {
  static const _zones = [
    ('Honolulu', -10.0), ('Los Angeles', -8.0), ('New York', -5.0), ('São Paulo', -3.0), ('London', 0.0), ('Paris', 1.0), ('Cairo', 2.0),
    ('Addis Ababa', 3.0), ('Dubai', 4.0), ('Delhi', 5.5), ('Bangkok', 7.0), ('Beijing', 8.0), ('Tokyo', 9.0), ('Sydney', 10.0), //
  ];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _p2(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final n = DateTime.now(), utc = n.toUtc();
    return ToolList(
      children: [
        Panel(
          children: [
            const Center(child: Text('Your local time')),
            Center(child: Text('${_p2(n.hour)}:${_p2(n.minute)}:${_p2(n.second)}', style: _big)),
          ],
        ),
        Panel(
          children: [
            for (final z in _zones)
              Builder(
                builder: (_) {
                  final d = utc.add(Duration(minutes: (z.$2 * 60).round()));
                  final dd = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
                  return ListTile(
                    dense: true,
                    title: Text(z.$1, style: const TextStyle(fontSize: 15)),
                    trailing: Text('${_p2(d.hour)}:${_p2(d.minute)}${dd == 0 ? '' : (dd > 0 ? '  +1d' : '  −1d')}', style: const TextStyle(fontSize: 15)),
                  );
                },
              ),
            const Text('Standard time offsets; daylight saving is not applied.', style: TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }
}
