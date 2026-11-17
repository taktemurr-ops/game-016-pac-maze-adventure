import 'package:flutter_test/flutter_test.dart';
import 'package:game_016_pac_maze_adventure/game/maze_game.dart';

void main() {
  test('starts with pellets, score zero and first pellet consumed', () {
    final game = MazeGame();
    expect(game.score, 0);
    expect(game.pellets.contains(game.player), false);
    expect(game.pellets, isNotEmpty);
  });
  test('walls and invalid directions do not move player', () {
    final game = MazeGame();
    expect(game.walk(-1, 0), false);
    expect(game.walk(2, 0), false);
    expect(game.moves, 0);
  });
  test('walking collects pellets only once', () {
    final game = MazeGame();
    expect(game.walk(1, 0), true);
    expect(game.score, 10);
    expect(game.walk(-1, 0), true);
    expect(game.score, 10);
    expect(game.moves, 2);
  });
  test('reset restores the initial state', () {
    final game = MazeGame();
    final initial = game.pellets.length;
    game.walk(1, 0);
    game.reset();
    expect(game.score, 0);
    expect(game.moves, 0);
    expect(game.pellets.length, initial);
  });
}
