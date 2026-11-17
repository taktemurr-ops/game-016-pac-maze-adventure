import 'dart:math';

class MazeGame {
  static const layout = <String>[
    '#########',
    '#.......#',
    '#.##.##.#',
    '#...#...#',
    '###.#.###',
    '#.......#',
    '#.##.##.#',
    '#.......#',
    '#########',
  ];
  late Set<Point<int>> pellets;
  Point<int> player = const Point(1, 1);
  int score = 0;
  int moves = 0;
  bool get won => pellets.isEmpty;
  MazeGame() { reset(); }
  void reset() {
    pellets = {};
    for (var y = 0; y < layout.length; y++) {
      for (var x = 0; x < layout[y].length; x++) {
        if (layout[y][x] == '.') pellets.add(Point(x, y));
      }
    }
    player = const Point(1, 1);
    pellets.remove(player);
    score = 0;
    moves = 0;
  }
  bool walk(int dx, int dy) {
    if (won || dx.abs() + dy.abs() != 1) return false;
    final next = Point(player.x + dx, player.y + dy);
    if (next.y < 0 || next.y >= layout.length ||
        next.x < 0 || next.x >= layout[next.y].length ||
        layout[next.y][next.x] == '#') return false;
    player = next;
    moves++;
    if (pellets.remove(next)) score += 10;
    return true;
  }
}
