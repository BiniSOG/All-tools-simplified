import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toolbox/core/store.dart';
import 'package:toolbox/core/theme.dart';
import 'package:toolbox/main.dart';
import 'package:toolbox/registry.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    AppTheme.instance.load();
  });

  testWidgets('home lists tools, search filters, favourite persists', (t) async {
    await t.pumpWidget(const ToolboxApp());
    expect(find.text('Utility Hub'), findsOneWidget);
    expect(find.textContaining('Game of the day'), findsOneWidget);

    await t.enterText(find.byType(TextField), 'ping');
    await t.pump();
    expect(find.text('Paddle Pong'), findsOneWidget);
    expect(find.text('Calculator'), findsNothing);

    await t.enterText(find.byType(TextField), 'calc');
    await t.pump();
    await t.tap(find.text('Calculator'));
    await t.pumpAndSettle();
    for (final k in ['7', '×', '6', '=']) {
      await t.tap(find.widgetWithText(FilledButton, k));
      await t.pump();
    }
    expect(find.text('42'), findsWidgets);
    await t.tap(find.byIcon(Icons.star_border));
    await t.pump();
    expect(Store.list('favs'), ['calculator']);
    expect(Store.list('recent'), ['calculator']);
  });

  // Every tool must build and tear down cleanly on a small (old-phone sized) screen.
  for (final tool in allTools) {
    testWidgets('opens: ${tool.name}', (t) async {
      t.view.physicalSize = const Size(320, 480);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: ToolPage(tool)));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(tool.name), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  testWidgets('block drop plays through a start and pause', (t) async {
    await t.pumpWidget(MaterialApp(home: ToolPage(toolById('blocks')!)));
    await t.tap(find.textContaining('Tap to start'));
    await t.pump(const Duration(seconds: 2));
    expect(find.textContaining('Tap to start'), findsNothing);
    await t.tap(find.byIcon(Icons.pause));
    await t.pump();
    expect(find.text('Paused'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('snake dies at the wall and records a score', (t) async {
    await t.pumpWidget(MaterialApp(home: ToolPage(toolById('snake')!)));
    await t.tap(find.textContaining('Tap to start'));
    await t.pump(const Duration(seconds: 5));
    expect(find.textContaining('Game over'), findsOneWidget);
    expect(Scores.best('snake'), 0);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('appearance: custom colour and dark mode apply and persist', (t) async {
    await t.pumpWidget(const ToolboxApp());
    Color primary() => Theme.of(t.element(find.text('Utility Hub'))).colorScheme.primary;
    final before = primary();
    expect(AppTheme.instance.color, brandColor);

    await t.tap(find.byIcon(Icons.palette_outlined));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextField, 'Hex code'), '#C62828');
    await t.pumpAndSettle();
    expect(AppTheme.instance.color, const Color(0xFFC62828));
    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    expect(Theme.of(t.element(find.text('Appearance'))).brightness, Brightness.dark);

    await t.pageBack();
    await t.pumpAndSettle();
    expect(primary(), isNot(before));

    // A fresh launch restores both choices from storage.
    AppTheme.instance.load();
    expect(AppTheme.instance.mode, ThemeMode.dark);
    expect(hexOf(AppTheme.instance.color), '#C62828');
    expect(parseHex('fa0'), const Color(0xFFFFAA00));
    expect(parseHex('nope'), isNull);
  });
}
