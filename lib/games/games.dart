import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/store.dart';
import '../core/ui.dart';
import 'block_engine.dart';

const _boardBg = Color(0xFF11131C);

/// Dark board with a centred message shown before a game and after game over.
Widget _overlay(String title, String sub) => Container(
  color: Colors.black54,
  alignment: Alignment.center,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 6),
      Text(
        sub,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        textAlign: TextAlign.center,
      ),
    ],
  ),
);

// ================================================================ Block Drop
class BlockDropGame extends StatefulWidget {
  const BlockDropGame({super.key});
  @override
  State<BlockDropGame> createState() => _BlockDropState();
}

class _BlockDropState extends State<BlockDropGame> {
  static const colors = [Color(0xFF29B6F6), Color(0xFFFFCA28), Color(0xFFAB47BC), Color(0xFF5C6BC0), Color(0xFFFF7043), Color(0xFF66BB6A), Color(0xFFEF5350)];
  final _g = BlockEngine();
  Timer? _timer;
  bool _started = false, _paused = false, _newBest = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_started || _paused || _g.over) return;
    _timer = Timer(Duration(milliseconds: _g.dropMs), () {
      _after(_g.step());
      _schedule();
    });
  }

  void _after(int cleared) {
    if (cleared > 0) HapticFeedback.mediumImpact();
    if (_g.over) _newBest = Scores.submit('blocks', _g.score) && _g.score > 0;
    if (mounted) setState(() {});
  }

  void _start() {
    _g.reset();
    _started = true;
    _paused = false;
    _newBest = false;
    setState(() {});
    _schedule();
  }

  bool get _live => _started && !_paused && !_g.over;

  void _act(void Function() f) {
    if (!_live) return;
    f();
    setState(() {});
  }

  void _tapBoard() {
    if (!_started || _g.over) return _start();
    if (_paused) {
      setState(() => _paused = false);
      return _schedule();
    }
    _act(_g.rotate);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Row(
          children: [
            Stat('Score', '${_g.score}'),
            Stat('Lines', '${_g.lines}'),
            Stat('Level', '${_g.level}'),
            Stat('Best', '${Scores.best('blocks') ?? 0}'),
            SizedBox(width: 52, height: 48, child: CustomPaint(painter: _NextPainter(_g.nextKind, colors))),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: BlockEngine.cols / BlockEngine.rows,
              child: GestureDetector(
                onTap: _tapBoard,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _BlockPainter(_g, colors)),
                      if (!_started) _overlay('Block Drop', 'Tap to start\nTap the board to rotate'),
                      if (_paused) _overlay('Paused', 'Tap to continue'),
                      if (_g.over) _overlay(_newBest ? 'New best: ${_g.score}!' : 'Game over', 'Score ${_g.score} · Tap to play again'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            HoldButton(icon: Icons.arrow_back, repeat: true, onFire: () => _act(() => _g.move(-1))),
            HoldButton(icon: Icons.arrow_forward, repeat: true, onFire: () => _act(() => _g.move(1))),
            HoldButton(icon: Icons.rotate_right, onFire: () => _act(_g.rotate)),
            HoldButton(
              icon: Icons.arrow_downward,
              repeat: true,
              onFire: () {
                if (_live) _after(_g.step());
              },
            ),
            HoldButton(
              icon: Icons.vertical_align_bottom,
              onFire: () {
                if (!_live) return;
                _after(_g.hardDrop());
                _schedule();
              },
            ),
            HoldButton(
              icon: _paused ? Icons.play_arrow : Icons.pause,
              onFire: () {
                if (!_started || _g.over) return;
                setState(() => _paused = !_paused);
                _schedule();
              },
            ),
          ],
        ),
      ],
    ),
  );
}

void _cell(Canvas c, double x, double y, double s, Color col) {
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x + 1, y + 1, s - 2, s - 2), Radius.circular(s * 0.18)), Paint()..color = col);
}

