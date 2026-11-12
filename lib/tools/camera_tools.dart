import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

import '../core/logic.dart';
import '../core/ui.dart';
import 'net_tools.dart' show LanServer;

/// Opens a camera, handles permission problems and app pause/resume, and hands
/// the ready controller to [builder]. All camera tools are built on this.
class CameraBox extends StatefulWidget {
  const CameraBox({super.key, required this.builder, this.front = false, this.preset = ResolutionPreset.medium, this.format, this.onReady});
  final Widget Function(BuildContext context, CameraController camera) builder;
  final bool front;
  final ResolutionPreset preset;
  final ImageFormatGroup? format;
  final void Function(CameraController camera)? onReady;

  @override
  State<CameraBox> createState() => _CameraBoxState();
}

class _CameraBoxState extends State<CameraBox> with WidgetsBindingObserver {
  CameraController? _cam;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  Future<void> _open() async {
    try {
      final all = await availableCameras();
      if (all.isEmpty) throw CameraException('none', 'no camera');
      final want = widget.front ? CameraLensDirection.front : CameraLensDirection.back;
      final desc = all.firstWhere((c) => c.lensDirection == want, orElse: () => all.first);
      final cam = CameraController(desc, widget.preset, enableAudio: false, imageFormatGroup: widget.format);
      await cam.initialize();
      if (!mounted) return cam.dispose();
      setState(() {
        _cam = cam;
        _error = null;
      });
      widget.onReady?.call(cam);
    } on CameraException catch (e) {
      final denied = e.code.toLowerCase().contains('denied') || e.code.toLowerCase().contains('restricted');
      if (mounted) {
        setState(
          () => _error = denied ? 'Camera permission is needed. Allow the camera for this app in your phone settings, then reopen this tool.' : 'The camera could not be started on this device.',
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'No camera is available on this device.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released while the app is in the background.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final c = _cam;
      _cam = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed && _cam == null) {
      _open();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final cam = _cam;
    if (cam == null || !cam.value.isInitialized) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, cam);
  }
}

/// Camera picture filling the available space without distortion.
Widget _preview(CameraController cam, {double scale = 1, ColorFilter? filter}) {
  Widget v = Center(child: CameraPreview(cam));
  if (filter != null) v = ColorFiltered(colorFilter: filter, child: v);
  return ClipRect(
    child: ColoredBox(
      color: Colors.black,
      child: Transform.scale(scale: scale, child: v),
    ),
  );
}

Future<void> _quiet(Future<void> Function() f) async {
  try {
    await f();
  } catch (_) {}
}

/// Average colour of a small square in the middle of a frame, and overall brightness (0–255).
({int r, int g, int b, double luma}) frameStats(CameraImage im) {
  final w = im.width, h = im.height, p0 = im.planes[0];
  var r = 0, g = 0, b = 0, n = 0;
  var lumaSum = 0, lumaN = 0;
  if (im.format.group == ImageFormatGroup.bgra8888) {
    for (var y = 0; y < h; y += 16) {
      for (var x = 0; x < w; x += 16) {
        final i = y * p0.bytesPerRow + x * 4;
        lumaSum += p0.bytes[i + 2]; // red carries the pulse signal best
        lumaN++;
      }
    }
    for (var y = h ~/ 2 - 4; y < h ~/ 2 + 4; y++) {
      for (var x = w ~/ 2 - 4; x < w ~/ 2 + 4; x++) {
        final i = y * p0.bytesPerRow + x * 4;
        b += p0.bytes[i];
        g += p0.bytes[i + 1];
        r += p0.bytes[i + 2];
        n++;
      }
    }
  } else if (im.planes.length >= 3) {
    final pu = im.planes[1], pv = im.planes[2];
    final step = pu.bytesPerPixel ?? 1;
    for (var y = 0; y < h; y += 16) {
      for (var x = 0; x < w; x += 16) {
        lumaSum += p0.bytes[y * p0.bytesPerRow + x];
        lumaN++;
      }
    }
    for (var y = h ~/ 2 - 4; y < h ~/ 2 + 4; y++) {
      for (var x = w ~/ 2 - 4; x < w ~/ 2 + 4; x++) {
        final ci = (y ~/ 2) * pu.bytesPerRow + (x ~/ 2) * step;
        if (ci >= pu.bytes.length || ci >= pv.bytes.length) continue;
        final c = yuvToRgb(p0.bytes[y * p0.bytesPerRow + x], pu.bytes[ci], pv.bytes[ci]);
        r += c.$1;
        g += c.$2;
        b += c.$3;
        n++;
      }
    }
  }
  if (n == 0) n = 1;
  return (r: r ~/ n, g: g ~/ n, b: b ~/ n, luma: lumaN == 0 ? 0 : lumaSum / lumaN);
}

/// Coarse brightness grid of a frame, used to notice movement between frames.
List<int> frameGrid(CameraImage im) {
  final p = im.planes[0];
  final bgra = im.format.group == ImageFormatGroup.bgra8888;
  final out = <int>[];
  for (var gy = 0; gy < 12; gy++) {
    for (var gx = 0; gx < 16; gx++) {
      final x = (gx + 0.5) * im.width ~/ 16, y = (gy + 0.5) * im.height ~/ 12;
      final i = bgra ? y * p.bytesPerRow + x * 4 + 1 : y * p.bytesPerRow + x;
      out.add(i < p.bytes.length ? p.bytes[i] : 0);
    }
  }
  return out;
}

/// Share of grid cells (0–1) whose brightness changed noticeably.
double gridChange(List<int> a, List<int> b) {
  if (a.length != b.length || a.isEmpty) return 0;
  var changed = 0;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > 24) changed++;
  }
  return changed / a.length;
}

