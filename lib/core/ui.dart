import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scrolling body used by form-style tools.
class ToolList extends StatelessWidget {
  const ToolList({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(12), children: children);
}

/// A padded card that stacks its children vertically.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

/// Highlighted result area.
class ResultBox extends StatelessWidget {
  const ResultBox(this.title, {super.key, this.sub});
  final String title;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(title, style: TextStyle(fontSize: 17, color: cs.onSecondaryContainer)),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(sub!, style: TextStyle(fontSize: 13, color: cs.onSecondaryContainer)),
            ),
        ],
      ),
    );
  }
}

Widget gap([double h = 12]) => SizedBox(height: h, width: h);

Widget numField(TextEditingController c, String label, VoidCallback onChanged, {String? hint}) => TextField(
  controller: c,
  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
  decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true),
  onChanged: (_) => onChanged(),
);

Widget textField(TextEditingController c, String label, VoidCallback onChanged, {int maxLines = 1, String? hint}) => TextField(
  controller: c,
  maxLines: maxLines,
  decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder(), isDense: true, alignLabelWithHint: true),
  onChanged: (_) => onChanged(),
);

Widget dropdown<T>(String label, T value, List<T> items, ValueChanged<T> onChanged) => InputDecorator(
  decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      items: [
        for (final i in items)
          DropdownMenuItem(
            value: i,
            child: Text('$i', overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  ),
);

/// Accepts "1.5" and "1,5".
double? numOf(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1600), behavior: SnackBarBehavior.floating));
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, 'Copied');
}

/// Game control button: fires on press, and optionally auto-repeats while held.
class HoldButton extends StatefulWidget {
  const HoldButton({super.key, required this.icon, required this.onFire, this.repeat = false});
  final IconData icon;
  final VoidCallback onFire;
  final bool repeat;

  @override
  State<HoldButton> createState() => _HoldButtonState();
}

class _HoldButtonState extends State<HoldButton> {
  Timer? _delay, _rep;
  bool _down = false;

  void _start() {
    _stop();
    setState(() => _down = true);
    widget.onFire();
    if (widget.repeat) {
      _delay = Timer(const Duration(milliseconds: 220), () {
        _rep = Timer.periodic(const Duration(milliseconds: 70), (_) => widget.onFire());
      });
    }
  }

  void _stop() {
    _delay?.cancel();
    _rep?.cancel();
    if (_down && mounted) setState(() => _down = false);
  }

  @override
  void dispose() {
    _delay?.cancel();
    _rep?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Listener(
        onPointerDown: (_) => _start(),
        onPointerUp: (_) => _stop(),
        onPointerCancel: (_) => _stop(),
        child: Container(
          height: 56,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: _down ? cs.primary.withValues(alpha: 0.7) : cs.primary, borderRadius: BorderRadius.circular(12)),
          child: Icon(widget.icon, color: cs.onPrimary, size: 28),
        ),
      ),
    );
  }
}

/// Small labelled number shown above a game board.
class Stat extends StatelessWidget {
  const Stat(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
            Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