class _BlockPainter extends CustomPainter {
  _BlockPainter(this.g, this.colors);
  final BlockEngine g;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / BlockEngine.cols;
    canvas.drawRect(Offset.zero & size, Paint()..color = _boardBg);
    final line = Paint()..color = Colors.white10;
    for (var c = 1; c < BlockEngine.cols; c++) {
      canvas.drawLine(Offset(c * s, 0), Offset(c * s, size.height), line);
    }
    for (var r = 0; r < BlockEngine.rows; r++) {
      for (var c = 0; c < BlockEngine.cols; c++) {
        if (g.grid[r][c] != 0) _cell(canvas, c * s, r * s, s, colors[g.grid[r][c] - 1]);
      }
    }
    if (g.over) return;
    final ghostY = g.landingY;
    for (var r = 0; r < g.piece.length; r++) {
      for (var c = 0; c < g.piece[r].length; c++) {
        if (g.piece[r][c] == 0) continue;
        _cell(canvas, (g.x + c) * s, (ghostY + r) * s, s, colors[g.kind].withValues(alpha: 0.22));
        _cell(canvas, (g.x + c) * s, (g.y + r) * s, s, colors[g.kind]);
      }
    }
  }

  @override
  bool shouldRepaint(_BlockPainter old) => true;
}

class _NextPainter extends CustomPainter {
  _NextPainter(this.kind, this.colors);
  final int kind;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final m = BlockEngine.shapes[kind];
    const s = 11.0;
    final ox = (size.width - m[0].length * s) / 2, oy = (size.height - m.length * s) / 2;
    for (var r = 0; r < m.length; r++) {
      for (var c = 0; c < m[r].length; c++) {
        if (m[r][c] != 0) _cell(canvas, ox + c * s, oy + r * s, s, colors[kind]);
      }
    }
  }

  @override
  bool shouldRepaint(_NextPainter old) => old.kind != kind;
}

// =============================================================== Paddle Pong
class PongGame extends StatefulWidget {
  const PongGame({super.key});
  @override
  State<PongGame> createState() => _PongState();
}

class _PongState extends State<PongGame> with SingleTickerProviderStateMixin {
  // The court is simulated in a fixed 300×440 space and scaled to the screen.
  static const w = 300.0, h = 440.0, pw = 64.0, ph = 10.0, br = 6.0, winAt = 7;
  late final Ticker _ticker;
  final _frame = ValueNotifier(0);
  final _rng = Random();
  Duration _last = Duration.zero;
  double px = w / 2, cx = w / 2, bx = w / 2, by = h / 2, vx = 0, vy = 0;
  int you = 0, cpu = 0;
  bool _playing = false, _over = false;
  String _msg = 'Tap to serve';

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _serve() {
    if (_over) {
      you = 0;
      cpu = 0;
      _over = false;
    }
    bx = w / 2;
    by = h / 2;
    vx = (_rng.nextDouble() - 0.5) * 3;
    vy = _rng.nextBool() ? 3.2 : -3.2;
    setState(() => _playing = true);
  }

  void _point(bool mine) {
    _playing = false;
    mine ? you++ : cpu++;
    HapticFeedback.lightImpact();
    if (you >= winAt || cpu >= winAt) {
      _over = true;
      final won = you > cpu;
      final streak = won ? Store.integer('pong.streak') + 1 : 0;
      Store.setInt('pong.streak', streak);
      if (won) Scores.submit('pong', streak);
      _msg = won ? 'You win $you–$cpu! Win streak: $streak' : 'Computer wins $cpu–$you';
    } else {
      _msg = mine ? 'Point for you! Tap to serve' : 'Computer scores. Tap to serve';
    }
    setState(() {});
  }