// ----------------------------------------------------------------- Magnifier
class MagnifierTool extends StatefulWidget {
  const MagnifierTool({super.key});
  @override
  State<MagnifierTool> createState() => _MagnifierState();
}

class _MagnifierState extends State<MagnifierTool> {
  double _zoom = 2, _max = 1;
  bool _light = false, _frozen = false;

  Future<void> _ready(CameraController cam) async {
    await _quiet(() async {
      _max = min(await cam.getMaxZoomLevel(), 8);
      await cam.setZoomLevel(min(_zoom, _max));
    });
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CameraBox(
    preset: ResolutionPreset.high,
    onReady: _ready,
    builder: (_, cam) {
      // Optical/sensor zoom first; any extra beyond what the camera offers is done by enlarging the picture.
      final native = min(_zoom, _max), extra = _zoom / native;
      return Column(
        children: [
          Expanded(child: _preview(cam, scale: extra)),
          Material(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_light ? Icons.flashlight_on : Icons.flashlight_off),
                  tooltip: 'Light',
                  onPressed: () {
                    setState(() => _light = !_light);
                    _quiet(() => cam.setFlashMode(_light ? FlashMode.torch : FlashMode.off));
                  },
                ),
                Expanded(
                  child: Slider(
                    value: _zoom,
                    min: 1,
                    max: 12,
                    onChanged: (v) {
                      setState(() => _zoom = v);
                      _quiet(() => cam.setZoomLevel(min(v, _max)));
                    },
                  ),
                ),
                Text('${_zoom.toStringAsFixed(1)}×'),
                IconButton(
                  icon: Icon(_frozen ? Icons.play_arrow : Icons.pause),
                  tooltip: _frozen ? 'Resume' : 'Freeze',
                  onPressed: () {
                    setState(() => _frozen = !_frozen);
                    _quiet(() => _frozen ? cam.pausePreview() : cam.resumePreview());
                  },
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

// -------------------------------------------------------------------- Mirror
class MirrorTool extends StatelessWidget {
  const MirrorTool({super.key});
  @override
  Widget build(BuildContext context) => CameraBox(front: true, preset: ResolutionPreset.high, builder: (_, cam) => _preview(cam));
}

// -------------------------------------------------------------- Night camera
class NightCameraTool extends StatefulWidget {
  const NightCameraTool({super.key});
  @override
  State<NightCameraTool> createState() => _NightCameraState();
}

class _NightCameraState extends State<NightCameraTool> {
  double _boost = 2.5;
  bool _green = false;
  String? _saved;

  Future<void> _ready(CameraController cam) => _quiet(() async {
    // Ask the camera for its longest/brightest exposure, then amplify on screen.
    await cam.setExposureOffset(await cam.getMaxExposureOffset());
  });

  @override
  Widget build(BuildContext context) => CameraBox(
    preset: ResolutionPreset.high,
    onReady: _ready,
    builder: (_, cam) {
      final k = _boost;
      final matrix = _green ? <double>[0, 0, 0, 0, 0, 0.3 * k, 0.6 * k, 0.1 * k, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0] : <double>[k, 0, 0, 0, 0, 0, k, 0, 0, 0, 0, 0, k, 0, 0, 0, 0, 0, 1, 0];
      return Column(
        children: [
          Expanded(child: _preview(cam, filter: ColorFilter.matrix(matrix))),
          Material(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.visibility, color: _green ? Colors.green : null),
                  tooltip: 'Green night-vision look',
                  onPressed: () => setState(() => _green = !_green),
                ),
                const Text('Boost'),
                Expanded(
                  child: Slider(value: _boost, min: 1, max: 6, onChanged: (v) => setState(() => _boost = v)),
                ),
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Take photo',
                  onPressed: () async {
                    try {
                      final f = await cam.takePicture();
                      final bytes = await f.readAsBytes();
                      final where = await FilePicker.saveFile(fileName: 'night_${DateTime.now().millisecondsSinceEpoch}.jpg', bytes: bytes);
                      if (mounted && where != null) setState(() => _saved = 'Photo saved');
                    } catch (_) {
                      if (mounted) setState(() => _saved = 'Could not take the photo');
                    }
                  },
                ),
              ],
            ),
          ),
          if (_saved != null)
            Padding(
              padding: const EdgeInsets.all(6),
              child: Text(_saved!, style: const TextStyle(fontSize: 13)),
            ),
        ],
      );
    },
  );
}

// ------------------------------------------------------------ Color detector
class ColorDetectorTool extends StatefulWidget {
  const ColorDetectorTool({super.key});
  @override
  State<ColorDetectorTool> createState() => _ColorDetectorState();
}

class _ColorDetectorState extends State<ColorDetectorTool> {
  int _r = 0, _g = 0, _b = 0, _lastMs = 0;
  bool _hold = false;

