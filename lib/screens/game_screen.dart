import 'dart:math' as math;
import 'package:flutter/material.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  static const double paddleWidth = 100;
  static const double paddleHeight = 14;
  static const double ballRadius = 10;
  static const double brickWidth = 50;
  static const double brickHeight = 22;
  static const int brickRows = 5;
  static const int brickCols = 8;
  // Match UI layout: bricks start at top 50, left padding 4, row spacing (brickHeight+4)
  static const double _brickTopOffset = 50;
  static const double _brickLeftPadding = 4;
  static const double _brickRowSpacing = brickHeight + 4;
  static const double _brickDrawWidth = brickWidth - 4;
  static const double _brickDrawHeight = brickHeight - 2;
  static const int maxLives = 3;

  late AnimationController _controller;
  double _paddleX = 0.5;
  double _ballX = 0.5;
  double _ballY = 0.85;
  double _ballDx = 0.015;
  double _ballDy = -0.02;
  int _score = 0;
  int _lives = maxLives;
  int _level = 1;
  bool _started = false;
  bool _gameOver = false;
  bool _levelComplete = false;
  List<List<bool>> _bricks = [];
  double _gameWidth = 400;
  double _gameHeight = 600;

  @override
  void initState() {
    super.initState();
    _initBricks();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 16));
    _controller.addListener(_update);
  }

  void _initBricks() {
    _bricks = List.generate(brickRows, (_) => List.filled(brickCols, true));
  }

  void _update() {
    if (!_started || _gameOver || _levelComplete) return;
    if (!mounted) return;

    setState(() {
      _ballX += _ballDx;
      _ballY += _ballDy;

      // Walls
      if (_ballX <= ballRadius / _gameWidth) {
        _ballX = ballRadius / _gameWidth;
        _ballDx = -_ballDx;
      }
      if (_ballX >= 1 - ballRadius / _gameWidth) {
        _ballX = 1 - ballRadius / _gameWidth;
        _ballDx = -_ballDx;
      }
      if (_ballY <= ballRadius / _gameHeight) {
        _ballY = ballRadius / _gameHeight;
        _ballDy = -_ballDy;
      }

      // Paddle (bottom: 24 in UI - match here so bounce is on paddle, not empty space below)
      final paddleLeft = _paddleX - (paddleWidth / 2) / _gameWidth;
      final paddleRight = _paddleX + (paddleWidth / 2) / _gameWidth;
      const double paddleBottomGap = 24;
      final paddleTop = 1 - (paddleHeight + paddleBottomGap) / _gameHeight;
      final paddleBottom = paddleTop + paddleHeight / _gameHeight;
      if (_ballDy > 0 &&
          _ballY >= paddleTop - ballRadius / _gameHeight &&
          _ballY <= paddleBottom &&
          _ballX >= paddleLeft - ballRadius / _gameWidth &&
          _ballX <= paddleRight + ballRadius / _gameWidth) {
        _ballDy = -_ballDy;
        final hitPos = (_ballX - paddleLeft) / (paddleRight - paddleLeft);
        _ballDx = 0.02 * (hitPos - 0.5);
      }

      // Bottom - lose life
      if (_ballY > 1) {
        _lives--;
        if (_lives <= 0) {
          _gameOver = true;
          _controller.stop();
          return;
        }
        _ballX = 0.5;
        _ballY = 0.85;
        _ballDx = 0.015;
        _ballDy = -0.02;
        _started = false;
        return;
      }

      // Bricks - use same layout as UI (top offset, left padding, draw size)
      final cellW = _gameWidth / brickCols;
      for (var r = 0; r < brickRows; r++) {
        for (var c = 0; c < brickCols; c++) {
          if (!_bricks[r][c]) continue;
          final centerX = _brickLeftPadding + c * cellW + _brickDrawWidth / 2;
          final centerY = _brickTopOffset + r * _brickRowSpacing + _brickDrawHeight / 2;
          final bx = centerX / _gameWidth;
          final by = centerY / _gameHeight;
          final dx = (_ballX - bx).abs();
          final dy = (_ballY - by).abs();
          final halfW = _brickDrawWidth / 2 / _gameWidth + ballRadius / _gameWidth;
          final halfH = _brickDrawHeight / 2 / _gameHeight + ballRadius / _gameHeight;
          if (dx < halfW && dy < halfH) {
            _bricks[r][c] = false;
            _ballDy = -_ballDy;
            _score += 10;
          }
        }
      }

      final allGone = _bricks.every((row) => row.every((b) => !b));
      if (allGone) {
        _levelComplete = true;
        _controller.stop();
      }
    });
  }

  void _startGame() {
    if (_levelComplete) {
      _level++;
      _initBricks();
      _ballX = 0.5;
      _ballY = 0.85;
      _ballDx = 0.015;
      _ballDy = -0.02;
      _levelComplete = false;
    }
    _started = true;
    _controller.repeat();
  }

  void _restart() {
    _score = 0;
    _lives = maxLives;
    _level = 1;
    _initBricks();
    _ballX = 0.5;
    _ballY = 0.85;
    _ballDx = 0.015;
    _ballDy = -0.02;
    _started = false;
    _gameOver = false;
    _levelComplete = false;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _gameWidth = constraints.maxWidth;
              _gameHeight = constraints.maxHeight;
              return GestureDetector(
                onHorizontalDragUpdate: (d) {
                  final localX = d.globalPosition.dx - (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dx;
                  setState(() {
                    _paddleX = (localX / _gameWidth).clamp(
                      (paddleWidth / 2) / _gameWidth,
                      1 - (paddleWidth / 2) / _gameWidth,
                    );
                  });
                },
                child: Stack(
                  children: [
                  // Non-positioned child so Stack takes full size (avoids brown screen when overlay is removed)
                  SizedBox.expand(),
                  // HUD
                  Positioned(
                    top: 8,
                    left: 16,
                    child: Text(
                      'Score: $_score  |  Lives: $_lives  |  Level $_level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Bricks
                  ..._bricks.asMap().entries.expand((rowEntry) {
                    final r = rowEntry.key;
                    return rowEntry.value.asMap().entries.map((colEntry) {
                      final c = colEntry.key;
                      if (!colEntry.value) return const SizedBox.shrink();
                      final cellW = _gameWidth / brickCols;
                      final top = _brickTopOffset + r * _brickRowSpacing;
                      final left = _brickLeftPadding + c * cellW;
                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: _brickDrawWidth,
                          height: _brickDrawHeight,
                          decoration: BoxDecoration(
                            color: [
                              Colors.deepOrange,
                              Colors.orange,
                              Colors.amber,
                              Colors.yellow.shade700,
                              Colors.orange.shade300,
                            ][r % 5],
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: const Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    });
                  }),
                  // Paddle
                  Positioned(
                    left: (_paddleX * _gameWidth - paddleWidth / 2).clamp(0.0, _gameWidth - paddleWidth),
                    bottom: 24,
                    child: Container(
                      width: paddleWidth,
                      height: paddleHeight,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE65100),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Ball
                  Positioned(
                    left: _ballX * _gameWidth - ballRadius,
                    top: _ballY * _gameHeight - ballRadius,
                    child: Container(
                      width: ballRadius * 2,
                      height: ballRadius * 2,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                  // Tap to start overlay
                  if (!_started && !_gameOver && !_levelComplete)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _startGame,
                        child: Container(
                          color: Colors.black26,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Moving Brick',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _level == 1 ? 'Tap to start' : 'Tap for next level',
                                  style: const TextStyle(color: Colors.white70, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Game over
                  if (_gameOver)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Game Over',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Score: $_score',
                                style: const TextStyle(color: Colors.white70, fontSize: 20),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _restart();
                                },
                                icon: const Icon(Icons.refresh),
                                label: const Text('Play again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Level complete
                  if (_levelComplete)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _startGame,
                        child: Container(
                          color: Colors.black38,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Level $_level complete!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap for next level',
                                  style: TextStyle(color: Colors.white70, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
