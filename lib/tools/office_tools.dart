import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:cryptography/cryptography.dart' show SecretKey;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/locker.dart';
import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

const _small = TextStyle(fontSize: 13);

// ------------------------------------------------------------------- Billing
class BillingTool extends StatefulWidget {
  const BillingTool({super.key});
  @override
  State<BillingTool> createState() => _BillingState();
}

class _BillingState extends State<BillingTool> {
  final _shop = TextEditingController(), _customer = TextEditingController();
  final _tax = TextEditingController(text: '0'), _disc = TextEditingController(text: '0');
  final _name = TextEditingController(), _qty = TextEditingController(text: '1'), _price = TextEditingController();
  List<BillItem> _items = [];

  @override
  void initState() {
    super.initState();
    final j = Store.json('bill');
    if (j is Map<String, dynamic>) {
      _shop.text = '${j['shop'] ?? ''}';
      _customer.text = '${j['customer'] ?? ''}';
      _tax.text = '${j['tax'] ?? 0}';
      _disc.text = '${j['disc'] ?? 0}';
      try {
        _items = [for (final i in j['items'] as List) BillItem.fromJson(i as Map<String, dynamic>)];
      } catch (_) {}
    }
  }

  void _save() {
    Store.setJson('bill', {'shop': _shop.text, 'customer': _customer.text, 'tax': _tax.text, 'disc': _disc.text, 'items': _items.map((i) => i.toJson()).toList()});
    setState(() {});
  }

  void _add() {
    final q = numOf(_qty), p = numOf(_price);
    if (_name.text.trim().isEmpty || q == null || p == null || q <= 0 || p < 0) return toast(context, 'Enter an item name, quantity and price');
    _items.add(BillItem(_name.text.trim(), q, p));
    _name.clear();
    _price.clear();
    _qty.text = '1';
    _save();
  }

  ({double subtotal, double discount, double tax, double total}) get _totals => billTotals(_items, discountPct: numOf(_disc) ?? 0, taxPct: numOf(_tax) ?? 0);

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _asText() {
    final t = _totals;
    return [
      if (_shop.text.trim().isNotEmpty) _shop.text.trim(),
      'Bill · ${_today()}',
      if (_customer.text.trim().isNotEmpty) 'Customer: ${_customer.text.trim()}',
      '',
      for (final i in _items) '${i.name}  ${fmtNum(i.qty)} x ${money(i.price)} = ${money(i.total)}',
      '',
      'Subtotal: ${money(t.subtotal)}',
      if (t.discount > 0) 'Discount: -${money(t.discount)}',
      if (t.tax > 0) 'Tax: ${money(t.tax)}',
      'TOTAL: ${money(t.total)}',
    ].join('\n');
  }

