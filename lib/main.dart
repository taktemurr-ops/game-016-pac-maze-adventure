import 'package:flutter/material.dart';
import 'game/maze_game.dart';

void main() => runApp(const MaterialApp(debugShowCheckedModeBanner: false, home: MazeScreen()));

class MazeScreen extends StatefulWidget {
  const MazeScreen({super.key});
  @override
  State<MazeScreen> createState() => _MazeScreenState();
}

class _MazeScreenState extends State<MazeScreen> {
  final game = MazeGame();
  void move(int dx, int dy) => setState(() { game.walk(dx, dy); });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pac Maze Adventure'), actions: [
      IconButton(tooltip: 'Restart', onPressed: () => setState(game.reset), icon: const Icon(Icons.refresh))
    ]),
    body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Score: ${game.score}   Moves: ${game.moves}   Left: ${game.pellets.length}',
        style: Theme.of(context).textTheme.titleMedium),
      if (game.won) const Text('Maze cleared! Well done!', style: TextStyle(fontSize: 20)),
      const SizedBox(height: 16),
      AspectRatio(aspectRatio: 1, child: Padding(padding: const EdgeInsets.all(12),
        child: GridView.builder(physics: const NeverScrollableScrollPhysics(),
          itemCount: MazeGame.layout.length * MazeGame.layout[0].length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 9),
          itemBuilder: (context, index) {
            final x = index % 9, y = index ~/ 9;
            final wall = MazeGame.layout[y][x] == '#';
            final isPlayer = game.player.x == x && game.player.y == y;
            final pellet = game.pellets.any((p) => p.x == x && p.y == y);
            return Container(margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(color: wall ? Colors.indigo.shade900 : Colors.black87,
                borderRadius: BorderRadius.circular(3)),
              child: Center(child: isPlayer ? const Icon(Icons.circle, color: Colors.yellow, size: 23)
                : pellet ? const Icon(Icons.circle, color: Colors.white, size: 6) : null));
          }))),
      const SizedBox(height: 12),
      IconButton(iconSize: 48, tooltip: 'Up', onPressed: () => move(0, -1), icon: const Icon(Icons.keyboard_arrow_up)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(iconSize: 48, tooltip: 'Left', onPressed: () => move(-1, 0), icon: const Icon(Icons.keyboard_arrow_left)),
        const SizedBox(width: 50),
        IconButton(iconSize: 48, tooltip: 'Right', onPressed: () => move(1, 0), icon: const Icon(Icons.keyboard_arrow_right)),
      ]),
      IconButton(iconSize: 48, tooltip: 'Down', onPressed: () => move(0, 1), icon: const Icon(Icons.keyboard_arrow_down)),
    ])),
  );
}
