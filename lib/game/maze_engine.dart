import 'dart:math' as math;

import '../core/arcade.dart';
import '../core/level_plan.dart';
import '../core/rng.dart';

/// Wall bits.
const int kN = 1, kE = 2, kS = 4, kW = 8;
const _bit = [kN, kE, kS, kW];
const _dx = [0, 1, 0, -1];
const _dy = [-1, 0, 1, 0];

class MazeLevel {
  final ArcadeMeta meta;
  final int cols, rows;
  final List<int> walls; // per cell
  final int ghosts;
  final int ghostStep; // ticks per cell
  final int playerStep;
  final int frightTicks;
  final bool fruit;
  final double chase;

  const MazeLevel({
    required this.meta,
    required this.cols,
    required this.rows,
    required this.walls,
    required this.ghosts,
    required this.ghostStep,
    required this.playerStep,
    required this.frightTicks,
    required this.fruit,
    required this.chase,
  });

  int get start => (rows - 1) * cols + cols ~/ 2;
  int get home => (rows ~/ 2) * cols + cols ~/ 2;
  List<int> get powerCells => [cols + 1, 2 * cols - 2, (rows - 2) * cols + 1, (rows - 1) * cols - 2];
}

List<int> carveMaze(SeededRandom r, int cols, int rows) {
  final n = cols * rows;
  final walls = List<int>.filled(n, kN | kE | kS | kW);
  final seen = List<bool>.filled(n, false);
  final stack = [r.nextInt(n)];
  seen[stack.first] = true;
  while (stack.isNotEmpty) {
    final c = stack.last;
    final x = c % cols, y = c ~/ cols;
    final opts = <int>[];
    for (var d = 0; d < 4; d++) {
      final nx = x + _dx[d], ny = y + _dy[d];
      if (nx < 0 || ny < 0 || nx >= cols || ny >= rows || seen[ny * cols + nx]) continue;
      opts.add(d);
    }
    if (opts.isEmpty) {
      stack.removeLast();
      continue;
    }
    final d = opts[r.nextInt(opts.length)];
    final m = (y + _dy[d]) * cols + x + _dx[d];
    walls[c] &= ~_bit[d];
    walls[m] &= ~_bit[(d + 2) % 4];
    seen[m] = true;
    stack.add(m);
  }
  void open(int c, int d) {
    final x = c % cols, y = c ~/ cols;
    final nx = x + _dx[d], ny = y + _dy[d];
    if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) return;
    walls[c] &= ~_bit[d];
    walls[ny * cols + nx] &= ~_bit[(d + 2) % 4];
  }

  // Remove dead ends (arcade mazes have loops everywhere).
  for (var c = 0; c < n; c++) {
    var closed = 0;
    for (var d = 0; d < 4; d++) {
      if (walls[c] & _bit[d] != 0) closed++;
    }
    if (closed >= 3) {
      final opts = [for (var d = 0; d < 4; d++) if (walls[c] & _bit[d] != 0) d];
      r.shuffle(opts);
      for (final d in opts) {
        final x = c % cols + _dx[d], y = c ~/ cols + _dy[d];
        if (x < 0 || y < 0 || x >= cols || y >= rows) continue;
        open(c, d);
        break;
      }
    }
  }
  for (var k = 0; k < n ~/ 10; k++) {
    open(r.nextInt(n), r.nextInt(4));
  }
  return walls;
}

MazeLevel generateMazeLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final r = SeededRandom(mixSeed([spec.seed, 16]));
  final d = spec.difficulty;
  final cols = spec.has('big_maze') ? 13 : 11;
  final rows = (cols * 1.45).floor();
  final ghosts = (1 + d ~/ 3 + (spec.has('more_ghosts') ? 1 : 0)).clamp(1, 4);
  final gStep = (15 - d * 0.5 - (spec.has('fast_ghosts') ? 2 : 0)).round().clamp(10, 15);
  return MazeLevel(
    meta: m,
    cols: cols,
    rows: rows,
    walls: carveMaze(r, cols, rows),
    ghosts: ghosts,
    ghostStep: gStep,
    playerStep: 8,
    frightTicks: (420 - d * 20).clamp(200, 420),
    fruit: spec.has('fruit') || !m.goal,
    chase: (0.45 + d * 0.04).clamp(0.45, 0.85),
  );
}

class Mover {
  int cell;
  int dir = -1;
  int t = 0;
  Mover(this.cell);
}

class Ghost extends Mover {
  final int id;
  int release;
  int frightened = 0;
  bool eyes = false; // eaten, returning home
  Ghost(super.cell, this.id, this.release);
}

class MazeSim extends ArcadeSim {
  final MazeLevel level;
  late List<int> walls;
  late List<bool> dots;
  late Set<int> power;
  late Mover player;
  int want = -1;
  final List<Ghost> ghosts = [];
  int dotsLeft = 0, dotsTotal = 1;
  int eatenDots = 0, ghostsEaten = 0, fruits = 0, chain = 0;
  int fruitTtl = 0;
  int stage = 1;
  int lastEvent = 0; // 1 dot, 2 power, 3 ghost eaten, 4 fruit

