import 'dart:math';

/// Rules for the falling-block puzzle, with no Flutter dependency so they can be unit-tested.
class BlockEngine {
  BlockEngine({Random? rng}) : _rng = rng ?? Random() {
    reset();
  }

  static const cols = 10, rows = 20;
  static const shapes = <List<List<int>>>[
    [
      [1, 1, 1, 1],
    ],
    [
      [1, 1],
      [1, 1],
    ],
    [
      [0, 1, 0],
      [1, 1, 1],
    ],
    [
      [1, 0, 0],
      [1, 1, 1],
    ],
    [
      [0, 0, 1],
      [1, 1, 1],
    ],
    [
      [0, 1, 1],
      [1, 1, 0],
    ],
    [
      [1, 1, 0],
      [0, 1, 1],
    ],
  ];

  final Random _rng;

  /// 0 = empty, otherwise shape index + 1 (used to pick a colour).
  late List<List<int>> grid;
  late List<List<int>> piece;
  late int kind, nextKind, x, y;
  int score = 0, lines = 0;
  bool over = false;

  int get level => 1 + lines ~/ 10;

  /// Milliseconds between automatic drops at the current level.
  int get dropMs => max(90, 800 - (level - 1) * 70);

  void reset() {
    grid = List.generate(rows, (_) => List.filled(cols, 0));
    score = 0;
    lines = 0;
    over = false;
    nextKind = _rng.nextInt(shapes.length);
    _spawn();
  }

  void _spawn() {
    kind = nextKind;
    nextKind = _rng.nextInt(shapes.length);
    piece = [for (final r in shapes[kind]) List.of(r)];
    x = (cols - piece[0].length) ~/ 2;
    y = 0;
    if (collides(piece, x, y)) over = true;
  }

  bool collides(List<List<int>> m, int px, int py) {
    for (var r = 0; r < m.length; r++) {
      for (var c = 0; c < m[r].length; c++) {
        if (m[r][c] == 0) continue;
        final gx = px + c, gy = py + r;
        if (gx < 0 || gx >= cols || gy >= rows) return true;
        if (gy >= 0 && grid[gy][gx] != 0) return true;
      }
    }
    return false;
  }

  static List<List<int>> rotated(List<List<int>> m) => [
    for (var c = 0; c < m[0].length; c++) [for (var r = m.length - 1; r >= 0; r--) m[r][c]],
  ];

  bool move(int dx) {
    if (over || collides(piece, x + dx, y)) return false;
    x += dx;
    return true;
  }

  /// Rotates clockwise, nudging sideways if a wall is in the way.
  bool rotate() {
    if (over) return false;
    final r = rotated(piece);
    for (final k in const [0, -1, 1, -2, 2]) {
      if (!collides(r, x + k, y)) {
        piece = r;
        x += k;
        return true;
      }
    }
    return false;
  }

  /// Row the current piece would land on (for the ghost outline).
  int get landingY {
    var gy = y;
    while (!collides(piece, x, gy + 1)) {
      gy++;
    }
    return gy;
  }

  /// Moves the piece down one row; locks it if it cannot move.
  /// Returns the number of lines cleared by a lock, or -1 if it simply moved.
  int step() {
    if (over) return 0;
    if (!collides(piece, x, y + 1)) {
      y++;
      return -1;
    }
    return _lock();
  }

  int hardDrop() {
    if (over) return 0;
    final ly = landingY;
    score += (ly - y) * 2;
    y = ly;
    return _lock();
  }

  int _lock() {
    for (var r = 0; r < piece.length; r++) {
      for (var c = 0; c < piece[r].length; c++) {
        if (piece[r][c] != 0 && y + r >= 0) grid[y + r][x + c] = kind + 1;
      }
    }
    final lv = level;
    grid.removeWhere((row) => row.every((v) => v != 0));
    final cleared = rows - grid.length;
    for (var i = 0; i < cleared; i++) {
      grid.insert(0, List.filled(cols, 0));
    }
    lines += cleared;
    score += const [0, 100, 300, 500, 800][cleared] * lv;
    _spawn();
    return cleared;
  }
}
