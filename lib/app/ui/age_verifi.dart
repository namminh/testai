import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/exam_prep_view_model.dart';
import '../routes/routes.dart';
import '../data/providers/base_view.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import '../core/utils/soundUtils.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import '../data/models/quest.dart';

class AgeVerificationScreen extends StatefulWidget {
  const AgeVerificationScreen({super.key});

  @override
  _AgeVerificationScreenState createState() => _AgeVerificationScreenState();
}

class _AgeVerificationScreenState extends State<AgeVerificationScreen>
    with SingleTickerProviderStateMixin {
  String? selectedAgeGroup;
  String? selectedAvatar;
  String? selectedAccessory;
  String? _narrativeMessage;
  late ExamPrepViewModel model;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;
  bool _isLoading = false;
  int _xp = 0;
  int _coins = 0;
  String _currentQuest = "Giải mã cánh cổng để bắt đầu hành trình!";
  List<Quest> _quests = [
    Quest("Giải mã cánh cổng cổ", 50, 20),
    Quest("Chinh phục bài kiểm tra đầu tiên", 100, 50),
    Quest("Khám phá kho báu huyền thoại", 200, 100, isSecret: true),
  ];
  int _currentQuestIndex = 0;
  bool _showIntro = true;

  int get _level => (_xp / 500).floor() + 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _loadProgress();
    _controller.forward();
    _playIntro();
  }

  Future<void> _playIntro() async {
    SoundUtils.playSound(Sounds.correct); // Giả lập âm thanh intro
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _showIntro = false);
      _confettiController.play();
    }
  }

  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _xp = prefs.getInt('userXp') ?? 0;
        _coins = prefs.getInt('userCoins') ?? 0;
      });
    } catch (e) {
      print('Error loading progress: $e');
      var box = await Hive.openBox('tempProgress');
      setState(() {
        _xp = box.get('xp', defaultValue: 0);
        _coins = box.get('coins', defaultValue: 0);
      });
    }
  }

  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('userXp', _xp);
      await prefs.setInt('userCoins', _coins);
    } catch (e) {
      var box = await Hive.openBox('tempProgress');
      await box.put('xp', _xp);
      await box.put('coins', _coins);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _nextQuest() {
    setState(() {
      _currentQuestIndex = (_currentQuestIndex + 1) % _quests.length;
      _quests[_currentQuestIndex] = _evolveQuest(_quests[_currentQuestIndex]);
      _currentQuest = _quests[_currentQuestIndex].description;
      if (Random().nextDouble() < 0.3) {
        _currentQuestIndex = _quests.indexWhere((q) => q.isSecret);
        _currentQuest = _quests[_currentQuestIndex].description;
      }
    });
  }

  Quest _evolveQuest(Quest current) {
    final mutation = Random().nextDouble();
    return Quest(
      "${current.description} ${mutation > 0.5 ? 'Huyền Thoại' : 'Bí Ẩn'}",
      (current.xpReward * (1 + mutation)).toInt(),
      (current.coinReward * (1 + mutation)).toInt(),
      isSecret: current.isSecret,
    );
  }

  Future<void> _setAgeAndQuestions() async {
    if (selectedAgeGroup == null) return;
    setState(() => _isLoading = true);
    String ageValue;
    if (selectedAgeGroup!.toLowerCase().contains('dưới 10')) {
      model.subjectController.text = 'Lớp 5';
      model.topicController.text = 'Ai thông minh hơn học sinh lớp 5';
      await model.generateQuestionsUnder10();
      ageValue = '10';
    } else if (selectedAgeGroup!.toLowerCase().contains('10-17')) {
      model.subjectController.text = 'Học sinh Trung học';
      model.topicController.text = 'Khoa học - Tự nhiên - Xã hội';
      await model.generateQuestions10to18();
      ageValue = '17';
    } else {
      model.subjectController.text = 'Văn học, Lịch sử, Địa lý';
      model.topicController.text = 'Kiến thức phổ thông';
      await model.generateQuestionsOver18();
      ageValue = '18';
    }
    model.age = ageValue;
    _completeQuest();
    setState(() => _isLoading = false);
  }

  Future<void> _checkLevelUp() async {
    int newLevel = _level;
    int previousLevel =
        ((_xp - _quests[_currentQuestIndex].xpReward) / 500).floor() + 1;
    if (newLevel > previousLevel) {
      SoundUtils.playSound(Sounds.correct);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          content: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.yellow[800]!, Colors.orange[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie.asset('assets/lottie/level_up.json',
                //     width: 100, height: 100),
                // const Text('Thăng Cấp Huyền Thoại!',
                //     style: TextStyle(
                //         fontSize: 24,
                //         color: Colors.white,
                //         fontWeight: FontWeight.bold)),
                Text('Chúc mừng bạn đạt cấp $newLevel!',
                    style:
                        const TextStyle(fontSize: 16, color: Colors.white70)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Tiếp tục Phiêu Lưu',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _completeQuest() {
    setState(() {
      _xp += _quests[_currentQuestIndex].xpReward;
      _coins += _quests[_currentQuestIndex].coinReward;
      if (Random().nextDouble() < 0.5) {
        // Tăng tỷ lệ phần thưởng bất ngờ
        _xp += 75;
        _coins += 30;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kho báu bí mật: +75 XP, +30 Đồng!'),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _currentQuest = "Khám phá thế giới kiến thức!";
      _nextQuest();
    });
    _saveProgress();
    _checkLevelUp();
    _showRewardDialog();
  }

  void _showRewardDialog() {
    final confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    SoundUtils.playSound(Sounds.correct);
    int particleCount = _quests[_currentQuestIndex].xpReward > 100 ? 60 : 30;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Stack(
        alignment: Alignment.topCenter,
        children: [
          AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.purple[800]!, Colors.blue[700]!],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.yellow[300]!, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 3,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rương Báu Mở Ra!',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'FantasyFont')),
                  const SizedBox(height: 16),
                  Lottie.asset('assets/lottie/treasure_chest.json',
                      width: 150, height: 150, repeat: false),
                  const SizedBox(height: 16),
                  Text(_getPersonalizedMessage(),
                      style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'FantasyFont'),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.stars, color: Colors.yellow, size: 28),
                      const SizedBox(width: 8),
                      Text('+${_quests[_currentQuestIndex].xpReward} XP',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      const Icon(Icons.monetization_on,
                          color: Colors.yellow, size: 28),
                      const SizedBox(width: 8),
                      Text('+${_quests[_currentQuestIndex].coinReward} Đồng',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.yellow,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, Routes.quizGame);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 5,
                    ),
                    child: const Text('Bắt Đầu Mini-Game',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'FantasyFont')),
                  ),
                ],
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            colors: const [
              Colors.yellow,
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.purple
            ],
            numberOfParticles: particleCount,
            emissionFrequency: 0.03,
          ),
        ],
      ),
    ).then((_) => confettiController.dispose());
    confettiController.play();
  }

  String _getPersonalizedMessage() {
    if (selectedAvatar == null) return 'Chúc mừng bạn đã mở rương!';
    if (selectedAvatar!.contains('Nhí')) {
      return 'Nhà Thám Hiểm Nhí đã khám phá kho báu${selectedAccessory != null ? " với $selectedAccessory!" : "!"}';
    }
    if (selectedAvatar!.contains('Olympia')) {
      return 'Olympia Học Đường chinh phục vinh quang${selectedAccessory != null ? " với $selectedAccessory!" : "!"}';
    }
    return 'Học Giả Bí Ẩn đã giải mã huyền thoại${selectedAccessory != null ? " với $selectedAccessory!" : "!"}';
  }

  void _startNarrative() {
    if (selectedAvatar == null) return;
    if (selectedAvatar!.contains('Nhí')) {
      _narrativeMessage =
          'Nhà Thám Hiểm Nhí, bước qua rừng tri thức để tìm kho báu!';
    } else if (selectedAvatar!.contains('Olympia')) {
      _narrativeMessage =
          'Olympia Học Đường, chinh phục ngọn núi Kiến Thức vĩ đại!';
    } else {
      _narrativeMessage = 'Học Giả Bí Ẩn, giải mã bí ẩn trong thư viện cổ xưa!';
    }
    setState(() {});
  }

  void _showLeaderboard() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[900]!, Colors.purple[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bảng Vinh Danh',
                  style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FantasyFont')),
              const SizedBox(height: 16),
              _buildLeaderboardItem(1, 'Nhà Thám Hiểm Nhí', 1500),
              _buildLeaderboardItem(2, 'Olympia Học Đường', 1200),
              _buildLeaderboardItem(3, 'Học Giả Bí Ẩn', 900),
              const Divider(color: Colors.white70),
              _buildLeaderboardItem(-1, 'Bạn', _xp),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child:
                    const Text('Đóng', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(int rank, String name, int xp) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          rank > 0
              ? Row(
                  children: [
                    Icon(
                      rank == 1
                          ? Icons.emoji_events
                          : rank == 2
                              ? Icons.star
                              : Icons.military_tech,
                      color: rank == 1
                          ? Colors.yellow
                          : rank == 2
                              ? Colors.grey
                              : Colors.brown,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text('$rank.',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                )
              : const Icon(Icons.person, color: Colors.yellow, size: 24),
          const SizedBox(width: 8),
          Expanded(
              child: Text(name, style: const TextStyle(color: Colors.white))),
          Text('$xp XP',
              style: const TextStyle(
                  color: Colors.yellow, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (m) => model = m,
      builder: (context, _, __) => Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purple[700]!,
                    Colors.blue[500]!,
                    Colors.yellow[300]!
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: _showIntro
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Lottie.asset('assets/lottie/portal.json',
                                  //     width: 200, height: 200),
                                  // const SizedBox(height: 20),
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        Colors.yellow[300]!,
                                        Colors.white
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: const Text(
                                      'Bắt Đầu Huyền Thoại Kiến Thức!',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontFamily: 'FantasyFont',
                                        shadows: [
                                          Shadow(
                                              color: Colors.yellow,
                                              blurRadius: 10),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ScaleTransition(
                              scale: _scaleAnimation,
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ShaderMask(
                                        shaderCallback: (bounds) =>
                                            LinearGradient(
                                          colors: [
                                            Colors.yellow[300]!,
                                            Colors.white
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                        child: const Text(
                                          'Khởi Đầu Phiêu Lưu Huyền Thoại!',
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            fontFamily: 'FantasyFont',
                                            shadows: [
                                              Shadow(
                                                  color: Colors.yellow,
                                                  blurRadius: 10),
                                            ],
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(_currentQuest,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 18,
                                              fontFamily: 'FantasyFont'),
                                          textAlign: TextAlign.center),
                                      if (_narrativeMessage != null) ...[
                                        const SizedBox(height: 16),
                                        Text(_narrativeMessage!,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontStyle: FontStyle.italic,
                                                fontFamily: 'FantasyFont'),
                                            textAlign: TextAlign.center),
                                      ],
                                      const SizedBox(height: 40),
                                      ...[
                                        {
                                          'age': 'Lứa tuổi dưới 10',
                                          'avatar': 'Nhà Thám Hiểm Nhí',
                                          'lottie': 'kid_explorer.json'
                                        },
                                        {
                                          'age': 'Lứa tuổi 10-17',
                                          'avatar': 'Olympia Học Đường',
                                          'lottie': 'knight_student.json'
                                        },
                                        {
                                          'age': 'Lứa tuổi trên 18',
                                          'avatar': 'Học Giả Bí Ẩn',
                                          'lottie': 'scholar_mystic.json'
                                        },
                                      ].map((data) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: _buildAgeCard(
                                                data['age']!,
                                                data['avatar']!,
                                                data['lottie']!),
                                          )),
                                      const SizedBox(height: 24),
                                      if (selectedAgeGroup != null)
                                        AnimatedScale(
                                          scale: _isLoading ? 1.1 : 1.0,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : () async {
                                                    await _setAgeAndQuestions();
                                                    _debugWithASCII();
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.orange,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 48,
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              elevation: 5,
                                              shadowColor: Colors.yellow
                                                  .withOpacity(0.5),
                                            ),
                                            child: _isLoading
                                                ? Lottie.asset(
                                                    'assets/lottie/aiNemo.json',
                                                    width: 40,
                                                    height: 40)
                                                : const Text(
                                                    'Chinh phục Nhiệm vụ!',
                                                    style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'FantasyFont')),
                                          ),
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
            ),
            Positioned(
              top: 0,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [
                  Colors.green,
                  Colors.yellow,
                  Colors.blue,
                  Colors.pink,
                  Colors.purple
                ],
                numberOfParticles: 50,
                emissionFrequency: 0.02,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    double xpProgress = (_xp % 500) / 500;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Lottie.asset('assets/lottie/aiNemo.json', width: 70, height: 70),
          Column(
            children: [
              Text('Cấp $_level',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FantasyFont')),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.stars, color: Colors.yellow, size: 24),
                  const SizedBox(width: 5),
                  Text('$_xp XP',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  const Icon(Icons.monetization_on,
                      color: Colors.yellow, size: 24),
                  const SizedBox(width: 5),
                  Text('$_coins Đồng',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.leaderboard,
                        color: Colors.white, size: 28),
                    onPressed: _showLeaderboard,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 150,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: xpProgress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.yellow[300]!, Colors.orange[600]!],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgeCard(String age, String avatar, String lottieAsset) {
    final bool isSelected = selectedAgeGroup == age;
    return AnimatedScale(
      scale: isSelected ? 1.15 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: isSelected ? 12 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: InkWell(
          onTap: () {
            setState(() {
              selectedAgeGroup = age;
              selectedAvatar = avatar;
              _confettiController.play();
              SoundUtils.playSound(Sounds.correct);
            });
            _startNarrative();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isSelected
                    ? [Colors.blue[600]!, Colors.green[700]!]
                    : [Colors.grey[800]!, Colors.grey[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? Colors.yellow[300]! : Colors.transparent,
                width: 2,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              children: [
                Lottie.asset('assets/lottie/$lottieAsset',
                    width: 60, height: 60),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(age,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color:
                                  isSelected ? Colors.white : Colors.grey[300],
                              fontFamily: 'FantasyFont')),
                      Text(avatar,
                          style: TextStyle(
                              fontSize: 16,
                              color: isSelected
                                  ? Colors.white70
                                  : Colors.grey[500],
                              fontFamily: 'FantasyFont')),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: Colors.yellow, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _debugWithASCII() {
    print('''
    Quest Completed!
    XP: |||||| (${_quests[_currentQuestIndex].xpReward})
    Coins:  (${_quests[_currentQuestIndex].coinReward})
    ''');
  }
}