  MazeSim(this.level) : super(level.meta) {
    walls = [...level.walls];
    _fill();
    _resetActors();
  }

  int get cols => level.cols;
  int get rows => level.rows;
  double get cell => kWorldW / cols;
  double get top => (kWorldH - rows * cell) / 2;

  void _fill() {
    dots = List<bool>.filled(cols * rows, true);
    dots[level.start] = false;
    dots[level.home] = false;
    power = level.powerCells.toSet();
    dotsLeft = dots.where((x) => x).length;
    dotsTotal = dotsLeft;
  }

  void _resetActors() {
    player = Mover(level.start);
    want = -1;
    ghosts.clear();
    for (var i = 0; i < level.ghosts; i++) {
      ghosts.add(Ghost(level.home, i, ticks + 60 + i * 150));
    }
  }

  bool open(int c, int d) => walls[c] & _bit[d] == 0;

  int step(int c, int d) => (c ~/ cols + _dy[d]) * cols + c % cols + _dx[d];

  /// World position of a mover.
  (double, double) pos(Mover m, int stepTicks) {
    var x = (m.cell % cols + 0.5) * cell, y = top + (m.cell ~/ cols + 0.5) * cell;
    if (m.dir >= 0 && m.t > 0) {
      final f = m.t / stepTicks;
      x += _dx[m.dir] * f * cell;
      y += _dy[m.dir] * f * cell;
    }
    return (x, y);
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (input.swipe >= 0) want = input.swipe;
    if (input.dirX != 0) want = input.dirX > 0 ? 1 : 3;
    if (input.dirY != 0) want = input.dirY > 0 ? 2 : 0;
    _movePlayer();
    for (final g in ghosts) {
      _moveGhost(g);
    }
    _collide();
    if (fruitTtl > 0) fruitTtl--;
    if (dotsLeft == 0) {
      if (meta.goal) {
        win();
      } else {
        stage++;
        score += 500;
        walls = carveMaze(SeededRandom(mixSeed([meta.seed, stage])), cols, rows);
        _fill();
        _resetActors();
      }
    }
  }

  void _movePlayer() {
    final p = player;
    if (p.t == 0) {
      if (want >= 0 && open(p.cell, want)) {
        p.dir = want;
      } else if (p.dir >= 0 && !open(p.cell, p.dir)) {
        p.dir = -1;
      }
      if (p.dir < 0) return;
    } else if (want == (p.dir + 2) % 4) {
      // Instant reverse in a corridor.
      p.cell = step(p.cell, p.dir);
      p.dir = want;
      p.t = level.playerStep - p.t;
    }
    p.t++;
    if (p.t >= level.playerStep) {
      p.t = 0;
      p.cell = step(p.cell, p.dir);
      _eat(p.cell);
    }
  }

  void _eat(int c) {
    if (dots[c]) {
      dots[c] = false;
      dotsLeft--;
      eatenDots++;
      final isPower = power.remove(c);
      if (isPower) {
        score += 50;
        chain = 0;
        lastEvent = 2;
        for (final g in ghosts) {
          if (!g.eyes) g.frightened = level.frightTicks;
        }
      } else {
        score += 10;
        lastEvent = 1;
      }
      final eaten = dotsTotal - dotsLeft;
      if (level.fruit && (eaten == dotsTotal * 3 ~/ 10 || eaten == dotsTotal * 7 ~/ 10)) fruitTtl = 540;
    }
    if (fruitTtl > 0 && c == level.home + cols * 2) {
      fruitTtl = 0;
      fruits++;
      score += 100 * meta.difficulty;
      lastEvent = 4;
    }
  }

