import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

/// Camera LED, via the small native handlers in MainActivity / AppDelegate.
class Torch {
  static const _ch = MethodChannel('toolbox/torch');

  /// Returns false when the device has no usable LED.
  static Future<bool> set(bool on) async {
    try {
      return await _ch.invokeMethod<bool>('set', on) ?? false;
    } catch (_) {
      return false;
    }
  }
}

// --------------------------------------------------------------------- Notes
class NotesTool extends StatefulWidget {
  const NotesTool({super.key});
  @override
  State<NotesTool> createState() => _NotesState();
}

class _NotesState extends State<NotesTool> {
  List<String> _notes = Store.list('notes');

  Future<void> _edit(int? index) async {
    final c = TextEditingController(text: index == null ? '' : _notes[index]);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(index == null ? 'New note' : 'Edit note')),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: c,
              autofocus: true,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(hintText: 'Write something… it saves when you go back.', border: InputBorder.none),
            ),
          ),
        ),
      ),
    );
    final text = c.text.trim();
    setState(() {
      if (index != null) _notes.removeAt(index);
      if (text.isNotEmpty) _notes.insert(0, text);
      Store.setList('notes', _notes);
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (_notes.isEmpty)
        const Center(child: Text('No notes yet. Tap + to write one.'))
      else
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          itemCount: _notes.length,
          itemBuilder: (_, i) => Card(
            child: ListTile(
              title: Text(_notes[i], maxLines: 3, overflow: TextOverflow.ellipsis),
              onTap: () => _edit(i),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => setState(() {
                  _notes = List.of(_notes)..removeAt(i);
                  Store.setList('notes', _notes);
                }),
              ),
            ),
          ),
        ),
      Positioned(
        right: 16,
        bottom: 16,
        child: FloatingActionButton(onPressed: () => _edit(null), tooltip: 'New note', child: const Icon(Icons.add)),
      ),
    ],
  );
}

// --------------------------------------------------------------------- To-do
class TodoTool extends StatefulWidget {
  const TodoTool({super.key});
  @override
  State<TodoTool> createState() => _TodoState();
}

class _TodoState extends State<TodoTool> {
  // Each entry is "0text" (open) or "1text" (done).
  final List<String> _items = Store.list('todo');
  final _c = TextEditingController();

  void _save() => Store.setList('todo', _items);

