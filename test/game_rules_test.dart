import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'package:game_016_pac_maze_adventure/game/maze_engine.dart';
import 'package:game_016_pac_maze_adventure/game/rules.dart';

void main() {
  final rules = MazeRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('maze is fully connected and has no dead ends', () {
    final w = carveMaze(SeededRandom(7), 11, 15);
    final seen = {0};
    final q = [0];
    const dx = [0, 1, 0, -1], dy = [-1, 0, 1, 0], bit = [1, 2, 4, 8];
    for (var i = 0; i < q.length; i++) {
      final c = q[i];
      var exits = 0;
      for (var d = 0; d < 4; d++) {
        if (w[c] & bit[d] != 0) continue;
        exits++;
        final m = (c ~/ 11 + dy[d]) * 11 + c % 11 + dx[d];
        if (seen.add(m)) q.add(m);
      }
      expect(exits, greaterThanOrEqualTo(2), reason: 'dead end at $c');
    }
    expect(seen.length, 11 * 15);
  });

  test('eating a power pellet frightens the ghosts', () {
    final s = MazeSim(rules.build(planner.spec(30)).puzzle);
    final pc = s.level.powerCells.first;
    s.player.cell = pc;
    s.player.t = 0;
    s.dots[pc] = true;
    // move into the cell from a neighbour
    for (var d = 0; d < 4; d++) {
      if (s.open(pc, d)) {
        s.player.cell = s.step(pc, d);
        s.player.dir = (d + 2) % 4;
        s.player.t = s.level.playerStep - 1;
        break;
      }
    }
    s.tick(ArcadeInput.idle);
    expect(s.ghosts.every((g) => g.frightened > 0), isTrue);
  });
}
