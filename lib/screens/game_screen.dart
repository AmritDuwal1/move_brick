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
  // Brick types: 0=empty, 1=normal, 2=fire, 3=paddleWide, 4=multiBall, 5=ballSlow, 6=extraLife, 7=explode, 8=coinRain, 9=surprise
  static const int _brickNormal = 1;
  static const int _brickMagicFire = 2;
  static const int _brickMagicPaddle = 3;
  static const int _brickMagicMultiBall = 4;
  static const int _brickMagicBallSlow = 5;
  static const int _brickMagicExtraLife = 6;
  static const int _brickMagicExplode = 7;
  static const int _brickMagicCoinRain = 8;
  static const int _brickSurprise = 9;
  static const int _firstMagic = 2;
  static const int _lastMagic = 9;

  static const Duration _powerUpDuration = Duration(seconds: 12);
  static const Duration _widePaddleDuration = Duration(seconds: 10);
  static const Duration _ballSpeedDuration = Duration(seconds: 10);
  static const Duration _badEffectDuration = Duration(seconds: 6);
  static const Duration _screenShakeDuration = Duration(milliseconds: 800);
  static const double _widePaddleMultiplier = 1.6;
  static const double _shrinkPaddleMultiplier = 0.6;
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
  DateTime? _firePowerUpEndTime;
  DateTime? _widePaddleEndTime;
  DateTime? _shrinkPaddleEndTime;
  DateTime? _multiBallPowerUpEndTime;
  DateTime? _ballSlowEndTime;
  DateTime? _ballFastEndTime;
  DateTime? _reversePaddleEndTime;
  DateTime? _screenShakeEndTime;
  double _ballSpeedMultiplier = 1.0;
  final List<_ExtraBall> _extraBalls = [];
  final List<_Projectile> _projectiles = [];
  int _frameCount = 0;
  final math.Random _random = math.Random();

  double get _currentPaddleWidth {
    final now = DateTime.now();
    if (_widePaddleEndTime != null && now.isBefore(_widePaddleEndTime!)) return paddleWidth * _widePaddleMultiplier;
    if (_shrinkPaddleEndTime != null && now.isBefore(_shrinkPaddleEndTime!)) return paddleWidth * _shrinkPaddleMultiplier;
    return paddleWidth;
  }

  bool get _paddleReversed => _reversePaddleEndTime != null && DateTime.now().isBefore(_reversePaddleEndTime!);
  bool get _hasFirePowerUp => _firePowerUpEndTime != null && DateTime.now().isBefore(_firePowerUpEndTime!);
  bool get _hasWidePaddle => _widePaddleEndTime != null && DateTime.now().isBefore(_widePaddleEndTime!);
  bool get _hasMultiBallPowerUp => _multiBallPowerUpEndTime != null && DateTime.now().isBefore(_multiBallPowerUpEndTime!);
  bool get _hasAnyPowerUp =>
      _hasFirePowerUp ||
      _hasWidePaddle ||
      _shrinkPaddleEndTime != null && DateTime.now().isBefore(_shrinkPaddleEndTime!) ||
      _hasMultiBallPowerUp ||
      _ballSlowEndTime != null && DateTime.now().isBefore(_ballSlowEndTime!) ||
      _ballFastEndTime != null && DateTime.now().isBefore(_ballFastEndTime!) ||
      _paddleReversed ||
      _screenShakeEndTime != null && DateTime.now().isBefore(_screenShakeEndTime!);

  @override
  void initState() {
    super.initState();
    _initBricks();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 16));
    _controller.addListener(_update);
  }

  void _initBricks() {
    _bricks = List.generate(brickRows, (_) => List.filled(brickCols, _brickNormal));
    if (_level == 1) return; // Level 1: plain, no magic

    // All possible positions for magic bricks
    final positions = <List<int>>[];
    for (var r = 0; r < brickRows; r++) for (var c = 0; c < brickCols; c++) positions.add([r, c]);
    positions.shuffle(_random);

    var idx = 0;
    void place(int type) {
      if (idx >= positions.length) return;
      final p = positions[idx++];
      _bricks[p[0]][p[1]] = type;
    }

    // Level 2+: (level-1) good magic types from pool [fire, paddle, ballSlow, multiBall, explode, coinRain]
    final goodPool = [_brickMagicFire, _brickMagicPaddle, _brickMagicBallSlow, _brickMagicMultiBall, _brickMagicExplode, _brickMagicCoinRain];
    final count = math.min(_level - 1, goodPool.length);
    for (var i = 0; i < count; i++) place(goodPool[i]);

    // Level 2+: one dedicated life box (heart)
    place(_brickMagicExtraLife);

    // Level 3+: one surprise box (rainbow ?, random good/bad)
    if (_level >= 3) place(_brickSurprise);
  }

  void _activateFirePowerUp() => _firePowerUpEndTime = DateTime.now().add(_powerUpDuration);
  void _activateWidePaddlePowerUp() => _widePaddleEndTime = DateTime.now().add(_widePaddleDuration);
  void _activateShrinkPaddle() => _shrinkPaddleEndTime = DateTime.now().add(_badEffectDuration);
  void _activateMultiBallPowerUp() {
    _multiBallPowerUpEndTime = DateTime.now().add(_powerUpDuration);
    for (var i = 0; i < _extraBallsCount; i++) {
      final angle = -0.5 * math.pi + (i - _extraBallsCount / 2) * 0.35;
      _extraBalls.add(_ExtraBall(_ballX, _ballY, 0.008 * math.cos(angle), 0.008 * math.sin(angle)));
    }
  }

  void _activateBallSlow() => _ballSlowEndTime = DateTime.now().add(_ballSpeedDuration);
  void _activateBallFast() => _ballFastEndTime = DateTime.now().add(_badEffectDuration);
  void _activateExtraLife() => _lives = math.min(_lives + 1, maxLives + 2);
  void _activateReversePaddle() => _reversePaddleEndTime = DateTime.now().add(_badEffectDuration);
  void _activateScreenShake() => _screenShakeEndTime = DateTime.now().add(_screenShakeDuration);

  void _explodeAt(int r, int c) {
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < brickRows && nc >= 0 && nc < brickCols && _bricks[nr][nc] != 0) {
          _bricks[nr][nc] = 0;
          _score += 10;
        }
      }
    }
  }

  void _coinRain() {
    for (var r = 0; r < brickRows; r++) for (var c = 0; c < brickCols; c++) if (_bricks[r][c] == _brickNormal) { _bricks[r][c] = 0; _score += 15; }
  }

  void _onMagicBrickHit(int type) {
    if (type == _brickMagicFire) _activateFirePowerUp();
    else if (type == _brickMagicPaddle) _activateWidePaddlePowerUp();
    else if (type == _brickMagicMultiBall) _activateMultiBallPowerUp();
    else if (type == _brickMagicBallSlow) _activateBallSlow();
    else if (type == _brickMagicExtraLife) _activateExtraLife();
    else if (type == _brickMagicExplode) {} // handled at hit site with r,c
    else if (type == _brickMagicCoinRain) _coinRain();
    else if (type == _brickSurprise) _applySurpriseEffect();
  }

  void _applySurpriseEffect() {
    final effects = [
      () => _activateFirePowerUp(),
      () => _activateWidePaddlePowerUp(),
      () => _activateMultiBallPowerUp(),
      () => _activateBallSlow(),
      () => _activateExtraLife(),
      () => _activateReversePaddle(),
      () => _activateShrinkPaddle(),
      () => _activateBallFast(),
      () => _activateScreenShake(),
    ];
    effects[_random.nextInt(effects.length)]();
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
      final now = DateTime.now();
      if (_firePowerUpEndTime != null && now.isAfter(_firePowerUpEndTime!)) { _firePowerUpEndTime = null; _projectiles.clear(); }
      if (_widePaddleEndTime != null && now.isAfter(_widePaddleEndTime!)) _widePaddleEndTime = null;
      if (_shrinkPaddleEndTime != null && now.isAfter(_shrinkPaddleEndTime!)) _shrinkPaddleEndTime = null;
      if (_multiBallPowerUpEndTime != null && now.isAfter(_multiBallPowerUpEndTime!)) { _multiBallPowerUpEndTime = null; _extraBalls.clear(); }
      if (_ballSlowEndTime != null && now.isAfter(_ballSlowEndTime!)) _ballSlowEndTime = null;
      if (_ballFastEndTime != null && now.isAfter(_ballFastEndTime!)) _ballFastEndTime = null;
      if (_reversePaddleEndTime != null && now.isAfter(_reversePaddleEndTime!)) _reversePaddleEndTime = null;
      if (_screenShakeEndTime != null && now.isAfter(_screenShakeEndTime!)) _screenShakeEndTime = null;

      _ballSpeedMultiplier = 1.0;
      if (_ballSlowEndTime != null && now.isBefore(_ballSlowEndTime!)) _ballSpeedMultiplier = 0.5;
      if (_ballFastEndTime != null && now.isBefore(_ballFastEndTime!)) _ballSpeedMultiplier = 1.8;

      const double paddleBottomGap = 24;
      final paddleTop = 1 - (paddleHeight + paddleBottomGap) / _gameHeight;
      final paddleBottom = paddleTop + paddleHeight / _gameHeight;
      final w = _currentPaddleWidth;
      final paddleLeft = _paddleX - (w / 2) / _gameWidth;
      final paddleRight = _paddleX + (w / 2) / _gameWidth;
      final halfW = _brickDrawWidth / 2 / _gameWidth + ballRadius / _gameWidth;
      final halfH = _brickDrawHeight / 2 / _gameHeight + ballRadius / _gameHeight;

      if (_hasFirePowerUp && _frameCount % _fireIntervalFrames == 0) {
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
          final t = _bricks[r][c];
          if (t == _brickMagicExplode) _explodeAt(r, c); else if (t >= _firstMagic && t <= _lastMagic) _onMagicBrickHit(t);
          _bricks[r][c] = 0;
          _score += 10;
          GameSounds.brickHit();
          hit = true;
        });
        if (hit) _projectiles.removeAt(i);
      }

      // Main ball (apply speed multiplier)
      _ballX += _ballDx * _ballSpeedMultiplier;
      _ballY += _ballDy * _ballSpeedMultiplier;
      _bounceBall(_ballX, _ballY, _ballDx, _ballDy, (nx, ny, ndx, ndy) {
        _ballX = nx;
        _ballY = ny;
        _ballDx = ndx;
        _ballDy = ndy;
      }, paddleLeft, paddleRight, paddleTop, paddleBottom);
      _checkBrickHit(_ballX, _ballY, halfW, halfH, (r, c) {
        final t = _bricks[r][c];
        if (t == _brickMagicExplode) _explodeAt(r, c); else if (t >= _firstMagic && t <= _lastMagic) _onMagicBrickHit(t);
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

      // Extra balls (apply speed multiplier)
      for (var i = _extraBalls.length - 1; i >= 0; i--) {
        final b = _extraBalls[i];
        b.x += b.dx * _ballSpeedMultiplier;
        b.y += b.dy * _ballSpeedMultiplier;
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
          final t = _bricks[r][c];
          if (t == _brickMagicExplode) _explodeAt(r, c); else if (t >= _firstMagic && t <= _lastMagic) _onMagicBrickHit(t);
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
      _firePowerUpEndTime = null;
      _widePaddleEndTime = null;
      _shrinkPaddleEndTime = null;
      _multiBallPowerUpEndTime = null;
      _ballSlowEndTime = null;
      _ballFastEndTime = null;
      _reversePaddleEndTime = null;
      _screenShakeEndTime = null;
      _ballSpeedMultiplier = 1.0;
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
    _firePowerUpEndTime = null;
    _widePaddleEndTime = null;
    _shrinkPaddleEndTime = null;
    _multiBallPowerUpEndTime = null;
    _ballSlowEndTime = null;
    _ballFastEndTime = null;
    _reversePaddleEndTime = null;
    _screenShakeEndTime = null;
    _ballSpeedMultiplier = 1.0;
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
              final shake = _screenShakeEndTime != null && DateTime.now().isBefore(_screenShakeEndTime!);
              final shakeOffset = shake ? Offset((( _frameCount * 7) % 7 - 3).toDouble(), ((_frameCount * 11) % 7 - 3).toDouble()) : Offset.zero;
              return Transform.translate(
                offset: shakeOffset,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final localX = d.globalPosition.dx - box.localToGlobal(Offset.zero).dx;
                  final w = _currentPaddleWidth;
                  var x = localX / _gameWidth;
                  if (_paddleReversed) x = 1 - x;
                  setState(() {
                    _paddleX = x.clamp((w / 2) / _gameWidth, 1 - (w / 2) / _gameWidth);
                  });
                },
                onHorizontalDragUpdate: (d) {
                  final localX = d.globalPosition.dx - (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero).dx;
                  final w = _currentPaddleWidth;
                  var x = localX / _gameWidth;
                  if (_paddleReversed) x = 1 - x;
                  setState(() {
                    _paddleX = x.clamp((w / 2) / _gameWidth, 1 - (w / 2) / _gameWidth);
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
                  // Mute button (top-right) – tap here toggles sound; tap elsewhere moves paddle
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: Icon(
                          GameSounds.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () {
                          GameSounds.toggleMuted();
                          setState(() {});
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      ),
                    ),
                  ),
                  // Bricks (normal colors vary by level for fresh UI each level)
                  ..._bricks.asMap().entries.expand((rowEntry) {
                    final r = rowEntry.key;
                    return rowEntry.value.asMap().entries.map((colEntry) {
                      final c = colEntry.key;
                      final type = colEntry.value;
                      if (type == 0) return const SizedBox.shrink();
                      final cellW = _gameWidth / brickCols;
                      final top = _brickTopOffset + r * _brickRowSpacing;
                      final left = _brickLeftPadding + c * cellW;
                      // Level-based color schemes for normal bricks
                      final levelPalette = _level % 4;
                      final normalColors = [
                        [Colors.deepOrange, Colors.orange, Colors.amber, Colors.yellow.shade700, Colors.orange.shade300],
                        [Colors.teal, Colors.cyan.shade700, Colors.blue.shade300, Colors.indigo.shade300, Colors.blue.shade200],
                        [Colors.pink.shade700, Colors.pink.shade400, Colors.purple.shade300, Colors.deepPurple.shade300, Colors.purple.shade200],
                        [Colors.green.shade800, Colors.green.shade600, Colors.lightGreen.shade400, Colors.lime.shade400, Colors.green.shade200],
                      ][levelPalette];
                      // Magic bricks: different UI per type
                      BoxDecoration? decoration;
                      Widget? magicChild;
                      if (type == _brickMagicFire) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE65100), Color(0xFFFF9800), Color(0xFFFF5722)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.orange.withOpacity(0.7), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('🔥', style: TextStyle(fontSize: 18)));
                      } else if (type == _brickMagicPaddle) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF42A5F5), Color(0xFF90CAF9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.blue.withOpacity(0.6), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('⇔', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)));
                      } else if (type == _brickMagicMultiBall) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B1FA2), Color(0xFFE040FB), Color(0xFFBA68C8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.purple.withOpacity(0.6), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('⭐', style: TextStyle(fontSize: 18)));
                      } else if (type == _brickMagicBallSlow) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF26A69A), Color(0xFF4DB6AC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.teal.withOpacity(0.6), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('🐢', style: TextStyle(fontSize: 16)));
                      } else if (type == _brickMagicExtraLife) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD32F2F), Color(0xFFE57373), Color(0xFFFFCDD2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.red.withOpacity(0.6), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('❤️', style: TextStyle(fontSize: 18)));
                      } else if (type == _brickMagicExplode) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF455A64), Color(0xFF78909C), Color(0xFF90A4AE)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.orange.withOpacity(0.8), blurRadius: 8, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('💥', style: TextStyle(fontSize: 18)));
                      } else if (type == _brickMagicCoinRain) {
                        decoration = BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFC107), Color(0xFFFFA000)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.amber.withOpacity(0.7), blurRadius: 6, spreadRadius: 0),
                          ],
                        );
                        magicChild = const Center(child: Text('🪙', style: TextStyle(fontSize: 18)));
                      } else if (type == _brickSurprise) {
                        decoration = BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(0.9),
                              Colors.orange.withOpacity(0.9),
                              Colors.yellow.withOpacity(0.9),
                              Colors.green.withOpacity(0.9),
                              Colors.blue.withOpacity(0.9),
                              Colors.purple.withOpacity(0.9),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            const BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                            BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 8, spreadRadius: 0),
                          ],
                        );
                        magicChild = Center(
                          child: Transform.translate(
                            offset: Offset(0, 3 * math.sin(_frameCount * 0.12)),
                            child: const Text('❓', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          ),
                        );
                      } else {
                        decoration = BoxDecoration(
                          color: normalColors[r % 5],
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1)),
                          ],
                        );
                      }
                      return Positioned(
                        left: left,
                        top: top,
                        child: Container(
                          width: _brickDrawWidth,
                          height: _brickDrawHeight,
                          decoration: decoration,
                          child: magicChild,
                        ),
                      );
                    });
                  }),
                  // Paddle
                  Positioned(
                    left: (_paddleX * _gameWidth - _currentPaddleWidth / 2).clamp(0.0, _gameWidth - _currentPaddleWidth),
                    bottom: 24,
                    child: Container(
                      width: _currentPaddleWidth,
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
                  if (_hasAnyPowerUp)
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
              ),
              );
            },
          ),
        ),
      ),
    );
  }
}
