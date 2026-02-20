import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game_sounds.dart';

class _ExtraBall {
  double x, y, dx, dy;
  _ExtraBall(this.x, this.y, this.dx, this.dy);
}

class _Projectile {
  double x, y;
  _Projectile(this.x, this.y);
}

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
  // Brick types: 0 = empty, 1 = normal, 2 = magic
  static const int _brickNormal = 1;
  static const int _brickMagic = 2;
  static const Duration _powerUpDuration = Duration(seconds: 12);
  static const double _projectileSpeed = 0.025;
  static const double _projectileWidth = 6;
  static const double _projectileHeight = 16;
  static const int _extraBallsCount = 3;
  static const int _fireIntervalFrames = 20;

  late AnimationController _controller;
  double _paddleX = 0.5;
  double _ballX = 0.5;
  double _ballY = 0.85;
  double _ballDx = 0.006;
  double _ballDy = -0.008;
  int _score = 0;
  int _lives = maxLives;
  int _level = 1;
  bool _started = false;
  bool _gameOver = false;
  bool _levelComplete = false;
  List<List<int>> _bricks = [];
  double _gameWidth = 400;
  double _gameHeight = 600;
  // Power-up: multi-ball + firing
  DateTime? _powerUpEndTime;
  final List<_ExtraBall> _extraBalls = [];
  final List<_Projectile> _projectiles = [];
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initBricks();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 16));
    _controller.addListener(_update);
  }

  void _initBricks() {
    _bricks = List.generate(brickRows, (_) => List.filled(brickCols, _brickNormal));
    // Place one magic brick near center (row 2, col 3 or 4)
    final magicR = 2;
    final magicC = brickCols ~/ 2;
    if (magicR < brickRows && magicC < brickCols) {
      _bricks[magicR][magicC] = _brickMagic;
    }
  }

  bool get _hasPowerUp => _powerUpEndTime != null && DateTime.now().isBefore(_powerUpEndTime!);

  void _activatePowerUp() {
    _powerUpEndTime = DateTime.now().add(_powerUpDuration);
    // Spawn extra balls from main ball position with spread angles
    for (var i = 0; i < _extraBallsCount; i++) {
      final angle = -0.5 * math.pi + (i - _extraBallsCount / 2) * 0.35;
      _extraBalls.add(_ExtraBall(_ballX, _ballY, 0.008 * math.cos(angle), 0.008 * math.sin(angle)));
    }
  }

  void _checkBrickHit(double bx, double by, double halfW, double halfH, void Function(int r, int c) onHit) {
    final cellW = _gameWidth / brickCols;
    for (var r = 0; r < brickRows; r++) {
      for (var c = 0; c < brickCols; c++) {
        if (_bricks[r][c] == 0) continue;
        final centerX = _brickLeftPadding + c * cellW + _brickDrawWidth / 2;
        final centerY = _brickTopOffset + r * _brickRowSpacing + _brickDrawHeight / 2;
        final brickNx = centerX / _gameWidth;
        final brickNy = centerY / _gameHeight;
        final dx = (bx - brickNx).abs();
        final dy = (by - brickNy).abs();
        if (dx < halfW && dy < halfH) {
          onHit(r, c);
          return; // one hit per call
        }
      }
    }
  }

  void _update() {
    if (!_started || _gameOver || _levelComplete) return;
    if (!mounted) return;

    _frameCount++;

    setState(() {
      // Expire power-up
      if (_powerUpEndTime != null && DateTime.now().isAfter(_powerUpEndTime!)) {
        _powerUpEndTime = null;
        _extraBalls.clear();
        _projectiles.clear();
      }

      const double paddleBottomGap = 24;
      final paddleTop = 1 - (paddleHeight + paddleBottomGap) / _gameHeight;
      final paddleBottom = paddleTop + paddleHeight / _gameHeight;
      final paddleLeft = _paddleX - (paddleWidth / 2) / _gameWidth;
      final paddleRight = _paddleX + (paddleWidth / 2) / _gameWidth;
      final halfW = _brickDrawWidth / 2 / _gameWidth + ballRadius / _gameWidth;
      final halfH = _brickDrawHeight / 2 / _gameHeight + ballRadius / _gameHeight;

      // Auto-fire during power-up
      if (_hasPowerUp && _frameCount % _fireIntervalFrames == 0) {
        _projectiles.add(_Projectile(_paddleX, 1 - (paddleHeight + paddleBottomGap + 10) / _gameHeight));
      }

      // Update projectiles (move up, hit bricks)
      for (var i = _projectiles.length - 1; i >= 0; i--) {
        final p = _projectiles[i];
        p.y -= _projectileSpeed;
        if (p.y < 0) {
          _projectiles.removeAt(i);
          continue;
        }
        var hit = false;
        final projHalfW = (_projectileWidth / 2 + _brickDrawWidth / 2) / _gameWidth;
        final projHalfH = (_projectileHeight / 2 + _brickDrawHeight / 2) / _gameHeight;
        _checkBrickHit(p.x, p.y, projHalfW, projHalfH, (r, c) {
          if (_bricks[r][c] == _brickMagic) _activatePowerUp();
          _bricks[r][c] = 0;
          _score += 10;
          GameSounds.brickHit();
          hit = true;
        });
        if (hit) _projectiles.removeAt(i);
      }

      // Main ball
      _ballX += _ballDx;
      _ballY += _ballDy;
      _bounceBall(_ballX, _ballY, _ballDx, _ballDy, (nx, ny, ndx, ndy) {
        _ballX = nx;
        _ballY = ny;
        _ballDx = ndx;
        _ballDy = ndy;
      }, paddleLeft, paddleRight, paddleTop, paddleBottom);
      _checkBrickHit(_ballX, _ballY, halfW, halfH, (r, c) {
        if (_bricks[r][c] == _brickMagic) _activatePowerUp();
        _bricks[r][c] = 0;
        _ballDy = -_ballDy;
        _score += 10;
        GameSounds.brickHit();
      });

      // Bottom - lose life (main ball only)
      if (_ballY > 1) {
        _lives--;
        if (_lives <= 0) {
          _gameOver = true;
          _controller.stop();
          GameSounds.gameOver();
          return;
        }
        _ballX = 0.5;
        _ballY = 0.85;
        _ballDx = 0.006;
        _ballDy = -0.008;
        _started = false;
        return;
      }

      // Extra balls
      for (var i = _extraBalls.length - 1; i >= 0; i--) {
        final b = _extraBalls[i];
        b.x += b.dx;
        b.y += b.dy;
        if (b.y > 1) {
          _extraBalls.removeAt(i);
          continue;
        }
        _bounceBall(b.x, b.y, b.dx, b.dy, (nx, ny, ndx, ndy) {
          b.x = nx;
          b.y = ny;
          b.dx = ndx;
          b.dy = ndy;
        }, paddleLeft, paddleRight, paddleTop, paddleBottom);
        _checkBrickHit(b.x, b.y, halfW, halfH, (r, c) {
          if (_bricks[r][c] == _brickMagic) _activatePowerUp();
          _bricks[r][c] = 0;
          b.dy = -b.dy;
          _score += 10;
          GameSounds.brickHit();
        });
      }

      final allGone = _bricks.every((row) => row.every((b) => b == 0));
      if (allGone) {
        _levelComplete = true;
        _controller.stop();
        GameSounds.levelComplete();
      }
    });
  }

  void _bounceBall(double x, double y, double dx, double dy, void Function(double nx, double ny, double ndx, double ndy) set,
      double paddleLeft, double paddleRight, double paddleTop, double paddleBottom) {
    double nx = x, ny = y, ndx = dx, ndy = dy;
    if (nx <= ballRadius / _gameWidth) {
      nx = ballRadius / _gameWidth;
      ndx = -ndx;
    }
    if (nx >= 1 - ballRadius / _gameWidth) {
      nx = 1 - ballRadius / _gameWidth;
      ndx = -ndx;
    }
    if (ny <= ballRadius / _gameHeight) {
      ny = ballRadius / _gameHeight;
      ndy = -ndy;
    }
    if (ndy > 0 &&
        ny >= paddleTop - ballRadius / _gameHeight &&
        ny <= paddleBottom &&
        nx >= paddleLeft - ballRadius / _gameWidth &&
        nx <= paddleRight + ballRadius / _gameWidth) {
      ndy = -ndy;
      final hitPos = (nx - paddleLeft) / (paddleRight - paddleLeft);
      ndx = 0.008 * (hitPos - 0.5);
      GameSounds.paddleHit();
    }
    set(nx, ny, ndx, ndy);
  }

  void _startGame() {
    if (_levelComplete) {
      _level++;
      _initBricks();
      _ballX = 0.5;
      _ballY = 0.85;
      _ballDx = 0.006;
      _ballDy = -0.008;
      _levelComplete = false;
      _powerUpEndTime = null;
      _extraBalls.clear();
      _projectiles.clear();
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
    _ballDx = 0.006;
    _ballDy = -0.008;
    _started = false;
    _gameOver = false;
    _levelComplete = false;
    _powerUpEndTime = null;
    _extraBalls.clear();
    _projectiles.clear();
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
                  // Move paddle from anywhere: finger position controls paddle
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
                      final type = colEntry.value;
                      if (type == 0) return const SizedBox.shrink();
                      final cellW = _gameWidth / brickCols;
                      final top = _brickTopOffset + r * _brickRowSpacing;
                      final left = _brickLeftPadding + c * cellW;
                      final isMagic = type == _brickMagic;
                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: _brickDrawWidth,
                          height: _brickDrawHeight,
                          decoration: BoxDecoration(
                            gradient: isMagic
                                ? const LinearGradient(
                                    colors: [Color(0xFF9C27B0), Color(0xFFE040FB)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isMagic ? null : [
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
                              if (isMagic)
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.6),
                                  blurRadius: 6,
                                  spreadRadius: 0,
                                ),
                            ],
                          ),
                          child: isMagic
                              ? const Center(
                                  child: Text('★', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                )
                              : null,
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
                  // Main ball
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
                  // Extra balls (power-up)
                  ..._extraBalls.map((b) => Positioned(
                    left: b.x * _gameWidth - ballRadius,
                    top: b.y * _gameHeight - ballRadius,
                    child: Container(
                      width: ballRadius * 2,
                      height: ballRadius * 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.shade200,
                        border: Border.all(color: Colors.orange, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  )),
                  // Projectiles (firing power-up)
                  ..._projectiles.map((p) => Positioned(
                    left: p.x * _gameWidth - _projectileWidth / 2,
                    top: p.y * _gameHeight - _projectileHeight / 2,
                    child: Container(
                      width: _projectileWidth,
                      height: _projectileHeight,
                      decoration: BoxDecoration(
                        color: Colors.cyan.shade300,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                    ),
                  )),
                  // Power-up indicator
                  if (_hasPowerUp)
                    Positioned(
                      top: 8,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'POWER UP!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
