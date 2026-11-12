import 'package:flutter/material.dart';

import '../core/logic.dart';
import '../core/store.dart';
import '../core/ui.dart';

// ---------------------------------------------------------------- Calculator
class CalculatorTool extends StatefulWidget {
  const CalculatorTool({super.key});
  @override
  State<CalculatorTool> createState() => _CalculatorState();
}

class _CalculatorState extends State<CalculatorTool> {
  static const _ops = '+−×÷';
  static const _keys = ['C', '( )', '%', '÷', '7', '8', '9', '×', '4', '5', '6', '−', '1', '2', '3', '+', '0', '.', '⌫', '='];
  String _expr = Store.str('calc.expr');
  bool _justEq = false;

  String _js(String s) => s.replaceAll('×', '*').replaceAll('÷', '/').replaceAll('−', '-');

  String get _preview {
    if (_expr.isEmpty) return '0';
    try {
      return fmtNum(evaluate(_js(_expr)));
    } catch (_) {
      return '';
    }
  }

  void _press(String k) {
    final last = _expr.isEmpty ? '' : _expr[_expr.length - 1];
    setState(() {
      if (k == 'C') {
        _expr = '';
      } else if (k == '⌫') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length - 1);
      } else if (k == '=') {
        try {
          final v = evaluate(_js(_expr));
          if (v.isFinite) {
            var s = double.parse(v.toStringAsPrecision(12)).toString();
            if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
            _expr = s.replaceAll('-', '−');
            _justEq = true;
            Store.setStr('calc.expr', _expr);
            return;
          }
        } catch (_) {
          toast(context, 'Check the expression');
        }
      } else if (k == '( )') {
        final open = '('.allMatches(_expr).length - ')'.allMatches(_expr).length;
        _expr += (open > 0 && last != '(' && !_ops.contains(last)) ? ')' : '(';
      } else {
        final isOp = _ops.contains(k);
        if (_justEq && !isOp && k != '%') _expr = '';
        if (isOp && _expr.isEmpty && k != '−') return;
        // Replace a trailing operator, but allow "×−" style negatives.
        if (isOp && last.isNotEmpty && _ops.contains(last) && !(k == '−' && last != '−')) {
          _expr = _expr.substring(0, _expr.length - 1);
        }
        _expr += k;
      }
      _justEq = false;
      Store.setStr('calc.expr', _expr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: Container(
            alignment: Alignment.bottomRight,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              reverse: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_expr.isEmpty ? ' ' : _expr, style: TextStyle(fontSize: 22, color: cs.onSurfaceVariant)),
                  Text(_preview.isEmpty ? ' ' : _preview, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            children: [
              for (var r = 0; r < 5; r++)
                Row(
                  children: [
                    for (final k in _keys.sublist(r * 4, r * 4 + 4))
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(3),
                          child: SizedBox(
                            height: 58,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                padding: EdgeInsets.zero,
                                backgroundColor: k == '=' ? cs.primary : (RegExp(r'[0-9.]').hasMatch(k) ? cs.surfaceContainerHighest : cs.secondaryContainer),
                                foregroundColor: k == '=' ? cs.onPrimary : cs.onSurface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () => _press(k),
                              child: Text(k, style: const TextStyle(fontSize: 22)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Unit converter
class UnitTool extends StatefulWidget {
  const UnitTool({super.key});
  @override
  State<UnitTool> createState() => _UnitState();
}

class _UnitState extends State<UnitTool> {
  String _cat = 'Length', _from = 'mm', _to = 'cm';
  final _val = TextEditingController(text: '1');

  void _setCat(String c) {
    final u = units[c]!.keys.toList();
    setState(() {
      _cat = c;
      _from = u[0];
      _to = u[1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = units[_cat]!.keys.toList();
    final v = numOf(_val);
    return ToolList(
      children: [
        Panel(
          children: [
            dropdown('Category', _cat, units.keys.toList(), _setCat),
            gap(),
            numField(_val, 'Value', () => setState(() {})),
            gap(),
            Row(
              children: [
                Expanded(child: dropdown('From', _from, u, (x) => setState(() => _from = x))),
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Swap',
                  onPressed: () => setState(() {
                    final t = _from;
                    _from = _to;
                    _to = t;
                  }),
                ),
                Expanded(child: dropdown('To', _to, u, (x) => setState(() => _to = x))),
              ],
            ),
            ResultBox(v == null ? 'Enter a value' : '${fmtNum(v)} $_from = ${fmtNum(convert(_cat, v, _from, _to))} $_to'),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Percentage
class PercentTool extends StatefulWidget {
  const PercentTool({super.key});
  @override
  State<PercentTool> createState() => _PercentState();
}

class _PercentState extends State<PercentTool> {
  final _a = TextEditingController(), _b = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final x = numOf(_a), y = numOf(_b);
    void up() => setState(() {});
    return ToolList(
      children: [
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: numField(_a, 'X', up)),
                gap(8),
                Expanded(child: numField(_b, 'Y', up)),
              ],
            ),
            if (x == null || y == null)
              const ResultBox('Enter X and Y')
            else ...[
              ResultBox('${fmtNum(x)}% of ${fmtNum(y)} = ${fmtNum(x * y / 100)}'),
              ResultBox('${fmtNum(x)} is ${fmtNum(y == 0 ? double.nan : x / y * 100)}% of ${fmtNum(y)}'),
              ResultBox('Change from ${fmtNum(x)} to ${fmtNum(y)} = ${fmtNum(x == 0 ? double.nan : (y - x) / x.abs() * 100)}%'),
              ResultBox('${fmtNum(y)} with ${fmtNum(x)}% off = ${fmtNum(y - y * x / 100)}'),
            ],
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Tip & split
class TipTool extends StatefulWidget {
  const TipTool({super.key});
  @override
  State<TipTool> createState() => _TipState();
}

class _TipState extends State<TipTool> {
  final _bill = TextEditingController(), _tip = TextEditingController(text: '15'), _ppl = TextEditingController(text: '2');

  @override
  Widget build(BuildContext context) {
    void up() => setState(() {});
    final b = numOf(_bill), t = numOf(_tip) ?? 0;
    final p = (numOf(_ppl) ?? 1).floor().clamp(1, 1000);
    return ToolList(
      children: [
        Panel(
          children: [
            numField(_bill, 'Bill', up, hint: '0.00'),
            gap(),
            Row(
              children: [
                Expanded(child: numField(_tip, 'Tip %', up)),
                gap(8),
                Expanded(child: numField(_ppl, 'People', up)),
              ],
            ),
            if (b == null)
              const ResultBox('Enter the bill amount')
            else
              ResultBox('Each pays: ${((b + b * t / 100) / p).toStringAsFixed(2)}', sub: 'Tip ${(b * t / 100).toStringAsFixed(2)} · Total ${(b + b * t / 100).toStringAsFixed(2)}'),
          ],
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------- BMI
class BmiTool extends StatefulWidget {
  const BmiTool({super.key});
  @override
  State<BmiTool> createState() => _BmiState();
}

class _BmiState extends State<BmiTool> {
  final _h = TextEditingController(text: Store.str('bmi.h')), _w = TextEditingController();

  @override
  Widget build(BuildContext context) {
    void up() => setState(() {});
    final h = numOf(_h), w = numOf(_w);
    Widget out = const ResultBox('Enter height and weight');
    if (h != null && w != null && h > 0 && w > 0) {
      Store.setStr('bmi.h', _h.text);
      final b = bmi(w, h);
      final label = b < 18.5 ? 'Underweight' : (b < 25 ? 'Healthy weight' : (b < 30 ? 'Overweight' : 'Obese'));
      out = ResultBox('BMI ${b.toStringAsFixed(1)} — $label', sub: 'Adult ranges. A general guide only, not medical advice.');
    }
    return ToolList(
      children: [
        Panel(
          children: [
            Row(
              children: [
                Expanded(child: numField(_h, 'Height (cm)', up)),
                gap(8),
                Expanded(child: numField(_w, 'Weight (kg)', up)),
              ],
            ),
            out,
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Age & dates
class DatesTool extends StatefulWidget {
  const DatesTool({super.key});
  @override
  State<DatesTool> createState() => _DatesState();
}

class _DatesState extends State<DatesTool> {
  DateTime? _a = DateTime.tryParse(Store.str('dates.a'));
  DateTime _b = DateTime.now();

  String _f(DateTime? d) => d == null ? 'Tap to choose' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool first) async {
    final d = await showDatePicker(context: context, initialDate: (first ? _a : _b) ?? DateTime(2000), firstDate: DateTime(1900), lastDate: DateTime(2200));
    if (d == null) return;
    setState(() => first ? _a = d : _b = d);
    if (first) Store.setStr('dates.a', d.toIso8601String());
  }

  @override
  Widget build(BuildContext context) {
    Widget out = const ResultBox('Pick a start date');
    final a = _a;
    if (a != null) {
      final swapped = a.isAfter(_b);
      final r = swapped ? dateDiff(_b, a) : dateDiff(a, _b);
      out = ResultBox(
        '${r.years} years, ${r.months} months, ${r.days} days',
        sub: '${fmtNum(r.totalDays.toDouble())} days · ${fmtNum((r.totalDays ~/ 7).toDouble())} weeks${swapped ? ' (start is after end)' : ''}',
      );
    }
    return ToolList(
      children: [
        Panel(
          children: [
            ListTile(leading: const Icon(Icons.cake_outlined), title: const Text('From (e.g. your birthday)'), subtitle: Text(_f(_a)), onTap: () => _pick(true)),
            ListTile(leading: const Icon(Icons.event), title: const Text('To'), subtitle: Text(_f(_b)), onTap: () => _pick(false)),
            out,
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ EMI calculator
class EmiTool extends StatefulWidget {
  const EmiTool({super.key});
  @override
  State<EmiTool> createState() => _EmiState();
}

class _EmiState extends State<EmiTool> {
  final _p = TextEditingController(), _r = TextEditingController(text: '10'), _n = TextEditingController(text: '12');

  @override
  Widget build(BuildContext context) {
    void up() => setState(() {});
    final p = numOf(_p), r = numOf(_r), n = numOf(_n)?.floor();
    Widget out = const ResultBox('Enter loan amount, rate and months');
    if (p != null && r != null && n != null && n > 0 && p > 0 && r >= 0) {
      final e = emi(p, r, n);
      out = ResultBox(
        'Monthly payment: ${fmtNum(double.parse(e.toStringAsFixed(2)))}',
        sub: 'Total paid ${fmtNum(double.parse((e * n).toStringAsFixed(2)))} · Interest ${fmtNum(double.parse((e * n - p).toStringAsFixed(2)))}',
      );
    }
    return ToolList(
      children: [
        Panel(
          children: [
            numField(_p, 'Loan amount', up),
            gap(),
            Row(
              children: [
                Expanded(child: numField(_r, 'Interest % per year', up)),
                gap(8),
                Expanded(child: numField(_n, 'Months', up)),
              ],
            ),
            out,
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- Number base
class BaseTool extends StatefulWidget {
  const BaseTool({super.key});
  @override
  State<BaseTool> createState() => _BaseState();
}

class _BaseState extends State<BaseTool> {
  static const _defs = [('Decimal', 10), ('Binary', 2), ('Hex', 16), ('Octal', 8)];
  final _c = [for (final _ in _defs) TextEditingController()];

  @override
  void initState() {
    super.initState();
    _c[0].text = '255';
    _update(0);
  }

  void _update(int i) {
    final s = _c[i].text.replaceAll(' ', '');
    final v = BigInt.tryParse(s, radix: _defs[i].$2);
    for (var j = 0; j < _c.length; j++) {
      if (j == i) continue;
      _c[j].text = s.isEmpty ? '' : (v == null || v.isNegative ? 'invalid' : v.toRadixString(_defs[j].$2).toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) => ToolList(
    children: [
      Panel(
        children: [
          for (var i = 0; i < _defs.length; i++) ...[
            TextField(
              controller: _c[i],
              autocorrect: false,
              decoration: InputDecoration(labelText: _defs[i].$1, border: const OutlineInputBorder(), isDense: true),
              onChanged: (_) => _update(i),
            ),
            if (i < _defs.length - 1) gap(),
          ],
        ],
      ),
    ],
  );
}
