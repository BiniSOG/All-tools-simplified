import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../core/logic.dart';
import '../core/ui.dart';

const _small = TextStyle(fontSize: 13);

// --------------------------------------------------------------- Sound meter
class SoundMeterTool extends StatefulWidget {
  const SoundMeterTool({super.key});
  @override
  State<SoundMeterTool> createState() => _SoundMeterState();
}

class _SoundMeterState extends State<SoundMeterTool> {
  // Served by small native handlers (MainActivity / AppDelegate) that only report loudness.
  static const _ch = MethodChannel('toolbox/soundlevel');
  Timer? _t;
  String? _problem;
  double _db = 0, _max = 0, _sum = 0, _cal = 0;
  int _n = 0;

  bool get _on => _t != null;

  Future<void> _start() async {
    try {
      final r = await _ch.invokeMethod<String>('start');
      if (!mounted) return;
      if (r != 'ok') {
        setState(() => _problem = r == 'denied' ? 'Microphone permission is needed. Allow it for this app in your phone settings.' : 'The microphone could not be started on this device.');
        return;
      }
      _max = _sum = 0;
      _n = 0;
      _t = Timer.periodic(const Duration(milliseconds: 150), (_) async {
        try {
          final level = await _ch.invokeMethod<double>('level');
          if (!mounted || level == null || !level.isFinite) return;
          setState(() {
            // The microphone reports level relative to its own maximum (0 = loudest);
            // shifting by about 90 gives a usable everyday decibel estimate.
            _db = (level + 90 + _cal).clamp(0.0, 130.0);
            _max = max(_max, _db);
            _sum += _db;
            _n++;
          });
        } catch (_) {}
      });
      setState(() => _problem = null);
    } catch (_) {
      if (mounted) setState(() => _problem = 'The microphone could not be started on this device.');
    }
  }

  Future<void> _stop() async {
    final was = _t != null;
    _t?.cancel();
    _t = null;
    if (was) {
      try {
        await _ch.invokeMethod<void>('stop');
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    // Not _stop(): that refreshes the screen, which is not allowed while closing.
    if (_t != null) {
      _t?.cancel();
      _t = null;
      _ch.invokeMethod<void>('stop').catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _db < 30
        ? 'Very quiet'
        : (_db < 50 ? 'Quiet room' : (_db < 65 ? 'Conversation' : (_db < 80 ? 'Busy street' : (_db < 95 ? 'Loud — tiring over time' : 'Very loud — protect your ears'))));
    return ToolList(
      children: [
        Panel(
          children: [
            Center(
              child: Text(_on ? _db.toStringAsFixed(0) : '—', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w300)),
            ),
            Center(child: Text(_on ? 'dB · $label' : 'dB')),
            gap(),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: _on ? _db / 120 : 0, minHeight: 16, color: _db > 85 ? Colors.red : (_db > 65 ? Colors.orange : Colors.green)),
            ),
            gap(),
            Row(children: [Stat('Average', _n == 0 ? '—' : (_sum / _n).toStringAsFixed(0)), Stat('Peak', _n == 0 ? '—' : _max.toStringAsFixed(0))]),
            gap(),
            if (_problem != null) Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton(onPressed: _on ? _stop : _start, child: Text(_on ? 'Stop' : 'Start measuring')),
          ],
        ),
        Panel(
          children: [
            Text('Calibration: ${_cal >= 0 ? '+' : ''}${_cal.toStringAsFixed(0)} dB'),
            Slider(value: _cal, min: -20, max: 20, divisions: 40, onChanged: (v) => setState(() => _cal = v)),
            const Text('Phone microphones differ, so readings are approximate. If you have a real sound meter, adjust until they agree. Nothing is recorded or saved.', style: _small),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- Sound generator
class SoundGeneratorTool extends StatefulWidget {
  const SoundGeneratorTool({super.key});
  @override
  State<SoundGeneratorTool> createState() => _SoundGeneratorState();
}

class _SoundGeneratorState extends State<SoundGeneratorTool> {
  AudioPlayer? _player;
  double _hz = 440;
  bool _square = false, _playing = false;
  String? _file, _problem;

  Future<void> _play() async {
    try {
      final player = _player ??= AudioPlayer();
      final old = _file;
      // A fresh file name per tone, so the player never reuses a cached older tone.
      final path = '${(await getTemporaryDirectory()).path}/tone_${DateTime.now().millisecondsSinceEpoch}.wav';
      await File(path).writeAsBytes(toneWav(_hz, seconds: 3, square: _square));
      _file = path;
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(DeviceFileSource(path));
      if (old != null) File(old).delete().ignore();
      if (mounted) {
        setState(() {
          _playing = true;
          _problem = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _problem = 'Sound could not be played on this device.');
    }
  }

  Future<void> _stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
    if (mounted) setState(() => _playing = false);
  }

  @override
  void dispose() {
    final p = _player, f = _file;
    _player = null;
    p?.dispose().catchError((_) {});
    if (f != null) File(f).delete().ignore();
    super.dispose();
  }

  void _setHz(double hz, {bool apply = true}) {
    setState(() => _hz = hz.clamp(20.0, 20000.0));
    if (apply && _playing) _play();
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          Center(
            child: Text('${_hz.round()} Hz', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300)),
          ),
          Slider(value: hzToSlider(_hz).clamp(0.0, 1.0), onChanged: (t) => _setHz(sliderToHz(t), apply: false), onChangeEnd: (t) => _setHz(sliderToHz(t))),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (final hz in [100, 250, 440, 1000, 4000, 8000, 12000, 15000]) ActionChip(label: Text(hz >= 1000 ? '${hz ~/ 1000}k' : '$hz'), onPressed: () => _setHz(hz.toDouble())),
            ],
          ),
          gap(),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('Smooth (sine)')),
              ButtonSegment(value: true, label: Text('Buzzy (square)')),
            ],
            selected: {_square},
            onSelectionChanged: (s) {
              setState(() => _square = s.first);
              if (_playing) _play();
            },
          ),
          gap(),
          if (_problem != null) Text(_problem!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          FilledButton.icon(onPressed: _playing ? _stop : _play, icon: Icon(_playing ? Icons.stop : Icons.play_arrow), label: Text(_playing ? 'Stop' : 'Play tone')),
        ],
      ),
      const Text('Start with the volume low. Most adults cannot hear above 15–17 kHz, and phone speakers are weak below about 200 Hz.', style: _small),
    ],
  );
}

