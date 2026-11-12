import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'core/ui.dart';

/// Appearance settings: light / dark / system mode and the accent colour.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _presets = <Color>[
    brandColor,
    Color(0xFF3F51B5),
    Color(0xFF6A1B9A),
    Color(0xFFAD1457),
    Color(0xFFC62828),
    Color(0xFFE65100),
    Color(0xFFF9A825),
    Color(0xFF2E7D32),
    Color(0xFF00796B),
    Color(0xFF00838F),
    Color(0xFF5D4037),
    Color(0xFF455A64),
  ];
  final _theme = AppTheme.instance;
  late final _hex = TextEditingController(text: hexOf(_theme.color));

  void _pick(Color c, {bool fromHexField = false}) {
    _theme.setColor(c);
    if (!fromHexField) _hex.text = hexOf(_theme.color);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hsv = HSVColor.fromColor(_theme.color);
    Widget slider(String label, double value, double max, HSVColor Function(double) apply) => Row(
      children: [
        SizedBox(width: 84, child: Text(label)),
        Expanded(
          child: Slider(value: value.clamp(0, max), max: max, onChanged: (v) => _pick(apply(v).toColor())),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: ToolList(
          children: [
            Panel(
              children: [
                const Text('Mode', style: TextStyle(fontWeight: FontWeight.w600)),
                gap(8),
                SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, label: Text('Auto'), icon: Icon(Icons.brightness_auto)),
                    ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                  ],
                  selected: {_theme.mode},
                  onSelectionChanged: (s) => setState(() => _theme.setMode(s.first)),
                ),
                gap(8),
                const Text('Auto follows your phone’s light or dark setting.', style: TextStyle(fontSize: 12)),
              ],
            ),
            Panel(
              children: [
                const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                gap(),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in _presets)
                      Semantics(
                        button: true,
                        label: 'Color ${hexOf(c)}',
                        child: GestureDetector(
                          onTap: () => _pick(c),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(color: _theme.color == c ? cs.onSurface : Colors.transparent, width: 3),
                            ),
                            child: _theme.color == c ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Panel(
              children: [
                const Text('Custom color', style: TextStyle(fontWeight: FontWeight.w600)),
                gap(),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _theme.color,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cs.outline),
                      ),
                    ),
                    gap(),
                    Expanded(
                      child: TextField(
                        controller: _hex,
                        autocorrect: false,
                        decoration: const InputDecoration(labelText: 'Hex code', hintText: '#275A89', border: OutlineInputBorder(), isDense: true),
                        onChanged: (v) {
                          final c = parseHex(v);
                          if (c != null) _pick(c, fromHexField: true);
                        },
                      ),
                    ),
                  ],
                ),
                gap(8),
                slider('Hue', hsv.hue, 360, (v) => hsv.withHue(v)),
                slider('Saturation', hsv.saturation, 1, (v) => hsv.withSaturation(v)),
                slider('Brightness', hsv.value, 1, (v) => hsv.withValue(v)),
                // Live sample of how the chosen colour is used around the app.
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(onPressed: () {}, child: const Text('Button')),
                    ),
                    gap(8),
                    Expanded(
                      child: FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
                    ),
                    gap(8),
                    Expanded(
                      child: OutlinedButton(onPressed: () {}, child: const Text('Outline')),
                    ),
                  ],
                ),
                gap(),
                OutlinedButton.icon(onPressed: _theme.isDefaultColor ? null : () => _pick(brandColor), icon: const Icon(Icons.restart_alt), label: const Text('Reset to the default blue')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
