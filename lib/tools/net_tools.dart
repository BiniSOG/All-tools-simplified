import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

/// This phone's address on the local Wi-Fi / hotspot network, or null if it has none.
Future<String?> localIp() async {
  try {
    final nets = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    bool private(String a) => a.startsWith('192.168.') || a.startsWith('10.') || RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(a);
    // Prefer Wi-Fi / hotspot interfaces over mobile data.
    int rank(NetworkInterface n) => RegExp(r'^(wlan|swlan|ap|en|bridge)').hasMatch(n.name) ? 0 : 1;
    final sorted = nets.toList()..sort((a, b) => rank(a) - rank(b));
    for (final n in sorted) {
      for (final a in n.addresses) {
        if (private(a.address)) return a.address;
      }
    }
  } catch (_) {}
  return null;
}

/// A tiny web server other devices on the same network can open in a browser.
/// Every address contains a random code, so only people shown the link can use it.
class LanServer {
  HttpServer? _server;

  /// Starts serving and returns the address to share, or null without a local network.
  /// [handler] receives each request and its path after the secret code.
  Future<String?> start(Future<void> Function(HttpRequest request, String path) handler) async {
    final ip = await localIp();
    if (ip == null) return null;
    final rng = Random.secure();
    final token = [for (var i = 0; i < 6; i++) 'abcdefghjkmnpqrstuvwxyz23456789'[rng.nextInt(31)]].join();
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
    } catch (_) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      } catch (_) {
        return null;
      }
    }
    _server!.listen((req) async {
      try {
        final segs = req.uri.pathSegments;
        if (segs.isEmpty || segs.first != token) {
          req.response.statusCode = HttpStatus.notFound;
          await req.response.close();
        } else if (segs.length == 1 && !req.uri.path.endsWith('/')) {
          await req.response.redirect(Uri(path: '/$token/'));
        } else {
          await handler(req, segs.skip(1).where((s) => s.isNotEmpty).join('/'));
        }
      } catch (_) {
        try {
          await req.response.close();
        } catch (_) {}
      }
    }, onError: (_) {});
    return 'http://$ip:${_server!.port}/$token/';
  }

  void stop() {
    _server?.close(force: true);
    _server = null;
  }
}

// ------------------------------------------------------------- File transfer
class FileTransferTool extends StatefulWidget {
  const FileTransferTool({super.key});
  @override
  State<FileTransferTool> createState() => _FileTransferState();
}

class _FileTransferState extends State<FileTransferTool> {
  final _server = LanServer();
  final List<PlatformFile> _shared = [];
  List<File> _received = [];
  String? _url, _problem;

  @override
  void initState() {
    super.initState();
    _loadReceived();
  }