  Future<void> _pdf() async {
    try {
      final t = _totals;
      // The built-in PDF font covers Latin letters only; anything else is replaced so the file still builds.
      String a(String s) => s.replaceAll(RegExp(r'[^\x20-\x7E\xA0-\xFF]'), '?');
      pw.Widget cell(String s, {bool bold = false, bool right = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(
          a(s),
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
        ),
      );
      final doc = pw.Document()
        ..addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(36),
            build: (_) => [
              pw.Text(a(_shop.text.trim().isEmpty ? 'Invoice' : _shop.text.trim()), style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Date: ${_today()}'),
              if (_customer.text.trim().isNotEmpty) pw.Text(a('Customer: ${_customer.text.trim()}')),
              pw.SizedBox(height: 16),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.5),
                columnWidths: const {0: pw.FlexColumnWidth(4), 1: pw.FlexColumnWidth(1.2), 2: pw.FlexColumnWidth(1.6), 3: pw.FlexColumnWidth(1.8)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                    children: [cell('Item', bold: true), cell('Qty', bold: true, right: true), cell('Price', bold: true, right: true), cell('Amount', bold: true, right: true)],
                  ),
                  for (final i in _items) pw.TableRow(children: [cell(i.name), cell(fmtNum(i.qty), right: true), cell(money(i.price), right: true), cell(money(i.total), right: true)]),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${money(t.subtotal)}'),
                    if (t.discount > 0) pw.Text('Discount: -${money(t.discount)}'),
                    if (t.tax > 0) pw.Text('Tax: ${money(t.tax)}'),
                    pw.SizedBox(height: 4),
                    pw.Text('Total: ${money(t.total)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        );
      final where = await FilePicker.saveFile(fileName: 'Bill_${_today()}.pdf', bytes: await doc.save());
      if (mounted && where != null) toast(context, 'PDF saved');
    } catch (_) {
      if (mounted) toast(context, 'Could not create the PDF');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _totals;
    return ToolList(
      children: [
        Panel(children: [textField(_shop, 'Your shop or name', _save), gap(8), textField(_customer, 'Customer (optional)', _save)]),
        Panel(
          children: [
            textField(_name, 'Item', () {}),
            gap(8),
            Row(
              children: [
                Expanded(child: numField(_qty, 'Qty', () {})),
                gap(8),
                Expanded(flex: 2, child: numField(_price, 'Price each', () {})),
                gap(8),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
            for (var i = 0; i < _items.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(_items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${fmtNum(_items[i].qty)} × ${money(_items[i].price)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(money(_items[i].total), style: const TextStyle(fontSize: 15)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Remove',
                      onPressed: () {
                        _items.removeAt(i);
                        _save();
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: numField(_disc, 'Discount %', _save)),
                gap(8),
                Expanded(child: numField(_tax, 'Tax %', _save)),
              ],
            ),
            ResultBox('Total: ${money(t.total)}', sub: 'Subtotal ${money(t.subtotal)} · Discount ${money(t.discount)} · Tax ${money(t.tax)}'),
            gap(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(onPressed: _items.isEmpty ? null : () => copyText(context, _asText()), icon: const Icon(Icons.copy), label: const Text('Copy')),
                ),
                gap(8),
                Expanded(
                  child: FilledButton.icon(onPressed: _items.isEmpty ? null : _pdf, icon: const Icon(Icons.picture_as_pdf), label: const Text('PDF')),
                ),
              ],
            ),
            TextButton(
              onPressed: _items.isEmpty
                  ? null
                  : () {
                      _items.clear();
                      _customer.clear();
                      _save();
                    },
              child: const Text('Start a new bill'),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- Barcode
class BarcodeTool extends StatefulWidget {
  const BarcodeTool({super.key});
  @override
  State<BarcodeTool> createState() => _BarcodeState();
}

class _BarcodeState extends State<BarcodeTool> {
  static final _types = <String, (Barcode, String)>{
    'Code 128 (any text)': (Barcode.code128(), 'ABC-12345'),
    'EAN-13 (shop products)': (Barcode.ean13(), '590123412345'),
    'EAN-8': (Barcode.ean8(), '9638507'),
    'UPC-A (US products)': (Barcode.upcA(), '03600029145'),
    'Code 39': (Barcode.code39(), 'HELLO 123'),
    'ITF (cartons)': (Barcode.itf(), '1234567890'),
    'Codabar': (Barcode.codabar(), 'A12345B'),
    'Data Matrix': (Barcode.dataMatrix(), 'Utility Hub'),
    'PDF417': (Barcode.pdf417(), 'Utility Hub'),
    'Aztec': (Barcode.aztec(), 'Utility Hub'),
  };
  String _type = _types.keys.first;
  late final _c = TextEditingController(text: _types[_type]!.$2);

  @override
  Widget build(BuildContext context) {
    final bc = _types[_type]!.$1;
    final square = _type == 'Data Matrix' || _type == 'Aztec';
    return ToolList(
      children: [
        Panel(
          children: [
            dropdown('Barcode type', _type, _types.keys.toList(), (t) {
              setState(() {
                _type = t;
                _c.text = _types[t]!.$2;
              });
            }),
            gap(),
            textField(_c, 'Content', () => setState(() {})),
            gap(16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(14),
              child: _c.text.isEmpty
                  ? const SizedBox(
                      height: 120,
                      child: Center(
                        child: Text('Type the content above', style: TextStyle(color: Colors.black)),
                      ),
                    )
                  : Center(
                      child: BarcodeWidget(
                        barcode: bc,
                        data: _c.text,
                        width: square ? 180 : double.infinity,
                        height: square ? 180 : 120,
                        color: Colors.black,
                        style: const TextStyle(color: Colors.black, fontSize: 13),
                        errorBuilder: (_, e) => const SizedBox(
                          height: 120,
                          child: Center(
                            child: Text(
                              'This content does not fit this barcode type.\nCheck the length and allowed characters.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            gap(),
            const Text('Product codes (EAN, UPC) take digits only and add their own check digit. For QR codes, use the QR Generator.', style: _small),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- File locker
class FileLockerTool extends StatefulWidget {
  const FileLockerTool({super.key});
  @override
  State<FileLockerTool> createState() => _FileLockerState();
}

class _FileLockerState extends State<FileLockerTool> {
  static const _maxBytes = 30 * 1024 * 1024;
  final _pin = TextEditingController(), _pin2 = TextEditingController();
  SecretKey? _key;
  bool _busy = false;
  String _error = '';
  // Each entry: {id, name, size}
  List<Map<String, dynamic>> _files = [];

  bool get _hasPin => Store.str('locker.salt').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final j = Store.json('locker.files');
    if (j is List) _files = [for (final e in j) Map<String, dynamic>.from(e as Map)];
  }

  Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/locker');
    await d.create(recursive: true);
    return d;
  }

  Future<void> _submitPin() async {
    final pin = _pin.text;
    if (pin.length < 4) return setState(() => _error = 'Use at least 4 characters.');
    if (!_hasPin && pin != _pin2.text) return setState(() => _error = 'The two entries do not match.');
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      if (!_hasPin) {
        final rng = Random.secure();
        final salt = [for (var i = 0; i < 16; i++) rng.nextInt(256)];
        final key = await LockerCrypto.deriveKey(pin, salt);
        // A small encrypted marker lets a later unlock tell a right PIN from a wrong one.
        Store.setStr('locker.check', base64Encode(await LockerCrypto.encrypt(utf8.encode('utility-hub'), key)));
        Store.setStr('locker.salt', base64Encode(salt));
        _key = key;
      } else {
        final key = await LockerCrypto.deriveKey(pin, base64Decode(Store.str('locker.salt')));
        final ok = await LockerCrypto.decrypt(base64Decode(Store.str('locker.check')), key);
        if (ok == null) {
          _error = 'Wrong PIN.';
        } else {
          _key = key;
        }
      }
    } catch (_) {
      _error = 'Something went wrong. Try again.';
    }
    _pin.clear();
    _pin2.clear();
    if (mounted) setState(() => _busy = false);
  }

  void _saveIndex() => Store.setJson('locker.files', _files);

  Future<void> _add() async {
    final key = _key;
    if (key == null) return;
    try {
      final r = await FilePicker.pickFiles();
      final f = r?.files.single;
      if (f?.path == null || !mounted) return;
      if (f!.size > _maxBytes) return toast(context, 'That file is too large (limit 30 MB)');
      setState(() => _busy = true);
      final id = '${DateTime.now().microsecondsSinceEpoch}';
      await File('${(await _dir()).path}/$id.bin').writeAsBytes(await LockerCrypto.encrypt(await File(f.path!).readAsBytes(), key));
      _files.insert(0, {'id': id, 'name': f.name, 'size': f.size});
      _saveIndex();
      if (mounted) toast(context, 'Locked. Now delete the original from your gallery or files app.');
    } catch (_) {
      if (mounted) toast(context, 'Could not lock that file');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _export(Map<String, dynamic> e) async {
    final key = _key;
    if (key == null) return;
    setState(() => _busy = true);
    try {
      final blob = await File('${(await _dir()).path}/${e['id']}.bin').readAsBytes();
      final plain = await LockerCrypto.decrypt(blob, key);
      if (plain == null) throw const FormatException('damaged');
      final where = await FilePicker.saveFile(fileName: '${e['name']}', bytes: Uint8List.fromList(plain));
      if (mounted && where != null) toast(context, 'Unlocked copy saved');
    } catch (_) {
      if (mounted) toast(context, 'Could not unlock that file');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(Map<String, dynamic> e) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this locked file?'),
        content: Text('“${e['name']}” will be removed for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await File('${(await _dir()).path}/${e['id']}.bin').delete();
    } catch (_) {}
    _files.remove(e);
    _saveIndex();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_key == null) {
      return ToolList(
        children: [
          const Icon(Icons.lock, size: 56),
          gap(8),
          Text(_hasPin ? 'Enter your PIN to open the locker.' : 'Choose a PIN. Files you add are encrypted with it and can only be opened here.', textAlign: TextAlign.center),
          gap(),
          TextField(
            controller: _pin,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'PIN or password', border: OutlineInputBorder(), isDense: true),
            onSubmitted: (_) => _hasPin ? _submitPin() : null,
          ),
          if (!_hasPin) ...[
            gap(8),
            TextField(
              controller: _pin2,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Type it again', border: OutlineInputBorder(), isDense: true),
            ),
          ],
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          gap(),
          FilledButton(onPressed: _busy ? null : _submitPin, child: Text(_busy ? 'Working…' : (_hasPin ? 'Unlock' : 'Create locker'))),
          gap(),
          const Text('There is no way to recover a forgotten PIN: the files cannot be opened without it. A longer password is much safer than 4 digits.', textAlign: TextAlign.center, style: _small),
        ],
      );
    }
    return ToolList(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(onPressed: _busy ? null : _add, icon: const Icon(Icons.add), label: const Text('Lock a file')),
            ),
            gap(8),
            OutlinedButton.icon(onPressed: () => setState(() => _key = null), icon: const Icon(Icons.lock_outline), label: const Text('Close')),
          ],
        ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
        gap(),
        if (_files.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('No locked files yet.')),
          )
        else
          for (final e in _files)
            Card(
              child: ListTile(
                leading: const Icon(Icons.lock),
                title: Text('${e['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(fileSize((e['size'] as num).toInt())),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.lock_open), tooltip: 'Save an unlocked copy', onPressed: _busy ? null : () => _export(e)),
                    IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: _busy ? null : () => _delete(e)),
                  ],
                ),
              ),
            ),
        gap(),
        const Text('Locking stores an encrypted copy inside this app. The original stays where it was until you delete it yourself. Uninstalling the app removes locked files.', style: _small),
      ],
    );
  }
}