  void _ready(CameraController cam) => _quiet(
    () => cam.startImageStream((im) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_hold || now - _lastMs < 150 || !mounted) return;
      _lastMs = now;
      final s = frameStats(im);
      setState(() {
        _r = s.r;
        _g = s.g;
        _b = s.b;
      });
    }),
  );

  @override
  Widget build(BuildContext context) => CameraBox(
    preset: ResolutionPreset.low,
    onReady: _ready,
    builder: (_, cam) {
      final c = Color.fromARGB(255, _r, _g, _b);
      final hex = '#${[_r, _g, _b].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase()}';
      final hsv = HSVColor.fromColor(c);
      final k = rgbToCmyk(_r, _g, _b);
      return Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _preview(cam),
                Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Material(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  gap(),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${colorName(_r, _g, _b)}  $hex', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                        Text('RGB $_r, $_g, $_b', style: const TextStyle(fontSize: 13)),
                        Text('HSV ${hsv.hue.round()}°, ${(hsv.saturation * 100).round()}%, ${(hsv.value * 100).round()}%', style: const TextStyle(fontSize: 13)),
                        Text('CMYK ${k.$1}, ${k.$2}, ${k.$3}, ${k.$4}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(icon: Icon(_hold ? Icons.play_arrow : Icons.pause), tooltip: _hold ? 'Resume' : 'Hold', onPressed: () => setState(() => _hold = !_hold)),
                  IconButton(icon: const Icon(Icons.copy), tooltip: 'Copy hex', onPressed: () => copyText(context, hex)),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------- Heart rate
class HeartRateTool extends StatefulWidget {
  const HeartRateTool({super.key});
  @override
  State<HeartRateTool> createState() => _HeartRateState();
}

class _HeartRateState extends State<HeartRateTool> {
  final List<double> _v = [];
  final List<int> _t = [];
  double? _bpm;
  bool _finger = false;

  void _ready(CameraController cam) => _quiet(() async {
    await cam.setFlashMode(FlashMode.torch);
    await cam.startImageStream((im) {
      if (!mounted) return;
      final s = frameStats(im);
      final now = DateTime.now().millisecondsSinceEpoch;
      // A fingertip over the lit lens makes the whole frame bright red.
      final finger = im.format.group == ImageFormatGroup.bgra8888 ? s.luma > 90 : (s.r > 100 && s.r > s.g * 1.6 && s.r > s.b * 1.6);
      if (!finger) {
        _v.clear();
        _t.clear();
      } else {
        _v.add(s.luma);
        _t.add(now);
        while (_t.isNotEmpty && now - _t.first > 10000) {
          _t.removeAt(0);
          _v.removeAt(0);
        }
      }
      if (_t.length % 8 == 0 || finger != _finger) {
        final span = _t.length < 2 ? 0 : _t.last - _t.first;
        setState(() {
          _finger = finger;
          _bpm = span < 4000 ? null : bpmFromSamples(_v, (_t.length - 1) * 1000 / span);
        });
      }
    });
  });

  @override
  Widget build(BuildContext context) => CameraBox(
    preset: ResolutionPreset.low,
    onReady: _ready,
    builder: (_, cam) => Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipOval(child: SizedBox(width: 90, height: 90, child: _preview(cam, scale: 2))),
            gap(16),
            Icon(Icons.favorite, color: _bpm == null ? Colors.grey : Colors.red, size: 44),
            Text(_bpm == null ? '—' : _bpm!.round().toString(), style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w300)),
            const Text('beats per minute'),
            gap(16),
            Text(
              !_finger ? 'Cover the back camera and its light gently with a fingertip.' : (_bpm == null ? 'Hold still… measuring' : 'Keep still for a steadier reading'),
              textAlign: TextAlign.center,
            ),
            gap(),
            const Text('An estimate for curiosity only. This is not a medical device.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13)),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------- Motion camera
class MotionCameraTool extends StatefulWidget {
  const MotionCameraTool({super.key});
  @override
  State<MotionCameraTool> createState() => _MotionCameraState();
}

class _MotionCameraState extends State<MotionCameraTool> {
  CameraController? _cam;
  List<int>? _prev;
  final List<String> _shots = [];
  bool _armed = false, _busy = false;
  double _sens = 0.08, _level = 0;
  int _lastMs = 0, _lastShot = 0;

  void _onFrame(CameraImage im) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastMs < 250 || _busy || !mounted) return;
    _lastMs = now;
    final grid = frameGrid(im);
    final prev = _prev;
    _prev = grid;
    if (prev == null) return;
    final change = gridChange(prev, grid);
    setState(() => _level = change);
    if (_armed && change > _sens && now - _lastShot > 2000) _capture();
  }

  /// The image stream is paused around the photo because some phones cannot do both at once.
  Future<void> _capture() async {
    final cam = _cam;
    if (cam == null || _busy) return;
    _busy = true;
    try {
      if (cam.value.isStreamingImages) await cam.stopImageStream();
      final shot = await cam.takePicture();
      final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/motion');
      await dir.create(recursive: true);
      final path = '${dir.path}/motion_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(shot.path).copy(path);
      _shots.insert(0, path);
      _lastShot = DateTime.now().millisecondsSinceEpoch;
    } catch (_) {}
    _prev = null;
    await _quiet(() => cam.startImageStream(_onFrame));
    _busy = false;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => CameraBox(
    preset: ResolutionPreset.medium,
    onReady: (cam) {
      _cam = cam;
      _quiet(() => cam.startImageStream(_onFrame));
    },
    builder: (_, cam) => Column(
      children: [
        Expanded(child: _preview(cam)),
        LinearProgressIndicator(value: (_level / 0.3).clamp(0.0, 1.0), minHeight: 6, color: _level > _sens ? Colors.red : Colors.green),
        Material(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Sensitivity'),
                    // Slider right = more sensitive = smaller change needed.
                    Expanded(
                      child: Slider(value: 0.32 - _sens, min: 0.02, max: 0.3, onChanged: (v) => setState(() => _sens = 0.32 - v)),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _armed ? Colors.red : null),
                      onPressed: () => setState(() => _armed = !_armed),
                      child: Text(_armed ? 'Stop' : 'Start'),
                    ),
                  ],
                ),
                if (_shots.isNotEmpty)
                  SizedBox(
                    height: 64,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final p in _shots.take(20))
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Captured photo')),
                                  body: InteractiveViewer(child: Center(child: Image.file(File(p)))),
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Image.file(File(p), width: 64, height: 64, fit: BoxFit.cover, cacheWidth: 128),
                            ),
                          ),
                      ],
                    ),
                  ),
                Text(
                  _armed
                      ? 'Watching… ${_shots.length} photo${_shots.length == 1 ? '' : 's'} taken. Keep the phone still.'
                      : 'Prop the phone up, press Start, and a photo is taken whenever something moves.',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------- Document scanner
class ScannerTool extends StatefulWidget {
  const ScannerTool({super.key});
  @override
  State<ScannerTool> createState() => _ScannerState();
}

class _ScannerState extends State<ScannerTool> {
  final List<Uint8List> _pages = [];
  List<File> _saved = [];
  bool _busy = false, _camera = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/scans');
    await d.create(recursive: true);
    return d;
  }

  Future<void> _loadSaved() async {
    try {
      final files = (await _dir()).listSync().whereType<File>().where((f) => f.path.endsWith('.pdf')).toList()..sort((a, b) => b.path.compareTo(a.path));
      if (mounted) setState(() => _saved = files);
    } catch (_) {}
  }

  Future<void> _shoot(CameraController cam) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await (await cam.takePicture()).readAsBytes();
      _pages.add(bytes);
    } catch (_) {
      if (mounted) toast(context, 'Could not take the photo');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _finish() async {
    if (_pages.isEmpty) return;
    setState(() => _busy = true);
    try {
      final doc = pw.Document();
      for (final p in _pages) {
        final image = pw.MemoryImage(p);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(18),
            build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
          ),
        );
      }
      final n = DateTime.now();
      String p2(int v) => v.toString().padLeft(2, '0');
      final file = File('${(await _dir()).path}/Scan_${n.year}${p2(n.month)}${p2(n.day)}_${p2(n.hour)}${p2(n.minute)}${p2(n.second)}.pdf');
      await file.writeAsBytes(await doc.save());
      _pages.clear();
      _camera = false;
      await _loadSaved();
      if (mounted) toast(context, 'PDF created');
    } catch (_) {
      if (mounted) toast(context, 'Could not create the PDF');
    }
    if (mounted) setState(() => _busy = false);
  }

  String _name(File f) => f.path.split('/').last;

  void _view(File f) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(_name(f))),
        body: pdfx.PdfView(controller: pdfx.PdfController(document: pdfx.PdfDocument.openFile(f.path))),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_camera) {
      return CameraBox(
        preset: ResolutionPreset.veryHigh,
        builder: (_, cam) => Column(
          children: [
            Expanded(child: _preview(cam)),
            Material(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(child: Text('${_pages.length} page${_pages.length == 1 ? '' : 's'}')),
                    FilledButton.icon(onPressed: _busy ? null : () => _shoot(cam), icon: const Icon(Icons.camera_alt), label: const Text('Capture')),
                    gap(8),
                    OutlinedButton(onPressed: _busy || _pages.isEmpty ? null : _finish, child: const Text('Make PDF')),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ToolList(
      children: [
        FilledButton.icon(onPressed: () => setState(() => _camera = true), icon: const Icon(Icons.document_scanner), label: const Text('Scan a document')),
        gap(8),
        const Text('Photograph each page, then tap “Make PDF”. Lay the page flat in good light and fill the frame with it.', style: TextStyle(fontSize: 13)),
        gap(),
        if (_saved.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Your scanned PDFs will be listed here.')),
          )
        else
          for (final f in _saved)
            Card(
              child: ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: Text(_name(f), maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(fileSize(f.lengthSync())),
                onTap: () => _view(f),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_alt),
                      tooltip: 'Save a copy to the phone',
                      onPressed: () async {
                        try {
                          final where = await FilePicker.saveFile(fileName: _name(f), bytes: await f.readAsBytes());
                          if (context.mounted && where != null) toast(context, 'Saved');
                        } catch (_) {
                          if (context.mounted) toast(context, 'Could not save the file');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () async {
                        await _quiet(() => f.delete());
                        _loadSaved();
                      },
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

// ----------------------------------------------------------------- IP camera
class IpCameraTool extends StatefulWidget {
  const IpCameraTool({super.key});
  @override
  State<IpCameraTool> createState() => _IpCameraState();
}

class _IpCameraState extends State<IpCameraTool> {
  final _server = LanServer();
  final List<HttpResponse> _viewers = [];
  String? _url, _problem;
  int _lastMs = 0;
  bool _sending = false;

  static const _page =
      '<!doctype html><meta name=viewport content="width=device-width,initial-scale=1"><title>Utility Hub camera</title>'
      '<body style="margin:0;background:#000;text-align:center"><img src="stream" style="max-width:100%;max-height:100vh">';

  Future<void> _start() async {
    final url = await _server.start((req, path) async {
      if (path == 'stream') {
        req.response
          ..bufferOutput = false
          ..headers.set(HttpHeaders.contentTypeHeader, 'multipart/x-mixed-replace; boundary=frame')
          ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
        _viewers.add(req.response);
        req.response.done.whenComplete(() {
          _viewers.remove(req.response);
          if (mounted) setState(() {});
        }).ignore();
        if (mounted) setState(() {});
      } else {
        req.response.headers.contentType = ContentType.html;
        req.response.write(_page);
        await req.response.close();
      }
    });
    if (mounted) setState(() => url == null ? _problem = 'Connect this phone to Wi-Fi (or turn on its hotspot) and try again.' : _url = url);
  }

  /// Sends a frame to every connected viewer, at most about five times a second.
  void _onFrame(CameraImage im) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_viewers.isEmpty || _sending || now - _lastMs < 200) return;
    _lastMs = now;
    _sending = true;
    try {
      final Uint8List jpg;
      if (im.format.group == ImageFormatGroup.jpeg) {
        jpg = im.planes[0].bytes;
      } else {
        final p = im.planes[0];
        final frame = img.Image.fromBytes(
          width: im.width,
          height: im.height,
          bytes: p.bytes.buffer,
          bytesOffset: p.bytes.offsetInBytes,
          rowStride: p.bytesPerRow,
          numChannels: 4,
          order: img.ChannelOrder.bgra,
        );
        jpg = img.encodeJpg(frame, quality: 55);
      }
      for (final v in List.of(_viewers)) {
        try {
          v
            ..write('--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${jpg.length}\r\n\r\n')
            ..add(jpg)
            ..write('\r\n');
        } catch (_) {
          _viewers.remove(v);
        }
      }
    } catch (_) {}
    _sending = false;
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam, size: 64),
              gap(),
              Text(_problem ?? 'Turn this phone into a camera you can watch from another phone or computer on the same Wi-Fi.', textAlign: TextAlign.center),
              gap(16),
              FilledButton(onPressed: _start, child: const Text('Start camera')),
            ],
          ),
        ),
      );
    }
    return CameraBox(
      preset: ResolutionPreset.low,
      // Android can hand over ready-made JPEG frames; iOS frames are converted in the app.
      format: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      onReady: (cam) => _quiet(() => cam.startImageStream(_onFrame)),
      builder: (_, cam) => Column(
        children: [
          Expanded(child: _preview(cam)),
          Material(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  const Text('On the other device, open this address in a web browser:', style: TextStyle(fontSize: 13)),
                  SelectableText(_url!, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  Text('${_viewers.length} watching · both devices must be on the same Wi-Fi · keep this screen open', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