  @override
  void dispose() {
    _server.stop();
    super.dispose();
  }

  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/received');
    await d.create(recursive: true);
    return d;
  }

  Future<void> _loadReceived() async {
    try {
      final files = (await _dir()).listSync().whereType<File>().toList()..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      if (mounted) setState(() => _received = files);
    } catch (_) {}
  }

  String _page() {
    const esc = HtmlEscape();
    final rows = [for (var i = 0; i < _shared.length; i++) '<li><a href="get/$i">${esc.convert(_shared[i].name)}</a> <small>${fileSize(_shared[i].size)}</small></li>'].join();
    return '<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1"><title>Utility Hub file transfer</title>'
        '<style>body{font-family:sans-serif;max-width:560px;margin:auto;padding:16px}li{margin:10px 0}a{font-size:17px}'
        'button,input{font-size:16px;margin-top:8px}small{color:#666}</style>'
        '<h2>Files from the phone</h2>${rows.isEmpty ? '<p>Nothing shared yet. Add files in the app, then reload.</p>' : '<ul>$rows</ul>'}'
        '<h2>Send files to the phone</h2><input type=file id=f multiple><br><button onclick="go()">Send</button><p id=s></p>'
        '<script>async function go(){var s=document.getElementById("s"),fs=document.getElementById("f").files;'
        'for(var i=0;i<fs.length;i++){s.textContent="Sending "+fs[i].name+"...";'
        'var r=await fetch("upload?name="+encodeURIComponent(fs[i].name),{method:"POST",body:fs[i]});'
        'if(!r.ok){s.textContent="Failed: "+fs[i].name;return}}s.textContent=fs.length?"Done":"Choose a file first"}</script>';
  }

  Future<void> _handle(HttpRequest req, String path) async {
    final res = req.response;
    if (path == 'upload' && req.method == 'POST') {
      final dir = await _dir();
      final name = safeFileName(req.uri.queryParameters['name'] ?? 'file');
      var file = File('${dir.path}/$name');
      for (var n = 1; file.existsSync(); n++) {
        file = File('${dir.path}/${n}_$name');
      }
      await req.cast<List<int>>().pipe(file.openWrite());
      res.write('ok');
      await res.close();
      _loadReceived();
    } else if (path.startsWith('get/')) {
      final i = int.tryParse(path.substring(4)) ?? -1;
      final f = i >= 0 && i < _shared.length ? _shared[i] : null;
      if (f?.path == null) {
        res.statusCode = HttpStatus.notFound;
        return res.close();
      }
      res.headers
        ..contentType = ContentType.binary
        ..contentLength = f!.size
        ..set('Content-Disposition', 'attachment; filename="${safeFileName(f.name)}"');
      await res.addStream(File(f.path!).openRead());
      await res.close();
    } else {
      res.headers.contentType = ContentType.html;
      res.write(_page());
      await res.close();
    }
  }

  Future<void> _start() async {
    final url = await _server.start(_handle);
    if (mounted) setState(() => url == null ? _problem = 'Connect this phone to Wi-Fi (or turn on its hotspot) and try again.' : _url = url);
  }

  Future<void> _addFiles() async {
    try {
      final r = await FilePicker.pickFiles(allowMultiple: true);
      if (r != null && mounted) setState(() => _shared.addAll(r.files.where((f) => f.path != null)));
    } catch (_) {
      if (mounted) toast(context, 'Could not open the file picker');
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return ToolList(
      children: [
        if (url == null) ...[
          const Icon(Icons.swap_horiz, size: 56),
          gap(8),
          Text(_problem ?? 'Send and receive files with any phone or computer on the same Wi-Fi. No internet needed, and the other device only needs a web browser.', textAlign: TextAlign.center),
          gap(),
          FilledButton(onPressed: _start, child: const Text('Start sharing')),
        ] else
          Panel(
            children: [
              const Text('On the other device, scan this code or type the address into a browser:', style: TextStyle(fontSize: 13)),
              gap(8),
              Center(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),
                  child: QrImageView(data: url, size: 170),
                ),
              ),
              gap(8),
              Center(
                child: SelectableText(url, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              gap(4),
              const Text('Sharing stops when you leave this screen. Anyone with this address on your Wi-Fi can use it, so only share it with people you trust.', style: TextStyle(fontSize: 12)),
            ],
          ),
        Panel(
          children: [
            const Text('Files to send', style: TextStyle(fontWeight: FontWeight.w600)),
            for (final f in _shared)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(fileSize(f.size)),
                trailing: IconButton(icon: const Icon(Icons.close), tooltip: 'Stop sharing', onPressed: () => setState(() => _shared.remove(f))),
              ),
            OutlinedButton.icon(onPressed: _addFiles, icon: const Icon(Icons.add), label: const Text('Add files')),
          ],
        ),
        Panel(
          children: [
            const Text('Received files', style: TextStyle(fontWeight: FontWeight.w600)),
            if (_received.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Files sent to this phone appear here.', style: TextStyle(fontSize: 13)),
              ),
            for (final f in _received)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(f.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(fileSize(f.lengthSync())),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.save_alt),
                      tooltip: 'Save to the phone',
                      onPressed: () async {
                        try {
                          final where = await FilePicker.saveFile(fileName: f.path.split('/').last, bytes: await f.readAsBytes());
                          if (context.mounted && where != null) toast(context, 'Saved');
                        } catch (_) {
                          if (context.mounted) toast(context, 'Could not save the file');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: () {
                        try {
                          f.deleteSync();
                        } catch (_) {}
                        _loadReceived();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Speed test
class SpeedTestTool extends StatefulWidget {
  const SpeedTestTool({super.key});
  @override
  State<SpeedTestTool> createState() => _SpeedTestState();
}

class _SpeedTestState extends State<SpeedTestTool> {
  static const _host = 'https://speed.cloudflare.com';
  bool _running = false, _alive = true;
  String _phase = '';
  double? _down, _up;
  int? _ping;
  String? _error;
  late String _last = Store.str('speedtest.last');

  @override
  void dispose() {
    _alive = false;
    super.dispose();
  }

  void _set(VoidCallback f) {
    if (mounted) setState(f);
  }

  Future<void> _run() async {
    _set(() {
      _running = true;
      _error = null;
      _down = _up = null;
      _ping = null;
      _phase = 'Checking connection…';
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      // Response time: the second request reuses the open connection, so it times the round trip only.
      Future<int> hit() async {
        final sw = Stopwatch()..start();
        final res = await (await client.getUrl(Uri.parse('$_host/__down?bytes=0'))).close().timeout(const Duration(seconds: 8));
        await res.drain<void>();
        return sw.elapsedMilliseconds;
      }

      await hit();
      final ping = await hit();
      _set(() {
        _ping = ping;
        _phase = 'Testing download…';
      });

      // Download for up to 8 seconds.
      final res = await (await client.getUrl(Uri.parse('$_host/__down?bytes=100000000'))).close().timeout(const Duration(seconds: 8));
      var bytes = 0, shown = 0;
      final sw = Stopwatch()..start();
      await for (final chunk in res.timeout(const Duration(seconds: 8))) {
        bytes += chunk.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - shown > 250) {
          shown = ms;
          _set(() => _down = mbps(bytes, ms));
        }
        if (ms > 8000 || !_alive) break;
      }
      _set(() {
        _down = mbps(bytes, sw.elapsedMilliseconds);
        _phase = 'Testing upload…';
      });
      if (!_alive) return;

      // Upload random data for up to 6 seconds.
      final req = await client.postUrl(Uri.parse('$_host/__up'));
      req.headers.contentType = ContentType.binary;
      final rng = Random();
      final block = Uint8List.fromList([for (var i = 0; i < 65536; i++) rng.nextInt(256)]);
      var sent = 0;
      shown = 0;
      sw
        ..reset()
        ..start();
      while (sw.elapsedMilliseconds < 6000 && sent < 60000000 && _alive) {
        req.add(block);
        await req.flush().timeout(const Duration(seconds: 8));
        sent += block.length;
        final ms = sw.elapsedMilliseconds;
        if (ms - shown > 250) {
          shown = ms;
          _set(() => _up = mbps(sent, ms));
        }
      }
      final upMs = sw.elapsedMilliseconds;
      await (await req.close().timeout(const Duration(seconds: 10))).drain<void>();
      final n = DateTime.now();
      _set(() {
        _up = mbps(sent, upMs);
        _last = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}: ↓ ${_down!.toStringAsFixed(1)}  ↑ ${_up!.toStringAsFixed(1)} Mbps, $ping ms';
        Store.setStr('speedtest.last', _last);
      });
    } catch (_) {
      _set(() => _error = 'The test could not finish. Check that you are connected to the internet and try again.');
    } finally {
      client.close(force: true);
      _set(() {
        _running = false;
        _phase = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String f(double? v) => v == null ? '—' : v.toStringAsFixed(v < 10 ? 2 : 1);
    return ToolList(
      children: [
        Panel(
          children: [
            Row(children: [Stat('Download Mbps', f(_down)), Stat('Upload Mbps', f(_up)), Stat('Ping ms', _ping == null ? '—' : '$_ping')]),
            gap(),
            if (_running) ...[const LinearProgressIndicator(), gap(8), Center(child: Text(_phase))],
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            gap(8),
            FilledButton(onPressed: _running ? null : _run, child: Text(_down == null ? 'Start test' : 'Test again')),
            if (_last.isNotEmpty) ...[gap(), Text('Last result — $_last', style: const TextStyle(fontSize: 13))],
          ],
        ),
        const Text(
          'Uses real data: roughly 20–150 MB per test on a fast connection. On mobile data this counts against your allowance. This is the only tool that needs the internet.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
