import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:studio_core/app/arcade_stage.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/game_rules.dart';
import 'maze_engine.dart';
import 'rules.dart';

void paintMaze(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as MazeSim;
  final cs = s.cell, top = s.top;
  final wall = Paint()
    ..color = p.piece(2)
    ..strokeWidth = 8
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < s.cols * s.rows; i++) {
    final x = (i % s.cols) * cs, y = top + (i ~/ s.cols) * cs;
    final w = s.walls[i];
    if (w & kN != 0) c.drawLine(Offset(x, y), Offset(x + cs, y), wall);
    if (w & kW != 0) c.drawLine(Offset(x, y), Offset(x, y + cs), wall);
    if (i % s.cols == s.cols - 1 && w & kE != 0) c.drawLine(Offset(x + cs, y), Offset(x + cs, y + cs), wall);
    if (i ~/ s.cols == s.rows - 1 && w & kS != 0) c.drawLine(Offset(x, y + cs), Offset(x + cs, y + cs), wall);
    final center = Offset(x + cs / 2, y + cs / 2);
    if (s.dots[i]) {
      final big = s.power.contains(i);
      c.drawCircle(center, big ? cs * 0.2 * (1 + 0.15 * math.sin(t * 8)) : cs * 0.07,
          Paint()..color = big ? const Color(0xFFFFD60A) : Colors.white70);
    }
  }
  if (s.fruitTtl > 0) {
    final i = s.level.home + s.cols * 2;
    paintText(c, '🍒', Offset((i % s.cols + 0.5) * cs, top + (i ~/ s.cols + 0.5) * cs), cs * 0.6, Colors.white);
  }
  const ghostCols = [Color(0xFFFF4D6D), Color(0xFFFF9EBB), Color(0xFF4CC9F0), Color(0xFFFFB703)];
  for (final g in s.ghosts) {
    final (x, y) = s.pos(g, g.frightened > 0 ? s.level.ghostStep + 4 : s.level.ghostStep);
    final o = Offset(x, y);
    if (!g.eyes) {
      final scared = g.frightened > 0;
      final col = scared ? (g.frightened < 90 && (s.ticks ~/ 8).isOdd ? Colors.white : const Color(0xFF3A0CA3)) : ghostCols[g.id % 4];
      final r = cs * 0.38;
      final body = Path()
        ..addArc(Rect.fromCircle(center: o, radius: r), math.pi, math.pi)
        ..lineTo(o.dx + r, o.dy + r)
        ..lineTo(o.dx + r / 2, o.dy + r * 0.7)
        ..lineTo(o.dx, o.dy + r)
        ..lineTo(o.dx - r / 2, o.dy + r * 0.7)
        ..lineTo(o.dx - r, o.dy + r)
        ..close();
      c.drawPath(body, Paint()..color = ticksReady(s, g) ? col : col.withValues(alpha: 0.4));
    }
    for (final side in [-1.0, 1.0]) {
      c.drawCircle(o.translate(side * cs * 0.13, -cs * 0.05), cs * 0.09, Paint()..color = Colors.white);
      c.drawCircle(o.translate(side * cs * 0.13, -cs * 0.03), cs * 0.045, Paint()..color = Colors.indigo);
    }
  }
  final (px, py) = s.pos(s.player, s.level.playerStep);
  final mouth = (0.15 + 0.25 * (math.sin(t * 18) + 1) / 2) * math.pi;
  const angle = [-math.pi / 2, 0.0, math.pi / 2, math.pi];
  final a = s.player.dir < 0 ? 0.0 : angle[s.player.dir];
  final blink = s.shield > 0 && (s.ticks ~/ 6).isOdd;
  c.drawArc(Rect.fromCircle(center: Offset(px, py), radius: cs * 0.4), a + mouth, 2 * math.pi - 2 * mouth, true,
      Paint()..color = blink ? Colors.white38 : const Color(0xFFFFD60A));
}

bool ticksReady(MazeSim s, Ghost g) => s.ticks >= g.release;

Sfx? mazeSound(ArcadeSim sim) => switch ((sim as MazeSim).lastEvent) {
      1 => sim.ticks % 3 == 0 ? Sfx.tap : null,
      2 => Sfx.unlock,
      3 => Sfx.combo,
      4 => Sfx.coin,
      _ => null,
    };

final gameConfig = GameConfig(
  gameId: 'game-016-pac-maze-adventure',
  title: const ['Labirent Macerası', 'Pac Maze Adventure', 'Labyrinth-Abenteuer', 'Aventura Laberinto', 'Aventure Labyrinthe'],
  tagline: const ['Bütün noktaları ye, hayaletlerden kaç!', 'Eat every dot, dodge the ghosts!', 'Friss alle Punkte, meide die Geister!', '¡Cómete los puntos, esquiva fantasmas!', 'Mangez tout, évitez les fantômes !'],
  seedColor: const Color(0xFFFFD60A),
  icon: Icons.blur_circular,
  rules: MazeRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => MazeSim((ctx.generated as GeneratedLevel<MazeLevel>).puzzle),
    paint: paintMaze,
    sound: mazeSound,
    boosterIcon: Icons.flash_on,
    boosterLabel: (l) => l == 'tr' ? 'Güç yemi' : 'Power pellet',
    howTo: const [
      'Yön vermek için kaydır. Dönüşleri önceden ver, köşede uygulanır.',
      'Swipe to turn. Turns are buffered until the next corner.',
      'Wischen zum Abbiegen. Kurven werden vorgemerkt.',
      'Desliza para girar. Los giros se guardan.',
      'Glissez pour tourner. Les virages sont mémorisés.',
    ],
  ),
  tutorial: const [
    TutorialStep(Icons.swipe, [
      'Kaydır ya da ok tuşlarını kullan. Erken verilen dönüş köşede uygulanır.',
      'Swipe or use arrows. Early turns happen at the next corner.',
      'Wischen oder Pfeiltasten.',
      'Desliza o usa flechas.',
      'Glissez ou flèches.',
    ]),
    TutorialStep(Icons.circle, [
      'Büyük sarı yem hayaletleri korkutur: şimdi onları yiyebilirsin!',
      'Big yellow pellets scare ghosts: now you can eat them!',
      'Große Pillen erschrecken Geister.',
      'Las píldoras grandes asustan a los fantasmas.',
      'Les grosses pastilles effraient les fantômes.',
    ]),
    TutorialStep(Icons.emoji_food_beverage, [
      'Bonus meyveleri kaçırma. Bütün noktaları yiyince bölüm biter.',
      'Grab bonus fruit. Eat every dot to finish.',
      'Schnapp dir Obst. Friss alle Punkte.',
      'Atrapa la fruta. Come todos los puntos.',
      'Prenez les fruits. Mangez tous les points.',
    ]),
  ],
);