  void _add() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _items.insert(0, '0$t');
      _c.clear();
      _save();
    });
  }

  @override
  Widget build(BuildContext context) {
    final left = _items.where((e) => e.startsWith('0')).length;
    return ToolList(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                decoration: const InputDecoration(hintText: 'Add a task', border: OutlineInputBorder(), isDense: true),
                onSubmitted: (_) => _add(),
              ),
            ),
            gap(8),
            FilledButton(onPressed: _add, child: const Text('Add')),
          ],
        ),
        gap(),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Nothing to do. Enjoy!')),
          )
        else ...[
          Text('$left of ${_items.length} left', style: const TextStyle(fontSize: 13)),
          Panel(
            children: [
              for (var i = 0; i < _items.length; i++)
                CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  value: _items[i].startsWith('1'),
                  title: Text(_items[i].substring(1), style: TextStyle(fontSize: 15, decoration: _items[i].startsWith('1') ? TextDecoration.lineThrough : null)),
                  secondary: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Remove',
                    onPressed: () => setState(() {
                      _items.removeAt(i);
                      _save();
                    }),
                  ),
                  onChanged: (v) => setState(() {
                    _items[i] = '${v == true ? 1 : 0}${_items[i].substring(1)}';
                    _save();
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------- Text tools
class TextTool extends StatefulWidget {
  const TextTool({super.key});
  @override
  State<TextTool> createState() => _TextState();
}

class _TextState extends State<TextTool> {
  final _c = TextEditingController();

  void _apply(String Function(String) f) => setState(() => _c.text = f(_c.text));

  static String _title(String s) => s.toLowerCase().replaceAllMapped(RegExp(r'(^|\s)(\S)'), (m) => '${m[1]}${m[2]!.toUpperCase()}');

  @override
  Widget build(BuildContext context) {
    final t = _c.text;
    final words = t.trim().isEmpty ? 0 : t.trim().split(RegExp(r'\s+')).length;
    final lines = t.isEmpty ? 0 : '\n'.allMatches(t).length + 1;
    return ToolList(
      children: [
        Panel(
          children: [
            textField(_c, 'Your text', () => setState(() {}), maxLines: 7),
            ResultBox('$words words · ${t.length} characters', sub: '${t.replaceAll(RegExp(r'\s'), '').length} without spaces · $lines lines · about ${(words / 200).ceil()} min read'),
            gap(),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton(onPressed: () => _apply((s) => s.toUpperCase()), child: const Text('UPPER')),
                OutlinedButton(onPressed: () => _apply((s) => s.toLowerCase()), child: const Text('lower')),
                OutlinedButton(onPressed: () => _apply(_title), child: const Text('Title Case')),
                OutlinedButton(onPressed: () => _apply((s) => s.split('').reversed.join()), child: const Text('Reverse')),
                OutlinedButton(onPressed: () => _apply((s) => s.replaceAll(RegExp(r'[ \t]+'), ' ').trim()), child: const Text('Trim spaces')),
                FilledButton(onPressed: () => copyText(context, _c.text), child: const Text('Copy')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Password
class PasswordTool extends StatefulWidget {
  const PasswordTool({super.key});
  @override
  State<PasswordTool> createState() => _PasswordState();
}

class _PasswordState extends State<PasswordTool> {
  double _len = 16;
  bool _lower = true, _upper = true, _digits = true, _symbols = true;
  late String _pw = _make();

  String _make() => generatePassword(_len.round(), lower: _lower, upper: _upper, digits: _digits, symbols: _symbols);
  void _regen() => setState(() => _pw = _make());

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          ResultBox(_pw.isEmpty ? 'Select at least one character type' : _pw),
          gap(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: _regen, icon: const Icon(Icons.refresh), label: const Text('New')),
              ),
              gap(8),
              Expanded(
                child: FilledButton.icon(onPressed: () => copyText(context, _pw), icon: const Icon(Icons.copy), label: const Text('Copy')),
              ),
            ],
          ),
          gap(),
          Text('Length: ${_len.round()}'),
          Slider(
            value: _len,
            min: 6,
            max: 40,
            divisions: 34,
            onChanged: (v) {
              _len = v;
              _regen();
            },
          ),
          for (final o in [
            ('Lowercase a–z', _lower, (bool v) => _lower = v),
            ('Uppercase A–Z', _upper, (bool v) => _upper = v),
            ('Digits', _digits, (bool v) => _digits = v),
            ('Symbols', _symbols, (bool v) => _symbols = v),
          ])
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(o.$1),
              value: o.$2,
              onChanged: (v) {
                o.$3(v);
                _regen();
              },
            ),
          const Text('Generated on your device. Look-alike characters (0/O, 1/l) are left out.', style: TextStyle(fontSize: 12)),
        ],
      ),
    ],
  );
}

// ------------------------------------------------------------------- QR code
class QrTool extends StatefulWidget {
  const QrTool({super.key});
  @override
  State<QrTool> createState() => _QrState();
}

class _QrState extends State<QrTool> {
  final _c = TextEditingController(text: 'Hello from Utility Hub');

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          textField(_c, 'Text or link', () => setState(() {}), maxLines: 3),
          gap(16),
          Center(
            child: _c.text.isEmpty
                ? const Padding(padding: EdgeInsets.all(40), child: Text('Type something to make a QR code'))
                : Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: _c.text,
                      size: 240,
                      errorStateBuilder: (_, __) => const SizedBox(
                        width: 240,
                        height: 240,
                        child: Center(
                          child: Text('Too much text for one QR code', style: TextStyle(color: Colors.black)),
                        ),
                      ),
                    ),
                  ),
          ),
          gap(),
          const Center(child: Text('Show this screen to another phone’s camera to share.', style: TextStyle(fontSize: 13))),
        ],
      ),
    ],
  );
}

// --------------------------------------------------------------------- Morse
class MorseTool extends StatefulWidget {
  const MorseTool({super.key});
  @override
  State<MorseTool> createState() => _MorseState();
}

class _MorseState extends State<MorseTool> {
  final _text = TextEditingController(text: 'SOS'), _code = TextEditingController(text: '... --- ...');
  bool _flashing = false, _lit = false;

  @override
  void dispose() {
    if (_flashing) Torch.set(false);
    _flashing = false;
    super.dispose();
  }

