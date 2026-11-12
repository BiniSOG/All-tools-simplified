import 'package:flutter/material.dart';

import 'games/games.dart';
import 'tools/audio_tools.dart';
import 'tools/calc_tools.dart';
import 'tools/camera_tools.dart';
import 'tools/measure_tools.dart';
import 'tools/net_tools.dart';
import 'tools/office_tools.dart';
import 'tools/text_tools.dart';
import 'tools/time_tools.dart';
import 'tools/util_tools.dart';

class ToolDef {
  const ToolDef(this.id, this.name, this.cat, this.icon, this.color, this.builder, [this.tags = '']);
  final String id, name, cat, tags;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
}

/// Home-screen sections, in display order.
const categories = <String, String>{
  'games': 'Games',
  'calc': 'Calculators',
  'measure': 'Measure & navigate',
  'camera': 'Camera',
  'audio': 'Sound',
  'net': 'Connect & share',
  'text': 'Notes & documents',
  'time': 'Time',
  'util': 'Utilities',
};

/// Every tool in the app. To add one: write the widget, then add a line here.
final List<ToolDef> allTools = [
  ToolDef('blocks', 'Block Drop', 'games', Icons.grid_view_rounded, const Color(0xFF5C6BC0), () => const BlockDropGame(), 'falling blocks puzzle'),
  ToolDef('pong', 'Paddle Pong', 'games', Icons.sports_tennis, const Color(0xFF26A69A), () => const PongGame(), 'ping pong table tennis'),
  ToolDef('snake', 'Snake', 'games', Icons.gesture, const Color(0xFF66BB6A), () => const SnakeGame()),
  ToolDef('memory', 'Memory Match', 'games', Icons.style, const Color(0xFFAB47BC), () => const MemoryGame(), 'cards pairs'),
  ToolDef('ttt', 'Tic-Tac-Toe', 'games', Icons.tag, const Color(0xFFEF5350), () => const TicTacToeGame(), 'noughts crosses xo'),

  ToolDef('calculator', 'Calculator', 'calc', Icons.calculate, const Color(0xFF3F51B5), () => const CalculatorTool(), 'math sum'),
  ToolDef('units', 'Unit Converter', 'calc', Icons.straighten, const Color(0xFF00897B), () => const UnitTool(), 'length weight temperature convert'),
  ToolDef('percent', 'Percentage', 'calc', Icons.percent, const Color(0xFFE65100), () => const PercentTool(), 'discount sale change'),
  ToolDef('emi', 'Loan / EMI', 'calc', Icons.account_balance, const Color(0xFF6D4C41), () => const EmiTool(), 'interest mortgage instalment'),
  ToolDef('tip', 'Tip & Split', 'calc', Icons.receipt_long, const Color(0xFF2E7D32), () => const TipTool(), 'bill restaurant share'),
  ToolDef('bmi', 'BMI', 'calc', Icons.monitor_weight, const Color(0xFFAD1457), () => const BmiTool(), 'body mass index health'),
  ToolDef('dates', 'Age & Dates', 'calc', Icons.cake, const Color(0xFF5E35B1), () => const DatesTool(), 'birthday days between'),
  ToolDef('base', 'Number Base', 'calc', Icons.pin, const Color(0xFF455A64), () => const BaseTool(), 'binary hex octal decimal'),

  ToolDef('ruler', 'Ruler', 'measure', Icons.straighten, const Color(0xFFF9A825), () => const RulerTool(), 'cm inch length measure'),
  ToolDef('protractor', 'Protractor', 'measure', Icons.looks, const Color(0xFF7E57C2), () => const ProtractorTool(), 'angle degrees'),
  ToolDef('speedometer', 'Speedometer', 'measure', Icons.speed, const Color(0xFFD84315), () => const SpeedometerTool(), 'gps speed distance trip'),
  ToolDef('altitude', 'Altitude', 'measure', Icons.terrain, const Color(0xFF5D4037), () => const AltitudeTool(), 'height elevation sea level'),
  ToolDef('pressure', 'Air Pressure', 'measure', Icons.compress, const Color(0xFF0277BD), () => const PressureTool(), 'barometer hpa weather'),
  ToolDef('gmeter', 'G-Meter', 'measure', Icons.rocket_launch, const Color(0xFFC2185B), () => const GMeterTool(), 'acceleration g-force'),
  ToolDef('vibro', 'Vibrometer', 'measure', Icons.vibration, const Color(0xFF00897B), () => const VibrometerTool(), 'vibration shake seismometer'),
  ToolDef('rpm', 'RPM', 'measure', Icons.rotate_right, const Color(0xFF455A64), () => const RpmTool(), 'rotations tachometer tempo bpm'),
  ToolDef('light', 'Light Meter', 'measure', Icons.wb_sunny, const Color(0xFFFFA000), () => const LightMeterTool(), 'lux brightness'),
  ToolDef('signal', 'Signal Strength', 'measure', Icons.network_wifi, const Color(0xFF1976D2), () => const SignalTool(), 'wifi rssi dbm'),
  ToolDef('steps', 'Steps Tracker', 'measure', Icons.directions_walk, const Color(0xFF43A047), () => const StepsTool(), 'pedometer walk calories health'),
  ToolDef('heart', 'Heart Rate', 'measure', Icons.favorite, const Color(0xFFE53935), () => const HeartRateTool(), 'pulse bpm health'),

  ToolDef('magnifier', 'Magnifier', 'camera', Icons.zoom_in, const Color(0xFF3949AB), () => const MagnifierTool(), 'zoom magnifying glass small text'),
  ToolDef('scanner', 'Document Scanner', 'camera', Icons.document_scanner, const Color(0xFF00838F), () => const ScannerTool(), 'scan pdf paper'),
  ToolDef('colordetect', 'Color Detector', 'camera', Icons.colorize, const Color(0xFFEC407A), () => const ColorDetectorTool(), 'rgb hex cmyk hsv picker'),
  ToolDef('mirror', 'Mirror', 'camera', Icons.face, const Color(0xFF8E24AA), () => const MirrorTool(), 'selfie front camera'),
  ToolDef('night', 'Night Camera', 'camera', Icons.nightlight, const Color(0xFF283593), () => const NightCameraTool(), 'low light dark night vision'),
  ToolDef('motion', 'Motion Camera', 'camera', Icons.directions_run, const Color(0xFFEF6C00), () => const MotionCameraTool(), 'movement detect security capture'),

  ToolDef('soundmeter', 'Sound Meter', 'audio', Icons.graphic_eq, const Color(0xFF00897B), () => const SoundMeterTool(), 'decibel noise loudness db'),
  ToolDef('tone', 'Sound Generator', 'audio', Icons.waves, const Color(0xFF5E35B1), () => const SoundGeneratorTool(), 'frequency tone hz'),
  ToolDef('music', 'Music Player', 'audio', Icons.library_music, const Color(0xFFD81B60), () => const MusicPlayerTool(), 'songs audio mp3'),
  ToolDef('tts', 'Text to Speech', 'audio', Icons.record_voice_over, const Color(0xFF1E88E5), () => const TtsTool(), 'read aloud speak voice'),
  ToolDef('stt', 'Speech to Text', 'audio', Icons.mic, const Color(0xFFF4511E), () => const SttTool(), 'dictation transcribe voice'),

  ToolDef('transfer', 'File Transfer', 'net', Icons.swap_horiz, const Color(0xFF2E7D32), () => const FileTransferTool(), 'share send receive wifi'),
  ToolDef('ipcam', 'IP Camera', 'net', Icons.videocam, const Color(0xFF6D4C41), () => const IpCameraTool(), 'cctv stream live security'),
  ToolDef('speedtest', 'Internet Speed', 'net', Icons.network_check, const Color(0xFF0288D1), () => const SpeedTestTool(), 'download upload ping mbps'),
  ToolDef('stopwatch', 'Stopwatch', 'time', Icons.timer_outlined, const Color(0xFF1565C0), () => const StopwatchTool(), 'lap'),
  ToolDef('timer', 'Timer', 'time', Icons.hourglass_bottom, const Color(0xFFC62828), () => const TimerTool(), 'countdown alarm'),
  ToolDef('worldclock', 'World Clock', 'time', Icons.public, const Color(0xFF00838F), () => const WorldClockTool(), 'time zone cities'),

  ToolDef('pdf', 'PDF Reader', 'text', Icons.picture_as_pdf, const Color(0xFFD32F2F), () => const PdfTool(), 'document book read'),
  ToolDef('notes', 'Notes', 'text', Icons.sticky_note_2, const Color(0xFFF9A825), () => const NotesTool(), 'memo write'),
  ToolDef('todo', 'To-Do List', 'text', Icons.checklist, const Color(0xFF43A047), () => const TodoTool(), 'tasks checklist'),
  ToolDef('text', 'Text Tools', 'text', Icons.text_fields, const Color(0xFF546E7A), () => const TextTool(), 'word count case upper lower'),
  ToolDef('clips', 'Clipboard', 'text', Icons.content_paste, const Color(0xFF7E57C2), () => const ClipboardTool(), 'copy paste snippets'),
  ToolDef('qr', 'QR Generator', 'text', Icons.qr_code_2, const Color(0xFF263238), () => const QrTool(), 'barcode share link'),
  ToolDef('morse', 'Morse Code', 'text', Icons.more_horiz, const Color(0xFF8D6E63), () => const MorseTool(), 'sos signal'),
  ToolDef('password', 'Password', 'text', Icons.key, const Color(0xFF00695C), () => const PasswordTool(), 'generator secure'),
  ToolDef('billing', 'Billing', 'text', Icons.receipt, const Color(0xFF2E7D32), () => const BillingTool(), 'invoice bill shop receipt'),
  ToolDef('barcode', 'Barcode Maker', 'text', Icons.view_week, const Color(0xFF37474F), () => const BarcodeTool(), 'ean upc code128 generator'),
  ToolDef('locker', 'File Locker', 'text', Icons.lock, const Color(0xFF6A1B9A), () => const FileLockerTool(), 'encrypt secure hide private vault'),

  ToolDef('flashlight', 'Flashlight', 'util', Icons.flashlight_on, const Color(0xFFFFA000), () => const FlashlightTool(), 'torch light led'),
  ToolDef('compass', 'Compass', 'measure', Icons.explore, const Color(0xFF1976D2), () => const CompassTool(), 'north direction'),
  ToolDef('level', 'Bubble Level', 'measure', Icons.architecture, const Color(0xFF388E3C), () => const LevelTool(), 'leveler spirit tilt'),
  ToolDef('metal', 'Metal Detector', 'measure', Icons.sensors, const Color(0xFF757575), () => const MetalTool(), 'magnet magnetic'),
  ToolDef('paint', 'Paint', 'util', Icons.brush, const Color(0xFFEC407A), () => const PaintTool(), 'draw sketch doodle'),
  ToolDef('counter', 'Tally Counter', 'util', Icons.plus_one, const Color(0xFF0097A7), () => const CounterTool(), 'number count clicker'),
  ToolDef('random', 'Dice & Random', 'util', Icons.casino, const Color(0xFF6A1B9A), () => const RandomTool(), 'coin flip number'),
  ToolDef('color', 'Color Mixer', 'util', Icons.palette, const Color(0xFFF4511E), () => const ColorTool(), 'hex rgb hsl'),
];

ToolDef? toolById(String id) {
  for (final t in allTools) {
    if (t.id == id) return t;
  }
  return null;
}
