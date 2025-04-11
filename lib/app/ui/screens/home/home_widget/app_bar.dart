import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart'; // Thêm dependency lottie nếu chưa có

class HomeAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget title;

  const HomeAppBar({
    super.key,
    required this.title,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(110); // Tăng nhẹ để chứa thêm chi tiết

  @override
  State<HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> with TickerProviderStateMixin {
  late AnimationController _compassController;
  late AnimationController _chestController;
  late AnimationController _titleController;
  late AnimationController _particleController;
  late Animation<double> _titleShake;
  late Animation<double> _chestGlow;
  int explorationXP = 0;
  int level = 1;
  int coins = 0; // Thêm tiền tệ mới
  bool showTreasure = false;
  int titleTapCount = 0;
  DateTime? lastTitleTapTime;

  @override
  void initState() {
    super.initState();
    _compassController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _chestController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _titleShake = Tween<double>(begin: 0.0, end: 0.03).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.elasticOut),
    );
    _chestGlow = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _chestController, curve: Curves.easeInOut),
    );
    _loadData();
  }

  @override
  void dispose() {
    _compassController.dispose();
    _chestController.dispose();
    _titleController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      explorationXP = prefs.getInt('userXp') ?? 0;
      level = prefs.getInt('level') ?? 1;
      coins = prefs.getInt('coins') ?? 0;
      showTreasure = explorationXP >= _xpForNextLevel(level - 1);
    });
  }

  Future<void> _saveData(
      {required int xp, required int lvl, required int coin}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userXp', xp);
    await prefs.setInt('level', lvl);
    await prefs.setInt('coins', coin);

    if (mounted) {
      setState(() {
        explorationXP = xp;
        level = lvl;
        coins = coin;
        showTreasure = explorationXP >= _xpForNextLevel(level - 1);
      });
    }
  }

  int _xpForNextLevel(int currentLevel) =>
      (currentLevel + 1) * 50 + (currentLevel * 20);

  void _handleTitleTap() {
    _titleController.forward(from: 0.0).then((_) => _titleController.reverse());
    HapticFeedback.lightImpact();

    final now = DateTime.now();
    if (lastTitleTapTime != null &&
        now.difference(lastTitleTapTime!).inSeconds < 2) {
      titleTapCount++;
    } else {
      titleTapCount = 1;
    }
    lastTitleTapTime = now;

    if (titleTapCount >= 3 && mounted) {
      final random = Random();
      final bonusXP = 20 + random.nextInt(31); // 20-50 XP
      final bonusCoins = 10 + random.nextInt(21); // 10-30 Coins
      final newXP = explorationXP + bonusXP;
      final nextLevelXP = _xpForNextLevel(level);
      final newLevel = newXP >= nextLevelXP ? level + 1 : level;

      setState(() {
        titleTapCount = 0;
        _saveData(xp: newXP, lvl: newLevel, coin: coins + bonusCoins);
      });

      _particleController
          .forward(from: 0.0)
          .then((_) => _particleController.reset());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Lottie.asset('assets/lottie/treasure_chest.json',
                  width: 24, height: 24),
              const SizedBox(width: 8),
              Text(
                'Bí mật: +$bonusXP XP & +$bonusCoins Coins${newXP >= nextLevelXP ? " - Lên cấp!" : ""}!',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          backgroundColor: Colors.purpleAccent.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          margin: const EdgeInsets.fromLTRB(10, 10, 10, 80),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Color _getGradientColor() {
    if (level >= 10) return Colors.redAccent; // Cao cấp
    if (level >= 5) return Colors.orangeAccent; // Trung cấp
    if (level >= 3) return Colors.yellowAccent; // Khá
    return Colors.blueAccent; // Cơ bản
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              Colors.black.withOpacity(0.9),
              _getGradientColor().withOpacity(0.6),
            ],
          ),
          border: Border(
            bottom: BorderSide(
              color: _getGradientColor().withOpacity(0.7),
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: _getGradientColor().withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nút khám phá với hiệu ứng xoay và glow
                    GestureDetector(
                      onTap: () {
                        _compassController.forward(from: 0.0);
                        HapticFeedback.selectionClick();
                        Navigator.pushNamed(context, '/home');
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _compassController,
                            builder: (_, __) => Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    _getGradientColor().withOpacity(
                                        0.5 * _compassController.value),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          RotationTransition(
                            turns: Tween(begin: 0.0, end: 0.5).animate(
                              CurvedAnimation(
                                  parent: _compassController,
                                  curve: Curves.easeInOut),
                            ),
                            child: Icon(
                              Icons.explore,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tiêu đề với hiệu ứng rung và particle
                    Expanded(
                      child: GestureDetector(
                        onTap: _handleTitleTap,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _titleShake,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: sin(_titleShake.value * 12) * 0.06,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: _getGradientColor(), width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _getGradientColor()
                                              .withOpacity(0.7),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: DefaultTextStyle(
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 1.5,
                                        shadows: [
                                          Shadow(
                                            color: _getGradientColor(),
                                            blurRadius: 8,
                                          ),
                                        ],
                                        fontFamily: 'FantasyFont',
                                      ),
                                      child: widget.title,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_particleController.isAnimating)
                              AnimatedBuilder(
                                animation: _particleController,
                                builder: (_, __) => CustomPaint(
                                  painter: ParticlePainter(
                                      _particleController.value),
                                  size: const Size(100, 50),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Nút kho báu với hiệu ứng glow và mở rương
                    GestureDetector(
                      onTap: () {
                        if (showTreasure && mounted) {
                          _chestController.forward(from: 0.0);
                          HapticFeedback.heavyImpact();
                          final random = Random();
                          final rewardCoins =
                              50 + random.nextInt(51); // 50-100 Coins
                          setState(() {
                            explorationXP =
                                explorationXP % _xpForNextLevel(level - 1);
                            coins += rewardCoins;
                            _saveData(
                                xp: explorationXP, lvl: level, coin: coins);
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Lottie.asset(
                                      'assets/lottie/treasure_chest.json',
                                      width: 24,
                                      height: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kho báu: +$rewardCoins Coins!',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.orangeAccent,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                              margin: const EdgeInsets.fromLTRB(10, 10, 10, 80),
                            ),
                          );
                        }
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _chestGlow,
                            builder: (_, __) => Container(
                              width: 45 * _chestGlow.value,
                              height: 45 * _chestGlow.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.yellow
                                        .withOpacity(showTreasure ? 0.7 : 0.0),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.card_giftcard,
                            color: showTreasure
                                ? Colors.yellowAccent
                                : Colors.grey,
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Progress bar với hiệu ứng gradient
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.black.withOpacity(0.6),
                        border: Border.all(
                            color: _getGradientColor().withOpacity(0.3)),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (explorationXP / _xpForNextLevel(level - 1))
                          .clamp(0.0, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getGradientColor(),
                              _getGradientColor().withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      elevation: 0,
      toolbarHeight: 110,
    );
  }
}

// Painter cho particle effect
class ParticlePainter extends CustomPainter {
  final double progress;

  ParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint()..color = Colors.yellowAccent.withOpacity(0.8);
    for (int i = 0; i < 10; i++) {
      final x = size.width * 0.5 +
          (random.nextDouble() - 0.5) * size.width * progress;
      final y = size.height * 0.5 +
          (random.nextDouble() - 0.5) * size.height * progress;
      canvas.drawCircle(Offset(x, y), 2 * (1 - progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