  /// Blinks the code on the LED and on screen. Unit = 180 ms.
  Future<void> _flash() async {
    if (_flashing) {
      _flashing = false;
      return;
    }
    setState(() => _flashing = true);
    const unit = Duration(milliseconds: 180);
    for (final ch in _code.text.split('')) {
      if (!_flashing || !mounted) break;
      if (ch == '.' || ch == '-') {
        Torch.set(true);
        setState(() => _lit = true);
        await Future<void>.delayed(unit * (ch == '.' ? 1 : 3));
        Torch.set(false);
        if (mounted) setState(() => _lit = false);
        await Future<void>.delayed(unit);
      } else {
        await Future<void>.delayed(unit * (ch == '/' ? 2 : 1));
      }
    }
    Torch.set(false);
    if (mounted) {
      setState(() {
        _flashing = false;
        _lit = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          textField(_text, 'Text', () => setState(() => _code.text = toMorse(_text.text)), maxLines: 3),
          gap(),
          textField(_code, 'Morse code ( . and - , words split by / )', () => setState(() => _text.text = fromMorse(_code.text)), maxLines: 3),
          gap(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(onPressed: () => copyText(context, _code.text), icon: const Icon(Icons.copy), label: const Text('Copy code')),
              ),
              gap(8),
              Expanded(
                child: FilledButton.icon(onPressed: _flash, icon: Icon(_flashing ? Icons.stop : Icons.flash_on), label: Text(_flashing ? 'Stop' : 'Flash it')),
              ),
            ],
          ),
          gap(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 40),
            height: 70,
            decoration: BoxDecoration(color: _lit ? Colors.amber : Colors.black12, borderRadius: BorderRadius.circular(10)),
          ),
        ],
      ),
    ],
  );
}

// ----------------------------------------------------------- Clipboard saver
class ClipboardTool extends StatefulWidget {
  const ClipboardTool({super.key});
  @override
  State<ClipboardTool> createState() => _ClipboardState();
}

class _ClipboardState extends State<ClipboardTool> {
  final List<String> _items = Store.list('clips');

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text?.trim() ?? '';
    if (!mounted) return;
    if (t.isEmpty) return toast(context, 'Clipboard is empty');
    setState(() {
      _items
        ..remove(t)
        ..insert(0, t);
      Store.setList('clips', _items);
    });
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      FilledButton.icon(onPressed: _paste, icon: const Icon(Icons.content_paste), label: const Text('Save what I just copied')),
      gap(),
      if (_items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('Saved snippets appear here. Tap one to copy it again.', textAlign: TextAlign.center)),
        )
      else
        for (var i = 0; i < _items.length; i++)
          Card(
            child: ListTile(
              title: Text(_items[i], maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => copyText(context, _items[i]),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete',
                onPressed: () => setState(() {
                  _items.removeAt(i);
                  Store.setList('clips', _items);
                }),
              ),
            ),
          ),
    ],
  );
}

// ---------------------------------------------------------------- PDF reader
class PdfTool extends StatefulWidget {
  const PdfTool({super.key});
  @override
  State<PdfTool> createState() => _PdfState();
}

class _PdfState extends State<PdfTool> {
  PdfController? _ctl;
  String _name = '';
  int _page = 1, _pages = 0;
  String? _error;

  @override
  void dispose() {
    _ctl?.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      final f = r?.files.single;
      final path = f?.path;
      if (f == null || path == null) return;
      final old = _ctl;
      // Reopen each document on the page where the reader left off.
      final start = Store.integer('pdf.page.${f.name}', 1);
      setState(() {
        _name = f.name;
        _page = start;
        _pages = 0;
        _error = null;
        _ctl = PdfController(document: PdfDocument.openFile(path), initialPage: start);
      });
      old?.dispose();
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not open that file.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = _ctl;
    if (ctl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.picture_as_pdf, size: 72, color: Colors.redAccent),
              gap(),
              Text(_error ?? 'Read any PDF stored on your phone.\nYour place in each document is remembered.', textAlign: TextAlign.center),
              gap(16),
              FilledButton.icon(onPressed: _open, icon: const Icon(Icons.folder_open), label: const Text('Open a PDF')),
            ],
          ),
        ),
      );
    }
    const turn = Duration(milliseconds: 200);
    return Column(
      children: [
        Expanded(
          child: PdfView(
            key: ValueKey(ctl),
            controller: ctl,
            onDocumentLoaded: (d) => setState(() => _pages = d.pagesCount),
            onDocumentError: (_) => setState(() {
              _ctl = null;
              _error = 'This PDF could not be read (it may be damaged or password-protected).';
            }),
            onPageChanged: (p) {
              setState(() => _page = p);
              Store.setInt('pdf.page.$_name', p);
            },
          ),
        ),
        Material(
          elevation: 4,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.folder_open), tooltip: 'Open another', onPressed: _open),
              Expanded(
                child: Text(_name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous page',
                onPressed: _page > 1 ? () => ctl.previousPage(duration: turn, curve: Curves.easeOut) : null,
              ),
              Text(_pages == 0 ? '…' : '$_page / $_pages'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next page',
                onPressed: _page < _pages ? () => ctl.nextPage(duration: turn, curve: Curves.easeOut) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
