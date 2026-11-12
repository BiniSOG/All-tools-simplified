import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';

import 'package:toolbox/core/locker.dart';
import 'package:toolbox/core/logic.dart';
import 'package:toolbox/core/store.dart';
import 'package:toolbox/games/block_engine.dart';
import 'package:toolbox/games/games.dart';
import 'package:toolbox/tools/camera_tools.dart';
import 'package:toolbox/tools/util_tools.dart';

void main() {
  test('calculator', () {
    expect(evaluate('2+3*4'), 14);
    expect(evaluate('(2+3)*4'), 20);
    expect(evaluate('-5+2'), -3);
    expect(evaluate('8/-2'), -4);
    expect(evaluate('50%*200'), 100);
    expect(evaluate('(1+2'), 3);
    expect(evaluate('1/0').isInfinite, true);
    expect(() => evaluate('2+'), throwsFormatException);
    expect(() => evaluate('2)3'), throwsFormatException);
    expect(fmtNum(0.1 + 0.2), '0.3');
    expect(fmtNum(1234567.5), '1,234,567.5');
    expect(fmtNum(-1000), '-1,000');
  });

  test('units', () {
    expect(convert('Length', 1, 'mile', 'km'), closeTo(1.609344, 1e-9));
    expect(convert('Temperature', 100, '°C', '°F'), closeTo(212, 1e-9));
    expect(convert('Temperature', 32, '°F', 'K'), closeTo(273.15, 1e-9));
    expect(convert('Weight', 1, 'pound', 'g'), closeTo(453.59237, 1e-9));
    expect(convert('Data', 1, 'GB', 'MB'), 1024);
  });

  test('bmi, emi, dates', () {
    expect(bmi(70, 175), closeTo(22.857, 0.001));
    expect(emi(100000, 12, 12), closeTo(8884.88, 0.01));
    expect(emi(1200, 0, 12), 100);
    final d = dateDiff(DateTime(2000, 2, 29), DateTime(2024, 3, 1));
    expect([d.years, d.months, d.days], [24, 0, 1]);
    expect(dateDiff(DateTime(2024, 1, 31), DateTime(2024, 3, 1)).totalDays, 30);
    final e = dateDiff(DateTime(2023, 12, 25), DateTime(2024, 1, 5));
    expect([e.years, e.months, e.days, e.totalDays], [0, 0, 11, 11]);
  });

  test('morse', () {
    expect(toMorse('SOS'), '... --- ...');
    expect(toMorse('hi  you'), '.... .. / -.-- --- ..-');
    expect(fromMorse('.... .. / -.-- --- ..-'), 'HI YOU');
    expect(fromMorse('... ....... ...'), 'S?S');
  });

  test('password', () {
    final p = generatePassword(20, symbols: true, rng: Random(1));
    expect(p.length, 20);
    expect(p, matches(RegExp(r'[a-z]')));
    expect(p, matches(RegExp(r'[A-Z]')));
    expect(p, matches(RegExp(r'[0-9]')));
    expect(generatePassword(8, lower: false, upper: false, symbols: false), matches(RegExp(r'^[2-9]{8}$')));
    expect(generatePassword(8, lower: false, upper: false, digits: false), '');
  });

  test('clock text', () {
    expect(clockText(65000), '01:05');
    expect(clockText(3723400, tenths: true), '1:02:03.4');
  });

  test('compass heading', () {
    // Phone flat, top edge pointing north: field points +y (north) and down (-z).
    expect(headingFrom([0, 0, 9.8], [0, 30, -40]), closeTo(0, 0.01));
    // Top edge pointing east: north is on the phone's -x side.
    expect(headingFrom([0, 0, 9.8], [-30, 0, -40]), closeTo(90, 0.01));
    expect(headingFrom([0, 0, 9.8], [0, -30, -40]), closeTo(180, 0.01));
    expect(headingFrom([0, 0, 0], [0, 0, 0]), isNull);
  });

  test('block engine', () {
    final g = BlockEngine(rng: Random(3));
    expect(
      BlockEngine.rotated([
        [1, 0, 0],
        [1, 1, 1],
      ]),
      [
        [1, 1],
        [1, 0],
        [1, 0],
      ],
    );
    // walls stop movement
    for (var i = 0; i < 20; i++) {
      g.move(-1);
    }
    expect(g.x, 0);
    expect(g.move(-1), false);
    // fill the bottom row except the cells a vertical bar will take, then drop it in
    g.reset();
    for (var c = 1; c < BlockEngine.cols; c++) {
      g.grid[BlockEngine.rows - 1][c] = 1;
    }
    g.kind = 0;
    g.piece = [
      [1],
      [1],
      [1],
      [1],
    ];
    g.x = 0;
    g.y = 0;
    expect(g.hardDrop(), 1);
    expect(g.lines, 1);
    expect(g.score, 100 + 16 * 2);
    // the three leftover bar cells fell one row
    expect(g.grid[BlockEngine.rows - 1][0], 1);
    expect(g.grid[BlockEngine.rows - 4][0], 0);
    expect(g.grid.length, BlockEngine.rows);
    // stacking to the top ends the game
    var guard = 0;
    while (!g.over && guard++ < 500) {
      g.hardDrop();
    }
    expect(g.over, true);
  });

  test('tic-tac-toe AI', () {
    expect(tttWinner(['X', 'X', 'X', '', '', '', '', '', '']), 'X');
    expect(tttWinner(['X', 'O', 'X', 'X', 'O', 'O', 'O', 'X', 'X']), 'draw');
    expect(tttWinner(List.filled(9, '')), isNull);
    // takes the win
    expect(tttMove(['O', 'O', '', 'X', 'X', '', '', '', ''], Random(1)), 2);
    // blocks
    expect(tttMove(['X', 'X', '', '', 'O', '', '', '', ''], Random(1)), 2);
  });

  test('streak and scores', () async {
    SharedPreferences.setMockInitialValues({});
    await Store.init();
    expect(Streak.touch(DateTime(2026, 1, 31)), false);
    expect(Streak.days, 1);
    expect(Streak.touch(DateTime(2026, 1, 31, 23)), false);
    expect(Streak.touch(DateTime(2026, 2, 1)), true);
    expect(Streak.days, 2);
    Streak.touch(DateTime(2026, 2, 5));
    expect([Streak.days, Streak.best], [1, 2]);
    expect(Scores.submit('g', 10), true);
    expect(Scores.submit('g', 5), false);
    expect(Scores.submit('m', 20, lowerIsBetter: true), true);
    expect(Scores.submit('m', 12, lowerIsBetter: true), true);
    expect(Scores.best('m'), 12);
  });

  test('measurement maths', () {
    expect(pressureAltitude(1013.25), closeTo(0, 0.01));
    expect(pressureAltitude(899), closeTo(1000, 15));
    expect(rpmFromTaps([0, 500, 1000, 1500]), 120);
    expect(rpmFromTaps([0]), isNull);
    expect(mbps(12500000, 1000), 100);
    expect(rssiLabel(-50), 'Excellent');
    expect(rssiLabel(-90), 'Very weak');
  });

  test('step detector counts walking, ignores standing still', () {
    final still = StepDetector();
    for (var t = 0; t < 5000; t += 20) {
      still.add(9.8 + 0.2 * sin(t / 50), t);
    }
    expect(still.steps, 0);
    // two steps per second for ten seconds
    final walk = StepDetector();
    for (var t = 0; t < 10000; t += 20) {
      walk.add(9.8 + 3.5 * sin(2 * pi * 2 * t / 1000), t);
    }
    expect(walk.steps, inInclusiveRange(18, 21));
  });

  test('heart rate from a pulsing signal', () {
    const fps = 30.0;
    // 72 beats per minute = 1.2 Hz, riding on a slowly drifting baseline
    final v = [for (var i = 0; i < 300; i++) 150 + i * 0.02 + 2 * sin(2 * pi * 1.2 * i / fps)];
    expect(bpmFromSamples(v, fps), closeTo(72, 3));
    expect(bpmFromSamples(List.filled(300, 150.0), fps), isNull);
    expect(bpmFromSamples(v.sublist(0, 60), fps), isNull);
  });

  test('colour conversions', () {
    expect(yuvToRgb(255, 128, 128), (255, 255, 255));
    expect(yuvToRgb(0, 128, 128), (0, 0, 0));
    final red = yuvToRgb(76, 85, 255);
    expect(red.$1, greaterThan(240));
    expect(red.$2, lessThan(20));
    expect(rgbToCmyk(255, 0, 0), (0, 100, 100, 0));
    expect(rgbToCmyk(0, 0, 0), (0, 0, 0, 100));
    expect(colorName(250, 20, 20), 'Red');
    expect(colorName(250, 250, 250), 'White');
    expect(colorName(20, 60, 230), 'Blue');
  });

  test('motion grid comparison', () {
    final a = List.filled(192, 100), b = List.of(a);
    expect(gridChange(a, b), 0);
    for (var i = 0; i < 48; i++) {
      b[i] = 200;
    }
    expect(gridChange(a, b), 0.25);
  });

  test('tone generator writes a valid looping WAV', () {
    final w = toneWav(440, seconds: 1);
    expect(String.fromCharCodes(w.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(w.sublist(8, 12)), 'WAVE');
    final data = ByteData.sublistView(Uint8List.fromList(w));
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint32(40, Endian.little), w.length - 44);
    expect(w.length - 44, closeTo(88200, 200));
    // whole cycles: the first sample is zero and the last is just below zero, so the loop is seamless
    expect(data.getInt16(44, Endian.little), 0);
    expect(data.getInt16(w.length - 2, Endian.little), inInclusiveRange(-1500, -1));
    expect(sliderToHz(hzToSlider(1000)), closeTo(1000, 0.001));
    expect(sliderToHz(0), 20);
    expect(sliderToHz(1), closeTo(20000, 0.001));
  });

  test('billing totals and file helpers', () {
    final t = billTotals([BillItem('A', 2, 10), BillItem('B', 1, 5.5)], discountPct: 10, taxPct: 20);
    expect(t.subtotal, 25.5);
    expect(t.discount, closeTo(2.55, 1e-9));
    expect(t.tax, closeTo(4.59, 1e-9));
    expect(t.total, closeTo(27.54, 1e-9));
    expect(money(1234.5), '1,234.5');
    expect(BillItem.fromJson(BillItem('x', 3, 1.5).toJson()).total, 4.5);
    expect(safeFileName('../../etc/passwd'), 'passwd');
    expect(safeFileName(r'C:\Users\me\photo 1.jpg'), 'photo 1.jpg');
    expect(safeFileName('.hidden'), 'hidden');
    expect(safeFileName('a<b>:c.txt'), 'a_b__c.txt');
    expect(safeFileName('///'), 'file');
    expect(fileSize(1536), '1.5 KB');
    expect(fileSize(5 * 1048576), '5.0 MB');
  });

  test('file locker encrypts, decrypts, and rejects a wrong PIN', () async {
    final salt = List.generate(16, (i) => i);
    final key = await LockerCrypto.deriveKey('1234', salt, iterations: 50);
    final secret = List.generate(5000, (i) => i % 251);
    final blob = await LockerCrypto.encrypt(secret, key);
    expect(blob.length, greaterThan(secret.length));
    expect(blob.sublist(12, 60), isNot(secret.sublist(0, 48)));
    expect(await LockerCrypto.decrypt(blob, key), secret);
    final wrong = await LockerCrypto.deriveKey('1235', salt, iterations: 50);
    expect(await LockerCrypto.decrypt(blob, wrong), isNull);
    blob[40] ^= 1; // tampering is detected
    expect(await LockerCrypto.decrypt(blob, key), isNull);
  });
}