  void _tick(Duration now) {
    final f = min(50, (now - _last).inMilliseconds) / 16.67;
    _last = now;
    if (!_playing) return;
    bx += vx * f;
    by += vy * f;
    if (bx < br) {
      bx = br;
      vx = vx.abs();
    } else if (bx > w - br) {
      bx = w - br;
      vx = -vx.abs();
    }
    // The computer chases the ball at a capped speed that grows as you score.
    final cap = (2.0 + you * 0.3) * f;
    cx = (cx + (bx - cx).clamp(-cap, cap)).clamp(pw / 2, w - pw / 2);
    const cy = 20.0, py = h - 20.0;
    if (vy < 0 && by - br <= cy + ph / 2 && by > cy - ph && (bx - cx).abs() <= pw / 2 + br) {
      by = cy + ph / 2 + br;
      vy = vy.abs() * 1.04;
      vx += (bx - cx) / (pw / 2) * 1.6;
    } else if (vy > 0 && by + br >= py - ph / 2 && by < py + ph && (bx - px).abs() <= pw / 2 + br) {
      by = py - ph / 2 - br;
      vy = -vy.abs() * 1.04;
      vx += (bx - px) / (pw / 2) * 1.6;
    }
    vx = vx.clamp(-6.0, 6.0);
    vy = vy.clamp(-9.0, 9.0);
    if (by < -br) {
      _point(true);
    } else if (by > h + br) {
      _point(false);
    }
    _frame.value++;
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Row(children: [Stat('You', '$you'), Stat('Computer', '$cpu'), Stat('Best streak', '${Scores.best('pong') ?? 0}')]),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: w / h,
              child: LayoutBuilder(
                builder: (_, box) {
                  void drag(Offset p) {
                    px = (p.dx / box.maxWidth * w).clamp(pw / 2, w - pw / 2);
                    _frame.value++;
                  }

                  return GestureDetector(
                    onTapUp: (_) {
                      if (!_playing) _serve();
                    },
                    onPanDown: (d) => drag(d.localPosition),
                    onPanUpdate: (d) => drag(d.localPosition),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CustomPaint(painter: _PongPainter(this, _frame)),
                          if (!_playing) _overlay(_over ? 'Game over' : 'Paddle Pong', '$_msg\nDrag to move · first to $winAt wins'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _PongPainter extends CustomPainter {
  _PongPainter(this.s, Listenable repaint) : super(repaint: repaint);
  final _PongState s;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _PongState.w;
    canvas.scale(k);
    canvas.drawRect(const Rect.fromLTWH(0, 0, _PongState.w, _PongState.h), Paint()..color = _boardBg);
    final dash = Paint()..color = Colors.white24;
    for (var x = 4.0; x < _PongState.w; x += 16) {
      canvas.drawRect(Rect.fromLTWH(x, _PongState.h / 2 - 1, 8, 2), dash);
    }
    RRect pad(double cx, double cy) => RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: _PongState.pw, height: _PongState.ph), const Radius.circular(5));
    canvas.drawRRect(pad(s.cx, 20), Paint()..color = const Color(0xFFEF5350));
    canvas.drawRRect(pad(s.px, _PongState.h - 20), Paint()..color = const Color(0xFF66BB6A));
    canvas.drawCircle(Offset(s.bx, s.by), _PongState.br, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PongPainter old) => false;
}

// ===================================================================== Snake
class SnakeGame extends StatefulWidget {
  const SnakeGame({super.key});
  @override
  State<SnakeGame> createState() => _SnakeState();
}

class _SnakeState extends State<SnakeGame> {
  static const n = 17;
  final _rng = Random();
  List<Point<int>> _snake = [];
  Point<int> _dir = const Point(1, 0), _food = const Point(12, 8);
  final List<Point<int>> _queue = [];
  Timer? _timer;
  bool _started = false, _over = false, _newBest = false;

  int get _score => max(0, _snake.length - 3);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _snake = [const Point(5, 8), const Point(4, 8), const Point(3, 8)];
    _dir = const Point(1, 0);
    _queue.clear();
    _placeFood();
    _started = true;
    _over = false;
    _newBest = false;
    setState(() {});
    _schedule();
  }

  void _placeFood() {
    final free = [
      for (var x = 0; x < n; x++)
        for (var y = 0; y < n; y++)
          if (!_snake.contains(Point(x, y))) Point(x, y),
    ];
    if (free.isNotEmpty) _food = free[_rng.nextInt(free.length)];
  }

  void _schedule() {
    _timer?.cancel();
    // Speeds up as the snake grows.
    _timer = Timer(Duration(milliseconds: max(70, 170 - _score * 3)), _step);
  }

  void _turn(Point<int> d) {
    if (!_started || _over) return;
    final last = _queue.isEmpty ? _dir : _queue.last;
    // Ignore repeats and direct reversals; buffer at most two turns.
    if (d == last || (d.x == -last.x && d.y == -last.y) || _queue.length >= 2) return;
    _queue.add(d);
  }

  void _step() {
    if (_queue.isNotEmpty) _dir = _queue.removeAt(0);
    final head = Point(_snake.first.x + _dir.x, _snake.first.y + _dir.y);
    final eats = head == _food;
    final body = eats ? _snake : _snake.sublist(0, _snake.length - 1);
    if (head.x < 0 || head.y < 0 || head.x >= n || head.y >= n || body.contains(head)) {
      _over = true;
      _newBest = Scores.submit('snake', _score) && _score > 0;
      HapticFeedback.heavyImpact();
      if (mounted) setState(() {});
      return;
    }
    _snake = [head, ...body];
    if (eats) {
      HapticFeedback.selectionClick();
      _placeFood();
    }
    if (mounted) setState(() {});
    _schedule();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(8),
    child: Column(
      children: [
        Row(children: [Stat('Score', '$_score'), Stat('Best', '${Scores.best('snake') ?? 0}')]),
        const SizedBox(height: 8),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: GestureDetector(
                onTap: () {
                  if (!_started || _over) _start();
                },
                onPanUpdate: (d) {
                  final v = d.delta;
                  if (v.distance < 2.5) return;
                  _turn(v.dx.abs() > v.dy.abs() ? Point(v.dx > 0 ? 1 : -1, 0) : Point(0, v.dy > 0 ? 1 : -1));
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(painter: _SnakePainter(_snake, _food)),
                      if (!_started) _overlay('Snake', 'Tap to start\nSwipe or use the arrows to steer'),
                      if (_over) _overlay(_newBest ? 'New best: $_score!' : 'Game over', 'Score $_score · Tap to play again'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            HoldButton(icon: Icons.arrow_back, onFire: () => _turn(const Point(-1, 0))),
            HoldButton(icon: Icons.arrow_upward, onFire: () => _turn(const Point(0, -1))),
            HoldButton(icon: Icons.arrow_downward, onFire: () => _turn(const Point(0, 1))),
            HoldButton(icon: Icons.arrow_forward, onFire: () => _turn(const Point(1, 0))),
          ],
        ),
      ],
    ),
  );
}

class _SnakePainter extends CustomPainter {
  _SnakePainter(this.snake, this.food);
  final List<Point<int>> snake;
  final Point<int> food;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / _SnakeState.n;
    canvas.drawRect(Offset.zero & size, Paint()..color = _boardBg);
    canvas.drawCircle(Offset((food.x + 0.5) * s, (food.y + 0.5) * s), s * 0.38, Paint()..color = const Color(0xFFEF5350));
    for (var i = snake.length - 1; i >= 0; i--) {
      _cell(canvas, snake[i].x * s, snake[i].y * s, s, i == 0 ? const Color(0xFFA5D6A7) : const Color(0xFF66BB6A));
    }
  }

  @override
  bool shouldRepaint(_SnakePainter old) => true;
}

// ============================================================== Memory match
class MemoryGame extends StatefulWidget {
  const MemoryGame({super.key});
  @override
  State<MemoryGame> createState() => _MemoryState();
}

class _MemoryState extends State<MemoryGame> {
  static const _icons = [Icons.star, Icons.favorite, Icons.pets, Icons.anchor, Icons.bolt, Icons.cake, Icons.eco, Icons.music_note];
  static const _tints = [Colors.amber, Colors.red, Colors.brown, Colors.blue, Colors.orange, Colors.pink, Colors.green, Colors.purple];
  late List<int> _cards;
  final Set<int> _matched = {}, _open = {};
  int _moves = 0;
  bool _busy = false, _newBest = false;
  Timer? _flipBack;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _flipBack?.cancel();
    super.dispose();
  }

  void _deal() {
    _flipBack?.cancel();
    _cards = [
      for (var i = 0; i < 8; i++) ...[i, i],
    ]..shuffle();
    _matched.clear();
    _open.clear();
    _moves = 0;
    _busy = false;
    _newBest = false;
  }

  void _tap(int i) {
    if (_busy || _open.contains(i) || _matched.contains(i)) return;
    setState(() => _open.add(i));
    if (_open.length < 2) return;
    _moves++;
    final pair = _open.toList();
    if (_cards[pair[0]] == _cards[pair[1]]) {
      HapticFeedback.selectionClick();
      setState(() {
        _matched.addAll(pair);
        _open.clear();
        if (_matched.length == _cards.length) _newBest = Scores.submit('memory', _moves, lowerIsBetter: true);
      });
    } else {
      _busy = true;
      _flipBack = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _open.clear();
          _busy = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final won = _matched.length == _cards.length;
    final best = Scores.best('memory');
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [Stat('Moves', '$_moves'), Stat('Pairs', '${_matched.length ~/ 2}/8'), Stat('Best', best == null ? '—' : '$best')]),
          const SizedBox(height: 8),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < _cards.length; i++)
                      GestureDetector(
                        onTap: () => _tap(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: _matched.contains(i) ? Colors.green.withValues(alpha: 0.25) : (_open.contains(i) ? cs.surfaceContainerHighest : cs.primary),
                          ),
                          child: _open.contains(i) || _matched.contains(i)
                              ? Icon(_icons[_cards[i]], size: 38, color: _tints[_cards[i]])
                              : Icon(Icons.question_mark, color: cs.onPrimary.withValues(alpha: 0.5)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (won)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_newBest ? 'New best: $_moves moves!' : 'Solved in $_moves moves', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
          FilledButton(onPressed: () => setState(_deal), child: Text(won ? 'Play again' : 'Restart')),
        ],
      ),
    );
  }
}

