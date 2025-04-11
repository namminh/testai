import 'dart:math';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/auth_view_model.dart';
import '../../../routes/routes.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/soundUtils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

final authViewModel = AuthViewModel();

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late Animation<double> _logoSpin;
  late ConfettiController _confettiController;
  Map<String, Quest> _quests = {};
  int _xp = 0;
  int _gold = 0;
  int _streak = 0; // New: Daily login streak
  List<String> _badges = []; // New: Achievement badges
  late AnimationController _avatarController;
  late AnimationController _particleController;
  bool _showParticles = false;

  @override
  void initState() {
    super.initState();
    _avatarController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    _particleController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();

    _logoAnimationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _logoSpin = Tween<double>(begin: 0, end: 2 * pi).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.easeOut),
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    SoundUtils.setVolume(0.3);
    SoundUtils.playSound(Sounds.appstart);
    _loadProgress();
    _checkDailyStreak(); // New: Check streak on init
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _xp = prefs.getInt('userXp') ?? 0;
      _gold = prefs.getInt('userGold') ?? 0;
      _streak = prefs.getInt('streak') ?? 0;
      _badges = prefs.getStringList('badges') ?? [];
      _quests = {
        'Chơi Ngay': Quest('Chơi Ngay', prefs.getBool('task_play') ?? false, 1),
        'Luyện Thi': Quest('Luyện Thi', prefs.getBool('task_exam') ?? false, 2),
        'Khám Phá Kiến Thức': Quest(
            'Khám Phá Kiến Thức', prefs.getBool('task_explore') ?? false, 1),
        'Thách Đấu Bạn Bè': Quest(
            'Thách Đấu Bạn Bè', prefs.getBool('task_friends') ?? false, 3),
        'Hành Trang':
            Quest('Hành Trang', prefs.getBool('task_profile') ?? false, 1),
        'Chọn Lại Đường Đi':
            Quest('Chọn Lại Đường Đi', prefs.getBool('task_reset') ?? false, 2),
      };
      _checkAchievements(); // New: Check badges on load
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userXp', _xp);
    await prefs.setInt('userGold', _gold);
    await prefs.setInt('streak', _streak);
    await prefs.setStringList('badges', _badges);
    _quests
        .forEach((key, quest) => prefs.setBool('task_$key', quest.completed));
  }

  // New: Daily streak logic
  Future<void> _checkDailyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogin = prefs.getInt('lastLogin') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final oneDay = 24 * 60 * 60 * 1000;

    if (now - lastLogin > oneDay && now - lastLogin < 2 * oneDay) {
      setState(() => _streak++);
      _awardStreakReward();
    } else if (now - lastLogin > 2 * oneDay) {
      setState(() => _streak = 1); // Reset streak
    }
    await prefs.setInt('lastLogin', now);
    _saveProgress();
  }

  void _awardStreakReward() {
    final reward = _streak * 10;
    setState(() {
      _gold += reward;
    });
    _confettiController.play();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đăng nhập ngày $_streak: +$reward Đồng!')),
    );
  }

  // New: Achievement system
  void _checkAchievements() {
    if (_xp >= 100 && !_badges.contains('XP Master')) {
      _badges.add('XP Master');
      _showBadgeDialog('XP Master', 'Đạt 100 XP!');
    }
    if (_quests.values.where((q) => q.completed).length >= 5 &&
        !_badges.contains('Quest Hero')) {
      _badges.add('Quest Hero');
      _showBadgeDialog('Quest Hero', 'Hoàn thành 5 nhiệm vụ!');
    }
  }

  void _showBadgeDialog(String badge, String message) {
    showDialog(
      context: context,
      barrierColor:
          Colors.black.withOpacity(0.5), // Dimmed background for focus
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor:
            Colors.transparent, // Transparent to allow gradient container
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gradient container for dialog body
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack, // Bouncy reveal
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple[400]!,
                    Colors.blue[400]!,
                    Colors.cyan[200]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.yellow[400]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge icon with animation
                  AnimatedScale(
                    scale: 1.2, // Slightly oversized then settles
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    child: Icon(
                      Icons.emoji_events, // Trophy icon
                      color: Colors.yellow[600],
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title with playful styling
                  Text(
                    'Huy Hiệu Mới: $badge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          offset: const Offset(2, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Message with fun tone
                  Text(
                    '$message\nTuyệt vời lắm!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action button with gradient
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ).copyWith(
                      foregroundColor: MaterialStateProperty.all(Colors.white),
                      overlayColor: MaterialStateProperty.all(
                          Colors.yellow[200]!.withOpacity(0.2)),
                      backgroundColor:
                          MaterialStateProperty.all(Colors.transparent),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange[500]!, Colors.red[400]!],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: const Text(
                        'Tuyệt vời!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Confetti celebration
            Positioned.fill(
              child: ConfettiWidget(
                confettiController: ConfettiController(
                  duration: const Duration(seconds: 2),
                )..play(), // Auto-play on dialog open
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [
                  Colors.red,
                  Colors.blue,
                  Colors.yellow,
                  Colors.green,
                ],
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                gravity: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _confettiController.dispose();
    _avatarController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[100]!, Colors.blue[300]!, Colors.yellow[100]!],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: GestureDetector(
                        onTap: _spinLuckyWheel,
                        child: RotationTransition(
                          turns: _logoSpin,
                          child: Image.asset(
                            "assets/logo/MLogo_HTL.png",
                            height: 150,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                      child: _buildPlayerInfo(context, authViewModel)),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(child: _buildQuestList(context)),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Lottie.asset(
                'assets/lottie/aiNemo.json',
                width: 80,
                height: 80,
                repeat: true,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [
                  Colors.green,
                  Colors.yellow,
                  Colors.blue,
                  Colors.red
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _spinLuckyWheel() {
    _logoAnimationController.forward(from: 0).then((_) {
      final rewards = [
        {'xp': 10, 'gold': 5},
        {'xp': 20, 'gold': 10},
        {'xp': 50, 'gold': 0, 'item': 'Đá Quý'},
      ];
      final reward = rewards[Random().nextInt(rewards.length)];
      setState(() {
        _xp += reward['xp'] as int;
        _gold += reward['gold'] as int;
        _checkAchievements(); // Check for badges after reward
      });
      _confettiController.play();
      SoundUtils.playSound(Sounds.correct);
      _saveProgress();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Bạn nhận +${reward['xp']} XP, +${reward['gold']} Đồng${reward['item'] != null ? ", ${reward['item']}" : ""}!')),
      );
    });
  }

  Widget _buildPlayerInfo(BuildContext context, AuthViewModel authViewModel) {
    return GestureDetector(
      onLongPress: () => authViewModel
          .getTotalScoreStream()
          .first, // Long press để hoàn thành Quest
      onTap: () => Navigator.pushNamed(context, Routes.countdown),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.purple[900]!,
                Colors.blue[700]!,
                Colors.cyan[400]!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 2),
            image: const DecorationImage(
              image: AssetImage('assets/images/rune_border.png'),
              fit: BoxFit.cover,
              opacity: 0.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildAvatar(authViewModel),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildScore(authViewModel),
                          const SizedBox(
                              height:
                                  12), // Slightly increased spacing for breathing room
                          // Animated container for radial progress with glow on level-up
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                if ((_xp ~/ 100) > 0 &&
                                    (_xp % 100) == 0) // Glow on level-up
                                  BoxShadow(
                                    color: Colors.yellow[400]!.withOpacity(0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                              ],
                            ),
                            child:
                                _buildRadialProgress(), // Enhanced radial progress from previous improvement
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AuthViewModel authViewModel) {
    final level = _xp ~/ 100;
    return ScaleTransition(
      scale: Tween(begin: 0.9, end: 1.0).animate(_avatarController),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
          boxShadow: [
            if (level > 0)
              BoxShadow(
                color: Colors.yellow.withOpacity(0.6),
                blurRadius: 12,
                spreadRadius: 2,
              ),
          ],
        ),
        child: CircleAvatar(
          radius: 30,
          backgroundImage: authViewModel.userphoto?.isNotEmpty ?? false
              ? NetworkImage(authViewModel.userphoto!)
              : null,
          child: authViewModel.userphoto?.isEmpty ?? true
              ? Icon(Icons.person, color: Colors.grey[600], size: 40)
              : null,
        ),
      ),
    );
  }

  Widget _buildScore(AuthViewModel authViewModel) {
    return StreamBuilder<int>(
      stream: authViewModel.getTotalScoreStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Text('Lỗi: ${snapshot.error}',
              style: const TextStyle(color: Colors.red));
        if (!snapshot.hasData) return const CircularProgressIndicator();

        final score = snapshot.data!;
        final level = score ~/ 10;
        final isLevelUp = level > 0 && score % 10 == 0;

        if (isLevelUp) {
          _avatarController.forward(from: 0.0);
          HapticFeedback.lightImpact();
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Row(
                children: [
                  Icon(
                    Icons.stars,
                    color: level >= 10 ? Colors.red[200] : Colors.yellow[200],
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Level $level',
                          style: TextStyle(
                            fontSize: 18,
                            color: level >= 10
                                ? Colors.red[200]
                                : Colors.yellow[200],
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${score * 1000} VNĐ',
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          '$_xp XP / $_gold Đồng',
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w400),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRadialProgress() {
    final levelProgress = (_xp % 100) / 100;

    return SizedBox(
      width: 70,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.grey[200]!, Colors.grey[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Custom painted progress ring
          AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
            width: 60,
            height: 60,
            child: CustomPaint(
              painter: GradientProgressPainter(
                progress: levelProgress == 0 ? 0.01 : levelProgress,
              ),
            ),
          ),
          // Inner glowing circle
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.blue[700]!.withOpacity(0.3),
                  Colors.blue[900]!.withOpacity(0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue[400]!.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Text
          Text(
            '${(_xp % 100)}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(1, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestList(BuildContext context) {
    return Column(
      children: _quests.entries.map((entry) {
        final quest = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildQuestCard(quest, () {
            if (!quest.completed) {
              setState(() {
                quest.completed = true;
                _xp += quest.rewardXp;
                _gold += quest.rewardGold;
                _checkAchievements(); // Check badges after quest completion
              });
              _confettiController.play();
              SoundUtils.playSound(Sounds.correct);
              _showTaskRewardDialog(context, quest);
            }
            quest.navigate(context);
          }),
        );
      }).toList(),
    );
  }

  Widget _buildQuestCard(Quest quest, VoidCallback onTap) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: quest.completed
                ? [
                    Colors.green[400]!.withOpacity(0.2),
                    Colors.green[700]!.withOpacity(0.2),
                  ]
                : [
                    Colors.blue[400]!.withOpacity(0.2),
                    Colors.blue[700]!.withOpacity(0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: quest.completed ? Colors.green[300]! : Colors.blue[300]!,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (quest.completed ? Colors.green : Colors.blue)
                  .withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: quest.completed
                        ? [Colors.green[300]!, Colors.green[700]!]
                        : [Colors.blue[300]!, Colors.blue[700]!],
                  ),
                  boxShadow: quest.completed
                      ? [
                          BoxShadow(
                              color: Colors.green.withOpacity(0.5),
                              blurRadius: 8)
                        ]
                      : [],
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.transparent,
                  child: Icon(quest.icon, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            quest.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              fontSize: 16,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange[700],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Lv ${quest.level}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (quest.completed)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: Colors.green[700], size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'Hoàn thành',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              quest.completed
                  ? const SizedBox.shrink()
                  : AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Khám phá',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskRewardDialog(BuildContext context, Quest quest) {
    showDialog(
      context: context,
      builder: (_) => _TaskRewardDialog(
        quest: quest,
        onReward: (xp, gold) {
          setState(() {
            _xp += xp;
            _gold += gold;
            _checkAchievements(); // Check badges after reward
          });
          _saveProgress();
        },
      ),
    );
  }
}

class Quest {
  final String title;
  bool completed;
  final int level;
  final int rewardXp;
  final int rewardGold;
  final IconData icon;

  Quest(this.title, this.completed, this.level)
      : rewardXp = level * 20,
        rewardGold = level * 10,
        icon = _getIconForQuest(title);

  static IconData _getIconForQuest(String title) {
    switch (title) {
      case 'Chơi Ngay':
        return Icons.games;
      case 'Luyện Thi':
        return Icons.school;
      case 'Khám Phá Kiến Thức':
        return Icons.explore;
      case 'Thách Đấu Bạn Bè':
        return Icons.group;
      case 'Hành Trang':
        return Icons.backpack;
      case 'Chọn Lại Đường Đi':
        return Icons.restart_alt;
      default:
        return Icons.star;
    }
  }

  void navigate(BuildContext context) {
    final routes = {
      'Chơi Ngay': Routes.quizGame,
      'Luyện Thi': Routes.subcription,
      'Khám Phá Kiến Thức': Routes.authRoute,
      'Thách Đấu Bạn Bè': Routes.friend,
      'Hành Trang': Routes.profileRoute,
      'Chọn Lại Đường Đi': Routes.age,
    };
    Navigator.pushNamed(context, routes[title]!);
  }
}

class _TaskRewardDialog extends StatelessWidget {
  final Quest quest;
  final Function(int, int) onReward;

  const _TaskRewardDialog({required this.quest, required this.onReward});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.blue[800],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chúc mừng! "${quest.title}" hoàn thành!',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Phần thưởng: +${quest.rewardXp} XP, +${quest.rewardGold} Đồng',
            style: const TextStyle(color: Colors.yellow, fontSize: 16),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onReward(quest.rewardXp, quest.rewardGold);
            Navigator.pop(context);
          },
          child: const Text('Nhận', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// Custom Painter for Gradient Progress
class GradientProgressPainter extends CustomPainter {
  final double progress;

  GradientProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 8.0;

    // Background circle (optional, if not using Container)
    final bgPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    // Gradient progress arc
    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi * progress,
        colors: [
          Colors.blue[900]!,
          Colors.cyan[400]!,
          Colors.yellow[600]!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // Start at top
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant GradientProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
