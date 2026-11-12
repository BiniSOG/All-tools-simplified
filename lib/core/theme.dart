import 'package:flutter/material.dart';

import 'store.dart';

/// The blue of the app icon; used until the user picks their own colour.
const brandColor = Color(0xFF275A89);

/// App-wide appearance: accent colour and light / dark / follow-system mode.
/// Both are saved on the device and applied instantly when changed.
class AppTheme extends ChangeNotifier {
  AppTheme._();
  static final AppTheme instance = AppTheme._();

  ThemeMode _mode = ThemeMode.system;
  Color _color = brandColor;

  ThemeMode get mode => _mode;
  Color get color => _color;
  bool get isDefaultColor => _color == brandColor;

  /// Reads the saved choice. Call after [Store.init].
  void load() {
    _mode = switch (Store.str('theme.mode')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    final saved = Store.integer('theme.color', -1);
    _color = saved < 0 ? brandColor : Color(0xFF000000 | saved);
    notifyListeners();
  }

  void setMode(ThemeMode m) {
    _mode = m;
    Store.setStr('theme.mode', m.name);
    notifyListeners();
  }

  void setColor(Color c) {
    _color = Color(0xFF000000 | (c.toARGB32() & 0xFFFFFF));
    Store.setInt('theme.color', _color.toARGB32() & 0xFFFFFF);
    notifyListeners();
  }

  /// Builds the Material theme for [brightness] from the chosen accent colour.
  ThemeData build(Brightness brightness) {
    // "fidelity" keeps the generated palette close to the exact colour picked.
    final cs = ColorScheme.fromSeed(seedColor: _color, brightness: brightness, dynamicSchemeVariant: DynamicSchemeVariant.fidelity);
    final dark = brightness == Brightness.dark;
    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      // Light mode shows the exact chosen colour in the title bar, with readable text on top.
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? cs.surfaceContainer : _color,
        foregroundColor: dark ? cs.onSurface : (ThemeData.estimateBrightnessForColor(_color) == Brightness.dark ? Colors.white : Colors.black),
        surfaceTintColor: Colors.transparent,
      ),
      // The simple fade transition is cheaper than the default zoom on slow phones.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()}),
    );
  }
}

String hexOf(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Parses "#RRGGBB" / "RRGGBB" / "#RGB"; returns null if it is not a colour.
Color? parseHex(String input) {
  var s = input.trim().replaceFirst('#', '');
  if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) return null;
  return Color(0xFF000000 | int.parse(s, radix: 16));
}