// ================================================================ Tic-tac-toe
class TicTacToeGame extends StatefulWidget {
  const TicTacToeGame({super.key});
  @override
  State<TicTacToeGame> createState() => _TicTacToeState();
}

/// Returns 'X', 'O', 'draw' or null while the game is still open.
String? tttWinner(List<String> b) {
  const lines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];
  for (final l in lines) {
    if (b[l[0]].isNotEmpty && b[l[0]] == b[l[1]] && b[l[1]] == b[l[2]]) return b[l[0]];
  }
  return b.every((c) => c.isNotEmpty) ? 'draw' : null;
}

/// Computer move: win if possible, else block, else centre, else random.
int tttMove(List<String> b, Random rng) {
  final free = [
    for (var i = 0; i < 9; i++)
      if (b[i].isEmpty) i,
  ];
  for (final who in ['O', 'X']) {
    for (final i in free) {
      final t = List.of(b)..[i] = who;
      if (tttWinner(t) == who) return i;
    }
  }
  if (b[4].isEmpty) return 4;
  return free[rng.nextInt(free.length)];
}

class _TicTacToeState extends State<TicTacToeGame> {
  final _rng = Random();
  List<String> _b = List.filled(9, '');
  String? _result;
  Timer? _cpu;
  bool _thinking = false;
  int _w = Store.integer('ttt.w'), _l = Store.integer('ttt.l'), _d = Store.integer('ttt.d');