// -------------------------------------------------------------- Music player
class MusicPlayerTool extends StatefulWidget {
  const MusicPlayerTool({super.key});
  @override
  State<MusicPlayerTool> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayerTool> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  final List<PlatformFile> _list = [];
  int _index = -1;
  bool _playing = false;
  Duration _pos = Duration.zero, _len = Duration.zero;

  AudioPlayer _ensure() {
    final existing = _player;
    if (existing != null) return existing;
    final p = AudioPlayer();
    _player = p;
    _subs
      ..add(p.onPositionChanged.listen((d) => mounted ? setState(() => _pos = d) : null))
      ..add(p.onDurationChanged.listen((d) => mounted ? setState(() => _len = d) : null))
      ..add(p.onPlayerStateChanged.listen((s) => mounted ? setState(() => _playing = s == PlayerState.playing) : null))
      ..add(p.onPlayerComplete.listen((_) => _next()));
    return p;
  }

  Future<void> _add() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.audio, allowMultiple: true);
      if (r == null || !mounted) return;
      final start = _list.isEmpty;
      setState(() => _list.addAll(r.files.where((f) => f.path != null)));
      if (start && _list.isNotEmpty) _playAt(0);
    } catch (_) {
      if (mounted) toast(context, 'Could not open the file picker');
    }
  }

  Future<void> _playAt(int i) async {
    if (i < 0 || i >= _list.length) return;
    setState(() {
      _index = i;
      _pos = _len = Duration.zero;
    });
    try {
      await _ensure().play(DeviceFileSource(_list[i].path!));
    } catch (_) {
      if (mounted) toast(context, 'This file could not be played');
    }
  }

  void _next() {
    if (_list.isNotEmpty) _playAt((_index + 1) % _list.length);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose().catchError((_) {});
    super.dispose();
  }

  String _t(Duration d) => clockText(d.inMilliseconds);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final has = _index >= 0 && _index < _list.length;
    return Column(
      children: [
        Expanded(
          child: _list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.library_music, size: 64),
                      gap(),
                      const Text('Play music files stored on your phone.'),
                      gap(),
                      FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Choose songs')),
                    ],
                  ),
                )
              : ListView(
                  children: [
                    for (var i = 0; i < _list.length; i++)
                      ListTile(
                        selected: i == _index,
                        leading: Icon(i == _index && _playing ? Icons.equalizer : Icons.music_note),
                        title: Text(_list[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _playAt(i),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add more')),
                    ),
                  ],
                ),
        ),
        if (has)
          Material(
            elevation: 8,
            color: cs.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Column(
                children: [
                  Text(
                    _list[_index].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _len.inMilliseconds == 0 ? 0 : (_pos.inMilliseconds / _len.inMilliseconds).clamp(0.0, 1.0),
                    onChanged: _len.inMilliseconds == 0 ? null : (v) => _player?.seek(_len * v).catchError((_) {}),
                  ),
                  Row(
                    children: [
                      Text(_t(_pos), style: _small),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.skip_previous), tooltip: 'Previous', onPressed: () => _playAt((_index - 1 + _list.length) % _list.length)),
                      IconButton.filled(
                        iconSize: 32,
                        icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                        tooltip: _playing ? 'Pause' : 'Play',
                        onPressed: () => (_playing ? _player?.pause() : _player?.resume())?.catchError((_) {}),
                      ),
                      IconButton(icon: const Icon(Icons.skip_next), tooltip: 'Next', onPressed: _next),
                      const Spacer(),
                      Text(_t(_len), style: _small),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------ Text to speech
class TtsTool extends StatefulWidget {
  const TtsTool({super.key});
  @override
  State<TtsTool> createState() => _TtsState();
}

class _TtsState extends State<TtsTool> {
  FlutterTts? _tts;
  final _c = TextEditingController();
  double _rate = 0.5, _pitch = 1;
  bool _speaking = false;

  Future<void> _speak() async {
    if (_c.text.trim().isEmpty) return toast(context, 'Type something to read aloud');
    try {
      final tts = _tts ??= FlutterTts()
        ..setCompletionHandler(() => mounted ? setState(() => _speaking = false) : null)
        ..setCancelHandler(() => mounted ? setState(() => _speaking = false) : null);
      await tts.setSpeechRate(_rate);
      await tts.setPitch(_pitch);
      setState(() => _speaking = true);
      await tts.speak(_c.text);
    } catch (_) {
      if (mounted) {
        setState(() => _speaking = false);
        toast(context, 'This phone has no speech voice installed');
      }
    }
  }

  @override
  void dispose() {
    _tts?.stop().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          textField(_c, 'Text to read aloud', () {}, maxLines: 7),
          gap(),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Speed')),
              Expanded(
                child: Slider(value: _rate, min: 0.1, max: 1, onChanged: (v) => setState(() => _rate = v)),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 60, child: Text('Pitch')),
              Expanded(
                child: Slider(value: _pitch, min: 0.5, max: 2, onChanged: (v) => setState(() => _pitch = v)),
              ),
            ],
          ),
          FilledButton.icon(
            onPressed: _speaking
                ? () {
                    _tts?.stop().catchError((_) {});
                    setState(() => _speaking = false);
                  }
                : _speak,
            icon: Icon(_speaking ? Icons.stop : Icons.volume_up),
            label: Text(_speaking ? 'Stop' : 'Speak'),
          ),
        ],
      ),
      const Text('Uses the voices built into your phone, in your phone’s language.', style: _small),
    ],
  );
}

