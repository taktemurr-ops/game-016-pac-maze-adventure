import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'maze_engine.dart';

class MazeRules extends ArcadeRules<MazeLevel> {
  @override
  String get gameId => 'game-016-pac-maze-adventure';

  @override
  List<String> get optionalMechanics => const ['fruit', 'fast_ghosts', 'more_ghosts', 'big_maze'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('dots_eaten', 'Yenen nokta', 'Dots eaten', scale: 500),
        GameStat('ghosts_eaten', 'Yenen hayalet', 'Ghosts eaten', scale: 10),
        GameStat('fruits', 'Meyve', 'Fruits', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('dots_eaten', 'dots_eaten', [166, 333, 500]),
        MissionTemplate('ghosts_eaten', 'ghosts_eaten', [3, 6, 10]),
      ];

  @override
  MazeLevel generate(LevelSpec spec) => generateMazeLevel(spec);

  @override
  ArcadeMeta metaOf(MazeLevel l) => l.meta;

  @override
  ArcadeSim createSim(MazeLevel l) => MazeSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => mazeBot(sim);
}

ArcadeRules createRules() => MazeRules();