  @override
  void dispose() {
    _cpu?.cancel();
    super.dispose();
  }

  void _finishIfDone() {
    final r = tttWinner(_b);
    if (r == null) return;
    _result = r;
    if (r == 'X') {
      Store.setInt('ttt.w', ++_w);
      Scores.submit('ttt', _w);
    } else if (r == 'O') {
      Store.setInt('ttt.l', ++_l);
    } else {
      Store.setInt('ttt.d', ++_d);
    }
  }

  void _tap(int i) {
    if (_b[i].isNotEmpty || _result != null || _thinking) return;
    setState(() {
      _b[i] = 'X';
      _finishIfDone();
    });
    if (_result != null) return;
    _thinking = true;
    _cpu = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _b[tttMove(_b, _rng)] = 'O';
        _thinking = false;
        _finishIfDone();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final msg = switch (_result) {
      'X' => 'You win!',
      'O' => 'Computer wins',
      'draw' => 'It’s a draw',
      _ => 'Your turn — you are X',
    };
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(children: [Stat('Wins', '$_w'), Stat('Losses', '$_l'), Stat('Draws', '$_d')]),
          const SizedBox(height: 8),
          Text(msg, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (var i = 0; i < 9; i++)
                      GestureDetector(
                        onTap: () => _tap(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(14)),
                          child: Text(
                            _b[i],
                            style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: _b[i] == 'X' ? cs.primary : Colors.redAccent),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => setState(() {
              _cpu?.cancel();
              _thinking = false;
              _b = List.filled(9, '');
              _result = null;
            }),
            child: const Text('New game'),
          ),
        ],
      ),
    );
  }
}