// ------------------------------------------------------------ Speech to text
class SttTool extends StatefulWidget {
  const SttTool({super.key});
  @override
  State<SttTool> createState() => _SttState();
}

class _SttState extends State<SttTool> {
  SpeechToText? _stt;
  final _c = TextEditingController();
  String _before = '', _problem = '';
  bool _listening = false;

  Future<void> _toggle() async {
    if (_listening) {
      try {
        await _stt?.stop();
      } catch (_) {}
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final stt = _stt ??= SpeechToText();
      final ok = await stt.initialize(
        onStatus: (s) {
          if (mounted && (s == 'done' || s == 'notListening')) setState(() => _listening = false);
        },
        onError: (_) => mounted ? setState(() => _listening = false) : null,
      );
      if (!ok) {
        if (mounted) setState(() => _problem = 'Speech recognition is not available. Allow the microphone for this app, and on Android make sure the Google app is installed.');
        return;
      }
      // New speech is added after whatever is already in the box.
      _before = _c.text.isEmpty ? '' : '${_c.text.trimRight()} ';
      await stt.listen(onResult: (r) => mounted ? setState(() => _c.text = '$_before${r.recognizedWords}') : null);
      if (mounted) {
        setState(() {
          _listening = true;
          _problem = '';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _problem = 'Speech recognition could not be started on this device.');
    }
  }

  @override
  void dispose() {
    _stt?.cancel().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          textField(_c, 'What you say appears here', () {}, maxLines: 8),
          gap(),
          if (_problem.isNotEmpty) Text(_problem, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _listening ? Colors.red : null),
                  onPressed: _toggle,
                  icon: Icon(_listening ? Icons.stop : Icons.mic),
                  label: Text(_listening ? 'Stop' : 'Start talking'),
                ),
              ),
              gap(8),
              IconButton(icon: const Icon(Icons.copy), tooltip: 'Copy', onPressed: () => copyText(context, _c.text)),
              IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Clear', onPressed: () => setState(_c.clear)),
            ],
          ),
        ],
      ),
      const Text('Uses your phone’s own speech recognition. Depending on the phone, this may need an internet connection.', style: _small),
    ],
  );
}
