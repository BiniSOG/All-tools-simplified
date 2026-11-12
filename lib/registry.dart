import 'package:flutter/material.dart';

import 'games/games.dart';
import 'tools/calc_tools.dart';
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
const categories = <String, String>{'games': 'Games', 'calc': 'Calculators', 'time': 'Time', 'text': 'Notes & documents', 'util': 'Utilities'};

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

  ToolDef('flashlight', 'Flashlight', 'util', Icons.flashlight_on, const Color(0xFFFFA000), () => const FlashlightTool(), 'torch light led'),
  ToolDef('compass', 'Compass', 'util', Icons.explore, const Color(0xFF1976D2), () => const CompassTool(), 'north direction'),
  ToolDef('level', 'Bubble Level', 'util', Icons.architecture, const Color(0xFF388E3C), () => const LevelTool(), 'leveler spirit tilt'),
  ToolDef('metal', 'Metal Detector', 'util', Icons.sensors, const Color(0xFF757575), () => const MetalTool(), 'magnet magnetic'),
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