  List<int> _distFrom(int src) {
    final dist = List<int>.filled(cols * rows, 1 << 20);
    dist[src] = 0;
    final q = [src];
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      for (var d = 0; d < 4; d++) {
        if (!open(c, d)) continue;
        final m = step(c, d);
        if (dist[m] <= dist[c] + 1) continue;
        dist[m] = dist[c] + 1;
        q.add(m);
      }
    }
    return dist;
  }

  void _moveGhost(Ghost g) {
    if (ticks < g.release) return;
    if (g.frightened > 0) g.frightened--;
    final stepT = g.eyes ? 4 : (g.frightened > 0 ? level.ghostStep + 4 : level.ghostStep);
    if (g.t == 0) {
      final opts = [for (var d = 0; d < 4; d++) if (open(g.cell, d)) d];
      var choices = opts.where((d) => g.dir < 0 || d != (g.dir + 2) % 4).toList();
      if (choices.isEmpty) choices = opts;
      int pick;
      if (g.eyes) {
        final dist = _distFrom(level.home);
        choices.sort((a, b) => dist[step(g.cell, a)].compareTo(dist[step(g.cell, b)]));
        pick = choices.first;
      } else {
        final dist = _distFrom(player.cell);
        if (g.frightened > 0) {
          choices.sort((a, b) => dist[step(g.cell, b)].compareTo(dist[step(g.cell, a)]));
          pick = rng.chance(0.7) ? choices.first : choices[rng.nextInt(choices.length)];
        } else if (rng.chance(level.chase)) {
          choices.sort((a, b) => dist[step(g.cell, a)].compareTo(dist[step(g.cell, b)]));
          pick = choices.first;
        } else {
          pick = choices[rng.nextInt(choices.length)];
        }
      }
      g.dir = pick;
    }
    g.t++;
    if (g.t >= stepT) {
      g.t = 0;
      g.cell = step(g.cell, g.dir);
      if (g.eyes && g.cell == level.home) {
        g.eyes = false;
        g.frightened = 0;
        g.release = ticks + 90;
      }
    }
  }

  void _collide() {
    final (px, py) = pos(player, level.playerStep);
    for (final g in ghosts) {
      if (g.eyes || ticks < g.release) continue;
      final (gx, gy) = pos(g, g.frightened > 0 ? level.ghostStep + 4 : level.ghostStep);
      final dx = gx - px, dy = gy - py;
      if (dx * dx + dy * dy > cell * cell * 0.36) continue;
      if (g.frightened > 0) {
        g.eyes = true;
        g.frightened = 0;
        g.t = 0;
        chain++;
        ghostsEaten++;
        score += 200 * (1 << (chain - 1).clamp(0, 3));
        lastEvent = 3;
      } else {
        hit();
        return;
      }
    }
  }

  @override
  void onLifeLost() => _resetActors();

  @override
  bool useBooster() {
    // Power booster: frighten every ghost.
    if (over) return false;
    for (final g in ghosts) {
      if (!g.eyes) g.frightened = level.frightTicks;
    }
    chain = 0;
    return true;
  }

  @override
  double get progress => 1 - dotsLeft / math.max(1, dotsTotal);

  @override
  String get goalText => meta.goal ? '$dotsLeft' : 'x$stage';

  @override
  Map<String, int> get stats => {'dots_eaten': eatenDots, 'ghosts_eaten': ghostsEaten, 'fruits': fruits};

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: shortest safe path to the nearest dot, fleeing when ghosts
/// are close; hunts frightened ghosts that are near.
ArcadeInput mazeBot(ArcadeSim sim) {
  final s = sim as MazeSim;
  final p = s.player;
  // Plan from the cell the player is entering.
  final from = p.t == 0 || p.dir < 0 ? p.cell : s.step(p.cell, p.dir);
  final n = s.cols * s.rows;
  final danger = List<int>.filled(n, 0);
  final active = s.ghosts.where((g) => !g.eyes && s.ticks >= g.release - 30 && g.frightened < 60).toList();
  for (final g in active) {
    final reach = 4;
    final dist = List<int>.filled(n, 99);
    final gc = g.t == 0 || g.dir < 0 ? g.cell : s.step(g.cell, g.dir);
    dist[g.cell] = 0;
    dist[gc] = 0;
    final q = [g.cell, gc];
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      if (dist[c] >= reach) continue;
      for (var d = 0; d < 4; d++) {
        if (!s.open(c, d)) continue;
        final m = s.step(c, d);
        if (dist[m] <= dist[c] + 1) continue;
        dist[m] = dist[c] + 1;
        q.add(m);
      }
    }
    for (var c = 0; c < n; c++) {
      if (dist[c] <= reach) danger[c] = math.max(danger[c], reach + 1 - dist[c]);
    }
  }
  final hunt = s.ghosts.where((g) => g.frightened > 90 && !g.eyes).map((g) => g.cell).toSet();
  int? goTo(bool Function(int) goal, int maxDanger) {
    final first = List<int>.filled(n, -1);
    final seen = List<bool>.filled(n, false);
    seen[from] = true;
    final q = <int>[];
    for (var d = 0; d < 4; d++) {
      if (!s.open(from, d)) continue;
      final m = s.step(from, d);
      if (danger[m] > maxDanger || seen[m]) continue;
      seen[m] = true;
      first[m] = d;
      q.add(m);
    }
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      if (goal(c)) return first[c];
      for (var d = 0; d < 4; d++) {
        if (!s.open(c, d)) continue;
        final m = s.step(c, d);
        if (seen[m] || danger[m] > maxDanger) continue;
        seen[m] = true;
        first[m] = first[c];
        q.add(m);
      }
    }
    return null;
  }

  int? dir;
  if (hunt.isNotEmpty) dir = goTo((c) => hunt.contains(c), 0);
  dir ??= danger[from] > 0 && s.power.isNotEmpty ? goTo((c) => s.power.contains(c) && s.dots[c], 1) : null;
  dir ??= goTo((c) => s.dots[c], 0);
  if (dir == null) {
    // Flee: neighbor with the lowest danger, then farthest from ghosts.
    var best = 99;
    for (var d = 0; d < 4; d++) {
      if (!s.open(from, d)) continue;
      final m = s.step(from, d);
      if (danger[m] < best) {
        best = danger[m];
        dir = d;
      }
    }
  }
  if (dir == null) return ArcadeInput.idle;
  return ArcadeInput(swipe: dir);
}
