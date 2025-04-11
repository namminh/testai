import 'package:flutter/material.dart';
import 'package:nemoai/app/routes/routes.dart';
import '../../../data/models/quiz_question_model.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/exam_prep_view_model.dart';
import 'dart:math';
import 'package:flutter_math_fork/flutter_math.dart';
import '../home/home_widget/app_bar.dart';
import '../../../core/utils/soundUtils.dart';
import 'package:confetti/confetti.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../data/models/card.dart';
import 'dart:io';
import '../../../../dir_helper.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:async';
import 'package:flip_card/flip_card.dart';
import './battle_card.dart';
import 'card_detail.dart';

enum LearningStyle { kinesthetic, visual, auditory }

class QuestionsGame extends StatefulWidget {
  const QuestionsGame({super.key});

  @override
  _QuestionsGameState createState() => _QuestionsGameState();
}

class _QuestionsGameState extends State<QuestionsGame>
    with TickerProviderStateMixin {
  final Map<String, double> playersPositions =
      {}; // Thay playersLevels bằng playersPositions
// Key: playerId hoặc aiId, Value: level (0-15)

  ExamPrepViewModel? model;
  bool _isLoading = true;
  List<List<String>>? _shuffledOptions;
  int _currentQuestionIndex = 0;
  Map<int, String> selectedAnswers = {};
  late PageController _pageController;
  late ConfettiController _confettiController;
  int score = 0;
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;
  ProgressionEngine progression = ProgressionEngine();

  late BehaviorAnalyzer behaviorAnalyzer; // phan tich hanh vi
  late _QuizTimer _timer;

  String? myPlayerId; // ID của người chơi hiện tại
  final Random _random = Random();
  double raceLength = 1.0; // Chiều dài đường đua ảo, ban đầu là 1.0
  double? previousAnswerTime; // Thời gian trả lời câu trước
  final int maxLevel = 15; // Tổng số mức cố định
  late ValueNotifier<bool> isSpeaking;
  bool _permissionsRequested = false; // Biến kiểm soát yêu cầu quyền

  @override
  void initState() {
    super.initState();
    behaviorAnalyzer = BehaviorAnalyzer();
    _timer = _QuizTimer();

    _pageController = PageController();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    isSpeaking = ValueNotifier(false);

    _initializeTts();
    _loadLongestQuestion();
    _initializeProgress(); // Khởi tạo tiến trình
    _initializeRace(); // Khởi tạo đua với AI
  }

  @override
  void dispose() {
    _pageController.dispose();
    _confettiController.dispose();
    flutterTts.stop();
    progression.saveProgress(); // Lưu tiến trình khi thoát
    isSpeaking.dispose();

    super.dispose();
  }

  void _initializeRace() {
    myPlayerId = 'player_1';
    playersPositions[myPlayerId!] = 0.0; // Vị trí ban đầu là 0.0
    playersPositions['ai_1'] = 0.0;
    playersPositions['ai_2'] = 0.0;
  }

  void _updateAIPositions(double currentAnswerTime) {
    double currentPosition = playersPositions[myPlayerId!]!;
    const double maxPosition = 1.0;

    // Tính tốc độ AI dựa trên thời gian trả lời của người chơi
    double baseAISpeed = 0.04; // Tốc độ cơ bản (4% mỗi lần)
    double speedMultiplier =
        currentAnswerTime > 5.0 ? 1.5 : 1.0; // Tăng tốc nếu trả lời > 5 giây
    double aiSpeedAdjustment = (currentAnswerTime / 10.0)
        .clamp(0.5, 2.0); // Điều chỉnh dựa trên thời gian

    playersPositions.forEach((key, value) {
      if (key.startsWith('ai_')) {
        double aiSpeed = baseAISpeed *
            (key == 'ai_1' ? 1.5 : 1.0) *
            speedMultiplier *
            aiSpeedAdjustment;
        double newPosition = value + aiSpeed;
        playersPositions[key] =
            newPosition > maxPosition ? maxPosition : newPosition;

        if (newPosition > currentPosition &&
            value <= currentPosition &&
            !_isSpeaking) {
          _speak("Ta vượt ngươi rồi, cố lên nào!");
        }
        if (newPosition >= maxPosition) {
          _endRaceWithAIWinner(key);
          return;
        }
      }
    });

    setState(() {});
    previousAnswerTime = currentAnswerTime;
  }

  void _speak(String message) async {
    if (!_isSpeaking) {
      setState(() => _isSpeaking = true);
      await flutterTts.speak(message);
      setState(() => _isSpeaking = false); // Reset sau khi nói xong
    }
  }

  void _endRaceWithAIWinner(String aiId) {
    if (!mounted) return;
    _speak("Ta là kẻ chiến thắng! Ngươi thua rồi!");
    _showQuestionResult(winner: aiId);
  }

  void _showQuestionResult({String? winner}) {
    if (!mounted) return;
    bool playerWins =
        winner == null && playersPositions[myPlayerId!]! >= maxLevel;
    if (playerWins || score >= (model?.questions.length ?? 0) / 2) {
      _confettiController.play();
    }
    showDialog(
      context: context,
      builder: (_) => _FinalResultDialog(
        score: score,
        total: model?.questions.length ?? 0,
        level: progression.level,
        xp: progression.xp,
        coins: progression.coins,
        playersPositions: playersPositions
            .map((key, value) => MapEntry(key, value.toDouble())),
        myPlayerId: myPlayerId!,
        isMultiplayer: false,
        winner: playerWins ? myPlayerId : winner,
        onClose: () async {
          await model?.saveScoreToFirestore(score);
          await progression.saveProgress();
          if (mounted) Navigator.pop(context);
        },
      ),
    ).catchError((e) {});
  }

  Future<void> _initializeProgress() async {
    await progression.loadProgress();
    if (!_permissionsRequested) {
      _permissionsRequested = true;
      bool granted = await DirHelper.requestStoragePermission();
      if (!granted) {
        print('NAMNM Running with limited storage access');
      }
    }
    setState(() {});
  }

  Future<void> _setVietnameseVoice() async {
    if (model != null) {
      await flutterTts.setLanguage(
          model!.ngonNgu.text.isNotEmpty ? model!.ngonNgu.text : 'vi-VN');
    }
  }

  Future<void> _initializeQuiz() async {
    if (model == null) return; // Bảo vệ khi model chưa sẵn sàng
    setState(() => _isLoading = true);
    final age = model!.age;
    if (model!.friendGame == false) {
      if (age == '10') {
        await model!.generateQuestionsUnder10();
      } else if (age == '17') {
        await model!.generateQuestions10to18();
      } else {
        await model!.generateQuestionsOver18();
      }
    }
    model!.friendGame == false;
    setState(() {
      _shuffledOptions = model!.questions
          .asMap()
          .map((i, q) => MapEntry(i, model!.shuffleAnswers(q, i)))
          .values
          .toList();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (m) async {
        model = m;
        await _setVietnameseVoice(); // Gọi sau khi model sẵn sàng
        await _initializeQuiz();
      },
      builder: (context, _, __) => Scaffold(
        appBar: HomeAppBar(
            title: _isLoading || _shuffledOptions == null
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.amber[300]!,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            colors: [Colors.amber[300]!, Colors.white],
                            stops: const [0.0, 0.5],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'Đang tải dữ liệu...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [Colors.amber[300]!, Colors.white],
                        stops: const [0.0, 0.7],
                      ).createShader(bounds);
                    },
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Câu hỏi ${_currentQuestionIndex + 1}/${model!.questions.length ?? 0}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${model!.topicController.text} - ${model!.subjectController.text}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white!, Colors.blue[700]!],
            ),
          ),
          child: _isLoading || _shuffledOptions == null || model == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    _LifelineBar(
                      onFiftyFifty: () =>
                          _handleLifeline(LifelineType.fiftyFifty),
                      onPhone: () => _handleLifeline(LifelineType.phone),
                      onAudience: () => _handleLifeline(LifelineType.audience),
                      onHint: () => _handleLifeline(LifelineType.hint),
                      scaffoldContext: context, // Truyền context từ Scaffold
                    ),
                    LinearProgressIndicator(
                        value: (_currentQuestionIndex + 1) /
                            model!.questions.length),
                    Container(
                      height: 60,
                      child: ClipRect(
                        child: Stack(
                          children: playersPositions.entries.map((entry) {
                            return AnimatedPositioned(
                              duration: const Duration(milliseconds: 500),
                              left: (MediaQuery.of(context).size.width *
                                      entry.value *
                                      0.9)
                                  .clamp(0,
                                      MediaQuery.of(context).size.width - 60),
                              child: Lottie.asset(
                                entry.key == myPlayerId
                                    ? 'assets/lottie/user.json'
                                    : 'assets/lottie/aiNemo.json',
                                width: 60,
                                height: 60,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: selectedAnswers[_currentQuestionIndex] != null
                            ? const AlwaysScrollableScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        onPageChanged: _handlePageChange,
                        itemCount: model!.questions.length,
                        itemBuilder: (_, index) => _QuestionCard(
                          question: model!.questions[index],
                          options: _shuffledOptions![index],
                          selectedAnswer: selectedAnswers[index],
                          onAnswerSelected: (answer) =>
                              setState(() => selectedAnswers[index] = answer),
                        ),
                      ),
                    ),
                    _NavigationButtons(
                      currentIndex: _currentQuestionIndex,
                      totalQuestions: model!.questions.length,
                      onPrevious: () => _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut),
                      onNext: _handleNext,
                      onStop: _showQuestionResult,
                    ),
                  ],
                ),
        ),
        floatingActionButton: _isLoading || _shuffledOptions == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(bottom: 50.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _CustomFAB(
                      icon: 'assets/lottie/share.json',
                      tooltip: 'Chia sẻ bài thi',
                      onPressed: _showInviteDialog,
                      heroTag: 'share_fab', // Tag riêng cho nút Chia sẻ
                    ),
                    const SizedBox(height: 16),
                    _CustomFAB(
                      icon: 'assets/lottie/speaker.json',
                      tooltip: 'Đọc câu hỏi',
                      onPressed: _readCurrentQuestion,
                      heroTag: 'speaker_fab', // Tag riêng cho nút Đọc
                    ),
                    const SizedBox(height: 16),
                    _CustomFAB(
                      icon: 'assets/lottie/card.json',
                      tooltip: 'Thẻ bài',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                RewardInventoryScreen(progression: progression),
                          ),
                        );
                      },
                      heroTag: 'card', // Tag riêng cho nút Túi mù
                    ),
                  ],
                ),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Future<void> _saveQuizData(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final question = model!.questions[index];
    final Map<String, dynamic> data = {};

    // Thu thập dữ liệu sai
    if (selectedAnswers[index] != question.answer) {
      data['incorrect'] = {
        'question': question.question,
        'selected': selectedAnswers[index],
        'correct': question.answer,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    // Thu thập dữ liệu câu hỏi lâu nhất
    final duration = _timer.getTime(index);
    if (duration > Duration.zero) {
      data['longest'] = {
        'question': question.question,
        'duration': duration.inMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    // Ghi một lần
    if (data.isNotEmpty) {
      await prefs.setString('quizData', jsonEncode(data));
    }
  }

  void _handlePageChange(int index) {
    if (selectedAnswers[_currentQuestionIndex] != null) {
      setState(() {
        _currentQuestionIndex = index;
        model!.point = index;
      });
    } else {
      _pageController.animateToPage(_currentQuestionIndex,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  Future<void> _loadLongestQuestion() async {
    final prefs = await SharedPreferences.getInstance();
    final longestJson = prefs.getString('quizData');
    if (longestJson != null) {
      final longest = jsonDecode(longestJson);
      if (longest.length >= 3) {
        longest.removeAt(0); // Xóa câu sai cũ nhất
      }
      model!.userHistory = longestJson.toString(); // Cập nhật vào model
      await prefs.setStringList(
          'quizData', longestJson.toString() as List<String>);
      print(
          'NAMNM Câu hỏi lâu nhất: ${longest['question']} - ${longest['duration']} giây');
    }
  }

  void _handleNext() async {
    if (selectedAnswers[_currentQuestionIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đáp án trước!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      _timer.end(_currentQuestionIndex); // Kết thúc và tính thời gian
      final isCorrect = selectedAnswers[_currentQuestionIndex] ==
          model!.questions[_currentQuestionIndex].answer;
      double currentPosition = playersPositions[myPlayerId!]!;
      const double maxPosition = 1.0;
      const int totalQuestions = 15;
      const double positionPerLevel = maxPosition / totalQuestions;

      // Cập nhật vị trí người chơi
      if (isCorrect) {
        double newPosition = currentPosition + positionPerLevel;
        playersPositions[myPlayerId!] =
            newPosition > maxPosition ? maxPosition : newPosition;
      } else if (currentPosition > 0) {
        double newPosition = currentPosition - positionPerLevel;
        playersPositions[myPlayerId!] = newPosition < 0.0 ? 0.0 : newPosition;
      }

      // Lấy thời gian trả lời
      double currentAnswerTime =
          _timer.getTime(_currentQuestionIndex).inMilliseconds / 1000.0;
      print(
          'NAMNM: Thời gian trả lời câu $_currentQuestionIndex: $currentAnswerTime giây');
      final learningStyle =
          behaviorAnalyzer.inferLearningStyle(); // Sử dụng phân tích hành vi
      model!.userLearningStyle = learningStyle; // Cập nhật vào model
      // Cập nhật vị trí AI
      _updateAIPositions(currentAnswerTime);

      // Kiểm tra nếu người chơi thắng
      if (playersPositions[myPlayerId!]! >= maxPosition) {
        print('NAMNM: Người chơi đã thắng!');
        if (!_isSpeaking) {
          setState(() => _isSpeaking = true);
          await flutterTts.speak("Bạn đã chiến thắng! Tuyệt vời!");
          setState(() => _isSpeaking = false);
        }
        _showQuestionResult(winner: myPlayerId);
        return;
      }

      // Kiểm tra nếu AI thắng (đặt sau _updateAIPositions)
      playersPositions.forEach((key, value) {
        if (key.startsWith('ai_') && value >= maxPosition) {
          _endRaceWithAIWinner(key);
          return;
        }
      });
      await _saveQuizData(_currentQuestionIndex);

      SoundUtils.playSound(isCorrect ? Sounds.correct : Sounds.incorrect);
      await flutterTts.stop();
      await flutterTts.speak(isCorrect ? "Chính xác!" : "Sai rồi!");
      await Future.delayed(const Duration(seconds: 1));
      await flutterTts.speak(
          "Đáp án đúng là: ${model!.questions[_currentQuestionIndex].answer}");

      Map<String, int>? bagReward;
      if (isCorrect) {
        score++;
        progression.addXp(1);
        try {
          await progression.openBlindBag(
            qualityBoost: 1,
            context: context,
          );
          if (progression.cards.isEmpty) {
            print('NAMNM No cards available after opening blind bag');
            return;
          }
          final newCard = progression.cards.last;
          if (mounted) {
            await showDialog(
              context: context,
              builder: (_) => CardRewardDialog(card: newCard),
            );
          } else {
            print('NAMNM Widget unmounted, cannot show dialog');
          }
        } catch (e) {
          print('NAMNM Failed to open blind bag or show dialog: $e');
        }
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _ResultDialog(
            isCorrect: isCorrect,
            explanation: model!.questions[_currentQuestionIndex].explanation,
            correctAnswer: model!.questions[_currentQuestionIndex].answer,
            learningTip: model!.questions[_currentQuestionIndex].learningTip,
            levelUpMessage: progression.xp >=
                    ProgressionEngine.xpPerLevel * progression.level
                ? 'Chúc mừng! Bạn đã lên cấp ${progression.level + 1}'
                : null,
            bagReward: bagReward,
            onNext: () {
              Navigator.of(context).pop();
              setState(() {
                if (_currentQuestionIndex < model!.questions.length - 1) {
                  _currentQuestionIndex++;
                  _timer.start(_currentQuestionIndex); // Bắt đầu câu tiếp theo
                  _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut);
                  if (_currentQuestionIndex == 4 ||
                      _currentQuestionIndex == 7 ||
                      _currentQuestionIndex == 11) {
                    _showQuangCao(_currentQuestionIndex);
                  }
                } else {
                  print('NAMNM: Hoàn thành quiz, gọi _showQuestionResult');
                  _showQuestionResult();
                }
              });
            },
          ),
        );
      }
    } catch (e) {
      print('NAMNM: Lỗi trong _handleNext: $e');
      if (mounted) _showQuestionResult();
    }
  }

  void _showQuangCao(int score) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor:
              Colors.transparent, // Nền trong suốt để gradient nổi bật
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black87, Colors.grey[900]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.amber.withOpacity(0.7), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon ngôi sao với hiệu ứng lấp lánh
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.amber.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star,
                        color: Colors.amber,
                        size: 64,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Thành tích với progress bar
                  Text(
                    'Chúc mừng!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(color: Colors.amber, blurRadius: 8),
                      ],
                      fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Bạn đã hoàn thành $score/${model!.questions.length} câu hỏi',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.grey[800],
                          ),
                          child: FractionallySizedBox(
                            widthFactor: score / model!.questions.length,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.amber, Colors.orangeAccent],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Ủng hộ tác giả
                  Text(
                    '❤️ Ủng hộ tác giả một ly cafe',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                      shadows: [
                        Shadow(
                            color: Colors.blueAccent.withOpacity(0.5),
                            blurRadius: 4),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Để có thêm động lực phát triển ứng dụng tốt hơn',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blueAccent),
                    ),
                    child: Column(
                      children: const [
                        Text(
                          'NGUYEN MINH NAM',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '0011004120000',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Vietcombank',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                          const ClipboardData(text: "0011004120000"));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Đã sao chép số tài khoản'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, color: Colors.white),
                    label: const Text(
                      'Sao chép STK',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                      shadowColor: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mời đăng ký Premium
                  Text(
                    '✨ Mở khóa gói Premium!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      shadows: [
                        Shadow(
                            color: Colors.greenAccent.withOpacity(0.5),
                            blurRadius: 4),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    'Không quảng cáo, toàn bộ tính năng!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(context, Routes.subcription);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                          shadowColor: Colors.greenAccent.withOpacity(0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_open,
                                color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: const Text(
                          'Tiếp tục',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.amber, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final List<String> emailList = []; // Đổi thành List<String>
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [Colors.purple[900]!, Colors.blue[900]!]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_add, color: Colors.amber, size: 48),
                    const SizedBox(height: 16),
                    const Text('Thử thách bạn bè!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Text(
                      'Môn học: ${model!.topicController.text}\nChủ đề: ${model!.subjectController.text}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Nhập email bạn bè',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.5)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, color: Colors.amber),
                          onPressed: () {
                            final email = emailController.text.trim();
                            if (email.isNotEmpty &&
                                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(email) &&
                                !emailList.contains(email) &&
                                emailList.length < 5) {
                              setState(() {
                                emailList.add(email);
                                emailController.clear();
                              });
                            } else if (emailList.length >= 5) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Tối đa 5 bạn bè'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.red),
                              );
                            }
                          },
                        ),
                      ),
                      validator: (value) => emailList.isEmpty
                          ? 'Vui lòng thêm ít nhất một email'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Hiển thị danh sách email đã thêm
                    Wrap(
                      spacing: 8,
                      children: emailList
                          .map((email) => Chip(
                                label: Text(email,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: Colors.amber.withOpacity(0.8),
                                deleteIcon: const Icon(Icons.close,
                                    size: 18, color: Colors.white),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Hủy',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8))),
                        ),
                        ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.send),
                          label: Text(isLoading ? 'Đang gửi...' : 'Gửi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (formKey.currentState!.validate()) {
                                    setState(() => isLoading = true);
                                    try {
                                      await model?.saveQuizToFriend(
                                          model!.questions, emailList);
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Đã gửi thành công!'),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content: Text('Lỗi: $e'),
                                            behavior: SnackBarBehavior.floating,
                                            backgroundColor: Colors.red),
                                      );
                                    } finally {
                                      setState(() => isLoading = false);
                                    }
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLifeline(LifelineType type) {
    behaviorAnalyzer.recordLifelineUsage(); // Ghi nhận hành vi

    switch (type) {
      case LifelineType.fiftyFifty:
        handleFiftyFifty();
        break;
      case LifelineType.phone:
        _showPhoneFriend();
        break;
      case LifelineType.audience:
        _showAudiencePoll();
        break;
      case LifelineType.hint:
        _showHint();
        break;
    }
  }

  Future<void> _initializeTts() async {
    await flutterTts.setLanguage('vi-VN');
    flutterTts.setCompletionHandler(() => isSpeaking.value = false);
    flutterTts.setErrorHandler((msg) {
      isSpeaking.value = false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi TTS: $msg'),
        behavior: SnackBarBehavior.floating,
      ));
    });
  }

  Future<void> _readCurrentQuestion() async {
    if (_isSpeaking) {
      await flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    setState(() => _isSpeaking = true);
    final question = model!.questions[_currentQuestionIndex].question;
    final options = _shuffledOptions![_currentQuestionIndex]
        .asMap()
        .map((i, opt) =>
            MapEntry(i, "Đáp án ${String.fromCharCode(65 + i)}: $opt"))
        .values
        .join(". ");
    final fullText = "Câu hỏi: $question. $options";
    await flutterTts.speak(fullText);
    setState(() => _isSpeaking = false);
  }

  void handleFiftyFifty() {
    SoundUtils.playSound(Sounds.fiftyFifty);

    final question = model!.questions[_currentQuestionIndex];
    final options = _shuffledOptions![_currentQuestionIndex];
    final incorrect = options.where((opt) => opt != question.answer).toList()
      ..shuffle();
    setState(() => _shuffledOptions![_currentQuestionIndex] = options
        .where((opt) => opt == question.answer || opt == incorrect.first)
        .toList());
  }

  void _showPhoneFriend() {
    final correctAnswer = model!.questions[_currentQuestionIndex].answer;
    SoundUtils.playSound(Sounds.audiencePhone);

    showDialog(
      context: context,
      builder: (_) => PhoneFriendDialog(correctAnswer: correctAnswer),
    ).then((_) async {
      await flutterTts.stop();
      await flutterTts.speak("Đáp án: $correctAnswer");
    });
  }

  void _showHint() {
    final hint =
        model!.questions[_currentQuestionIndex].hints ?? "Không có gợi ý";
    SoundUtils.playSound(Sounds.question);
    showDialog(
      context: context,
      builder: (_) => HintDialog(hint: hint),
    ).then((_) async {
      await flutterTts.stop();
      await flutterTts.speak("Gợi ý là: $hint");
    });
  }

  void _showAudiencePoll() {
    final random = Random();
    final correctAnswer = model!.questions[_currentQuestionIndex].answer;
    Map<String, int> pollResults = {};
    SoundUtils.playSound(Sounds.audiencePhone);

    int remainingPercent = 100;
    _shuffledOptions![_currentQuestionIndex].forEach((option) {
      if (option == correctAnswer) {
        pollResults[option] = 40 + random.nextInt(30); // 40-70%
        remainingPercent -= pollResults[option]!;
      }
    });

    _shuffledOptions![_currentQuestionIndex]
        .where((option) => option != correctAnswer)
        .forEach((option) {
      if (remainingPercent > 0) {
        int percent = option == _shuffledOptions![_currentQuestionIndex].last
            ? remainingPercent
            : random.nextInt(remainingPercent);
        pollResults[option] = percent;
        remainingPercent -= percent;
      } else {
        pollResults[option] = 0;
      }
    });

    showDialog(
      context: context,
      builder: (_) => AudiencePollDialog(pollResults: pollResults),
    );
  }
}

// Thêm lớp phân tích hành vi
class BehaviorAnalyzer {
  int ttsUsage = 0; // Số lần dùng TTS
  int lifelineUsage = 0; // Số lần dùng lifeline
  int questionRevisits = 0; // Số lần xem lại câu hỏi

  void recordTTSUsage() => ttsUsage++;
  void recordLifelineUsage() => lifelineUsage++;
  void recordQuestionRevisit() => questionRevisits++;

  String inferLearningStyle() {
    // Logic đơn giản dựa trên hành vi
    if (ttsUsage > lifelineUsage && ttsUsage > questionRevisits) {
      return 'auditory'; // Ưa thích âm thanh
    } else if (lifelineUsage > ttsUsage && lifelineUsage > questionRevisits) {
      return 'visual'; // Ưa thích hình ảnh/support
    } else if (questionRevisits > ttsUsage &&
        questionRevisits > lifelineUsage) {
      return 'kinesthetic'; // Thích tương tác/chuyển động
    }
    return 'balanced'; // Cân bằng nếu không rõ ràng
  }
} // Enum cho lifeline

enum LifelineType { fiftyFifty, phone, audience, hint }

class _LifelineBar extends StatefulWidget {
  final VoidCallback onFiftyFifty;
  final VoidCallback onPhone;
  final VoidCallback onAudience;
  final VoidCallback onHint;
  final BuildContext scaffoldContext; // Thêm context từ Scaffold cha

  const _LifelineBar({
    required this.onFiftyFifty,
    required this.onPhone,
    required this.onAudience,
    required this.onHint,
    required this.scaffoldContext,
  });

  @override
  _LifelineBarState createState() => _LifelineBarState();
}

class _LifelineBarState extends State<_LifelineBar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  final Map<LifelineType, bool> _used = {
    for (var type in LifelineType.values) type: false
  };
  late ProgressionEngine progression;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    progression = ProgressionEngine(); // Giả lập, thay bằng thực tế trong app
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useLifeline(LifelineType type, VoidCallback callback) {
    if (!_used[type]!) {
      setState(() {
        _used[type] = true;
      });
      callback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[900]!, Colors.blue[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.amber.withOpacity(0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _LifelineButton(
                type: LifelineType.fiftyFifty,
                icon: 'assets/joker/1.png',
                label: '50:50',
                isUsed: _used[LifelineType.fiftyFifty]!,
                animation: _controller,
                onTap: () =>
                    _useLifeline(LifelineType.fiftyFifty, widget.onFiftyFifty),
              ),
              _LifelineButton(
                type: LifelineType.phone,
                icon: 'assets/joker/3.png',
                label: 'Gọi bạn',
                isUsed: _used[LifelineType.phone]!,
                animation: _controller,
                onTap: () => _useLifeline(LifelineType.phone, widget.onPhone),
              ),
              _LifelineButton(
                type: LifelineType.audience,
                icon: 'assets/joker/2.png',
                label: 'Khán giả',
                isUsed: _used[LifelineType.audience]!,
                animation: _controller,
                onTap: () =>
                    _useLifeline(LifelineType.audience, widget.onAudience),
              ),
              _LifelineButton(
                type: LifelineType.hint,
                icon: 'assets/lottie/Animation1.json',
                label: 'Gợi ý',
                isUsed: _used[LifelineType.hint]!,
                animation: _controller,
                onTap: () => _useLifeline(LifelineType.hint, widget.onHint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LifelineButton extends StatelessWidget {
  final LifelineType type;
  final String icon;
  final String label;
  final bool isUsed;
  final AnimationController animation;
  final VoidCallback onTap;

  const _LifelineButton({
    required this.type,
    required this.icon,
    required this.label,
    required this.isUsed,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) => GestureDetector(
        onTap: isUsed ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isUsed
                      ? [Colors.red[900]!, Colors.red[700]!]
                      : [Colors.green[800]!, Colors.green[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isUsed
                        ? Colors.red.withOpacity(0.5)
                        : Colors.green.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(
                  color: isUsed ? Colors.red : Colors.amber,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  type == LifelineType.hint
                      ? Lottie.asset(
                          icon,
                          width: 60,
                          height: 40,
                          fit: BoxFit.cover,
                          repeat: !isUsed,
                        )
                      : Image.asset(
                          icon,
                          width: 60,
                          height: 40,
                          color: isUsed ? Colors.grey : null,
                        ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUsed ? Colors.grey : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                      shadows: [
                        Shadow(
                          color: isUsed ? Colors.red : Colors.amber,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isUsed)
              AnimatedScale(
                scale: animation.value,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.amber.withOpacity(0.3),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ),
            if (isUsed)
              Transform.rotate(
                angle: -45 * (3.1415926535 / 180),
                child: Container(
                  width: 70,
                  height: 4,
                  color: Colors.red.withOpacity(0.8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget câu hỏi
class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final List<String> options;
  final String? selectedAnswer;
  final ValueChanged<String> onAnswerSelected;

  const _QuestionCard({
    required this.question,
    required this.options,
    this.selectedAnswer,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildQuestionText(context, question.question),
            ),
          ),
          const SizedBox(height: 20),
          ...options.asMap().entries.map((e) => _OptionTile(
                option: e.value,
                letter: String.fromCharCode(65 + e.key),
                isSelected: selectedAnswer == e.value,
                onTap: () => onAnswerSelected(e.value),
                buildText: _buildQuestionText, // Truyền hàm như callback
              )),
        ],
      ),
    );
  }

  Widget _buildQuestionText(BuildContext context, String text) {
    final latexRegex =
        RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]|(\$[^\$]*\$)|(\$\$[^\$]*\$\$)');
    if (!latexRegex.hasMatch(text)) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 18,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      );
    }

    final matches = latexRegex.allMatches(text);
    List<InlineSpan> spans = [];
    int currentIndex = 0;

    for (final match in matches) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      final latex = match.group(1) ??
          match.group(2) ??
          match.group(3)!.substring(1, match.group(3)!.length - 1);
      spans.add(WidgetSpan(
        child: Math.tex(
          latex,
          textStyle: TextStyle(
            fontSize: 18,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
          ),
        ),
      ));
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: TextStyle(
          fontSize: 18,
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black,
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String option;
  final String letter;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget Function(BuildContext, String) buildText;

  const _OptionTile({
    required this.option,
    required this.letter,
    required this.isSelected,
    required this.onTap,
    required this.buildText,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.green.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? Colors.green : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Center(
                child: Text(
                  letter,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
                child: buildText(context, option)), // Sử dụng hàm truyền vào
          ],
        ),
      ),
    );
  }
}

// Widget nút điều hướng
class _NavigationButtons extends StatelessWidget {
  final int currentIndex;
  final int totalQuestions;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onStop;

  const _NavigationButtons({
    required this.currentIndex,
    required this.totalQuestions,
    required this.onPrevious,
    required this.onNext,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentIndex > 0)
            ElevatedButton(
              onPressed: onPrevious,
              child: Lottie.asset('assets/lottie/back.json',
                  width: 50, height: 50, fit: BoxFit.contain),
            ),
          ElevatedButton(
            onPressed: onStop,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Lottie.asset('assets/lottie/stop.json',
                width: 50, height: 50, fit: BoxFit.contain),
          ),
          ElevatedButton(
            onPressed: onNext,
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
            child: Lottie.asset(
              currentIndex == totalQuestions - 1
                  ? 'assets/lottie/complete.json'
                  : 'assets/lottie/next.json',
              width: 50,
              height: 50,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget dialog kết quả câu hỏi
class _ResultDialog extends StatefulWidget {
  final bool isCorrect;
  final String? explanation;
  final String correctAnswer;
  final VoidCallback onNext;
  final String? learningTip;
  final String? levelUpMessage;
  final Map<String, int>? bagReward;

  const _ResultDialog({
    required this.isCorrect,
    required this.explanation,
    required this.correctAnswer,
    required this.onNext,
    required this.learningTip,
    this.levelUpMessage,
    this.bagReward,
  });

  @override
  _ResultDialogState createState() => _ResultDialogState();
}

class _ResultDialogState extends State<_ResultDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ConfettiController _confettiController;
  bool _showReward = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    if (widget.isCorrect) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();

    super.dispose();
  }

  void _openBag() {
    setState(() {
      _showReward = true;
    });
    _confettiController.play();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        elevation: 10,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height *
                    0.7, // Giới hạn 70% chiều cao màn hình
                maxWidth: MediaQuery.of(context).size.width *
                    0.9, // Giới hạn 90% chiều ngang
              ),
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.only(top: 40), // Chừa chỗ cho animation
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isCorrect
                      ? [Colors.green[900]!, Colors.green[300]!]
                      : [Colors.red[900]!, Colors.red[300]!],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                // Thêm cuộn cho toàn bộ nội dung
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isCorrect ? 'Chiến Thắng!' : 'Thử Lại Nhé!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.levelUpMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.levelUpMessage!,
                          style: const TextStyle(
                              fontSize: 16, color: Colors.yellowAccent),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.bagReward != null && widget.isCorrect) ...[
                      _showReward
                          ? Column(
                              children: [
                                Text(
                                  "Phần thưởng: ${widget.bagReward!.keys.first} x${widget.bagReward!.values.first}",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Lottie.asset(
                                  'assets/lottie/bagde.json',
                                  width: 120,
                                  height: 120,
                                  repeat: false,
                                ),
                              ],
                            )
                          : ElevatedButton.icon(
                              onPressed: _openBag,
                              icon: const Icon(Icons.card_giftcard,
                                  color: Colors.white),
                              label: const Text('Mở Túi Mù',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber[700],
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                              ),
                            ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.explanation != null)
                      Container(
                        width: double.infinity, // Đảm bảo chiếm hết chiều ngang
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.explanation!,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      'Mẹo: ${widget.learningTip ?? "Không có mẹo"}',
                      style:
                          const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Đáp án đúng: ${widget.correctAnswer}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: widget.onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.isCorrect
                            ? Colors.green[700]
                            : Colors.red[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.isCorrect
                                ? Icons.arrow_forward
                                : Icons.refresh,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isCorrect ? 'Tiếp Tục' : 'Chơi Lại',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -40,
              child: Lottie.asset(
                widget.isCorrect
                    ? 'assets/lottie/win.json'
                    : 'assets/lottie/lose.json',
                width: 100,
                height: 100,
                repeat: false,
              ),
            ),
            if (widget.isCorrect)
              Positioned(
                top: -50,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.yellow,
                    Colors.blue,
                    Colors.pink
                  ],
                  numberOfParticles: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget dialog kết quả cuối
class _FinalResultDialog extends StatefulWidget {
  final int score;
  final int total;
  final int level;
  final int xp;
  final int coins;
  final Map<String, double> playersPositions;
  final String myPlayerId;
  final bool isMultiplayer;
  final String? winner; // Thêm tham số winner (null nếu chưa kết thúc đua)
  final VoidCallback onClose;

  const _FinalResultDialog({
    required this.score,
    required this.total,
    required this.level,
    required this.xp,
    required this.coins,
    required this.playersPositions,
    required this.myPlayerId,
    required this.isMultiplayer,
    this.winner, // Tham số mới
    required this.onClose,
  });

  @override
  _FinalResultDialogState createState() => _FinalResultDialogState();
}

class _FinalResultDialogState extends State<_FinalResultDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late ConfettiController _confettiController;
  final Random _random = Random();

  // Danh sách câu thoại cho AI khi thắng
  final List<String> aiWinQuotes = [
    "Ha ha, ta là vua đường đua! Ngươi cần luyện tập thêm đi!",
    "Tốc độ của ta không ai sánh bằng, cố lên lần sau nhé!",
    "Ngươi nghĩ có thể vượt qua trí tuệ AI sao? Ta thắng rồi!",
    "Đường đua này là của ta, ngươi chỉ là kẻ học việc thôi!",
  ];

  // Danh sách câu thoại cho AI khi thua
  final List<String> aiLoseQuotes = [
    "Chúc mừng, ngươi thắng lần này! Nhưng ta sẽ quay lại mạnh mẽ hơn!",
    "Hừ, ngươi may mắn thôi. Lần sau ta sẽ không thua đâu!",
    "Ta đã bị đánh bại... Ngươi thật sự giỏi đấy!",
    "Ồ, ta cần nâng cấp thuật toán của mình. Chúc mừng ngươi!",
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // Phát confetti nếu người chơi thắng hoặc điểm cao
    if (widget.winner == widget.myPlayerId ||
        widget.score >= widget.total / 2) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  String _getMotivationalMessage() {
    final percentage = widget.score / widget.total * 100;
    if (widget.winner == widget.myPlayerId) {
      return "Chiến thắng tuyệt đối! Bạn là nhà vô địch! 🏆";
    }
    if (percentage == 100) return "Hoàn hảo! Bạn là bậc thầy! 🌟";
    if (percentage >= 80) return "Xuất sắc! Tiếp tục phát huy nhé! 🎯";
    if (percentage >= 60) return "Tốt lắm! Bạn đang tiến bộ! 👍";
    if (percentage >= 50) return "Đạt rồi! Luyện thêm nhé! 💪";
    return "Đừng bỏ cuộc! Có công mài sắt, có ngày nên kim! 📚";
  }

  String _getAIQuote(String aiId) {
    // Nếu có winner, xác định câu thoại dựa trên winner
    if (widget.winner != null) {
      if (widget.winner == aiId) {
        return aiWinQuotes[_random.nextInt(aiWinQuotes.length)];
      } else if (widget.winner == widget.myPlayerId) {
        return aiLoseQuotes[_random.nextInt(aiLoseQuotes.length)];
      }
    }
    // Nếu chưa có winner, so sánh vị trí
    double playerPosition = widget.playersPositions[widget.myPlayerId]!;
    double aiPosition = widget.playersPositions[aiId]!;
    return aiPosition > playerPosition
        ? aiWinQuotes[_random.nextInt(aiWinQuotes.length)]
        : aiLoseQuotes[_random.nextInt(aiLoseQuotes.length)];
  }

  String _getWinnerAnnouncement() {
    if (widget.winner == widget.myPlayerId) {
      return "Bạn là người chiến thắng! 🎉";
    } else if (widget.winner != null && widget.winner!.startsWith('ai_')) {
      return "AI ${widget.winner!.substring(3)} đã thắng cuộc đua!";
    }
    return "Cuộc đua vẫn chưa phân thắng bại!";
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.only(top: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.purple[900]!,
                    Colors.blue[600]!,
                    Colors.cyan[400]!
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Kết Quả Đua Với AI',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.yellow),
                    ),
                    const SizedBox(height: 16),
                    // Hiển thị thông báo người thắng
                    if (widget.winner != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.winner == widget.myPlayerId
                              ? Colors.green.withOpacity(0.8)
                              : Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getWinnerAnnouncement(),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: Colors.white.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CircularPercentIndicator(
                              radius: 70,
                              lineWidth: 12,
                              percent: widget.score / widget.total,
                              center: Text(
                                '${(widget.score / widget.total * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                              progressColor: widget.score == widget.total
                                  ? Colors.green
                                  : (widget.score >= widget.total / 2
                                      ? Colors.orange
                                      : Colors.red),
                              backgroundColor:
                                  Colors.grey[800]!.withOpacity(0.3),
                              animation: true,
                              animationDuration: 1000,
                            ),
                            const SizedBox(height: 16),
                            Text('Điểm: ${widget.score}/${widget.total}',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            Text(
                                'Cấp độ: ${widget.level} - XP: ${widget.xp}/${ProgressionEngine.xpPerLevel * widget.level}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text('Coins: ${widget.coins}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      color: Colors.white.withOpacity(0.15),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text('Bảng Xếp Hạng',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                            const SizedBox(height: 8),
                            ...widget.playersPositions.entries
                                .map((entry) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            entry.key == widget.myPlayerId
                                                ? 'Bạn'
                                                : 'AI ${entry.key.substring(3)}',
                                            style: TextStyle(
                                                color: entry.key ==
                                                        widget.myPlayerId
                                                    ? Colors.yellow
                                                    : Colors.white,
                                                fontWeight:
                                                    entry.key == widget.winner
                                                        ? FontWeight.bold
                                                        : FontWeight.normal),
                                          ),
                                          Text(
                                              '${(entry.value * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                            const SizedBox(height: 8),
                            // Hiển thị câu thoại của AI
                            ...widget.playersPositions.entries
                                .where((entry) => entry.key.startsWith('ai_'))
                                .map((entry) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Text(
                                        '"${_getAIQuote(entry.key)}" - AI ${entry.key.substring(3)}',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                            fontStyle: FontStyle.italic),
                                        textAlign: TextAlign.center,
                                      ),
                                    ))
                                .toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(_getMotivationalMessage(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close, color: Colors.white),
                      label: const Text('Thoát',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -60,
              child: Lottie.asset('assets/lottie/aiNemo.json',
                  width: 120, height: 120, fit: BoxFit.cover, repeat: true),
            ),
            Positioned(
              top: -50,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.green,
                  Colors.yellow,
                  Colors.blue,
                  Colors.pink
                ],
                emissionFrequency: 0.05,
                numberOfParticles: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget phần thưởng (cải tiến)
class _RewardItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;

  const _RewardItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: value > 0 ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.amber[400],
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget nút FAB tùy chỉnh
class _CustomFAB extends StatelessWidget {
  final String icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String heroTag; // Thêm heroTag để phân biệt

  const _CustomFAB({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.heroTag, // Bắt buộc heroTag
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: Colors.amber,
      // Đảm bảo FAB có kích thước cố định và không vượt quá giới hạn
      mini: false, // Có thể đổi thành true nếu muốn FAB nhỏ hơn
      child: SizedBox(
        width: 40, // Giảm kích thước để vừa với FAB
        height: 40,
        child: Lottie.asset(
          icon,
          fit: BoxFit.contain,
          repeat: true, // Tùy chọn: lặp animation
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.error,
            color: Colors.white,
            size: 24,
          ), // Xử lý lỗi nếu file Lottie không tải được
        ),
      ),
    );
  }
}

class ProgressionEngine {
  int level = 1;
  int xp = 0;
  int coins = 0;
  static const int xpPerLevel = 20;
  List<Cards> cards = []; // Danh sách thẻ bài
  final BlindBag blindBag = BlindBag();

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    level = prefs.getInt('userLevel') ?? 1;
    xp = prefs.getInt('userXp') ?? 0;
    coins = prefs.getInt('coins') ?? 0;

    // Tải danh sách thẻ bài từ file JSON
    final directory = await DirHelper.getAppPath();
    final file = File('$directory/cards.json');
    cards.clear(); // Xóa danh sách cũ để tránh nhân đôi
    if (await file.exists()) {
      try {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        cards = jsonList.map((json) => Cards.fromJson(json)).toList();
        print('NAMNM: Loaded ${cards.length} cards from storage');
      } catch (e) {
        print('NAMNM: Error loading cards from JSON: $e');
        cards = []; // Reset nếu lỗi
      }
    }
  }

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userLevel', level);
    await prefs.setInt('userXp', xp);
    await prefs.setInt('coins', coins);

    // Lưu danh sách thẻ bài vào file JSON
    final directory = await DirHelper.getAppPath();
    final file = File('$directory/cards.json');
    try {
      // Xóa file cũ trước khi ghi để tránh dữ liệu chồng chéo
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);
      await file.writeAsString(
        jsonEncode(cards.map((card) => card.toJson()).toList()),
      );
      print('NAMNM: Saved ${cards.length} cards to storage');
    } catch (e) {
      print('NAMNM: Error saving cards to JSON: $e');
    }
  }

  void addXp(int points) {
    xp += points * 10;
    coins += points * 5; // Thêm phần thưởng coin khi kiếm XP
    while (xp >= xpPerLevel * level) {
      levelUp();
    }
    saveProgress(); // Lưu tiến trình ngay khi thêm XP
  }

  void levelUp() {
    level++;
    xp -= xpPerLevel * (level - 1);
    coins += level * 10; // Phần thưởng coin khi lên cấp
    print('NAMNM: Leveled up to $level! XP remaining: $xp, Coins: $coins');
    // openBlindBag(qualityBoost: level ~/ 5); // Mở blind bag khi lên cấp
  }

  Future<void> openBlindBag(
      {int qualityBoost = 0, required BuildContext context}) async {
    // Hiển thị dialog chờ với thông báo "Đợi chút, tôi đang rèn"
    bool isDialogOpen = true;
    late ConfettiController confettiController;
    if (context.mounted) {
      confettiController =
          ConfettiController(duration: const Duration(seconds: 2));
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange[900]!, Colors.red[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.amber.withOpacity(0.7), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 15,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie.asset(
                //   'assets/lottie/forge.json', // Giả lập animation "đang rèn"
                //   width: 100,
                //   height: 100,
                //   repeat: true,
                // ),
                // const SizedBox(height: 16),
                const Text(
                  'Đợi chút, tôi đang rèn...',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'FantasyFont',
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Thẻ bài sắp hoàn thiện!',
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    try {
      final newCard = await blindBag.openBag(qualityBoost: qualityBoost);
      if (!cards.any((card) => card.id == newCard.id)) {
        cards.add(newCard);
        await saveProgress();
        print('NAMNM: Added new card: ${newCard.name} (ID: ${newCard.id})');
        if (context.mounted && isDialogOpen) {
          Navigator.pop(context); // Đóng dialog chờ
          isDialogOpen = false;
          await showDialog(
            context: context,
            builder: (_) => Stack(
              alignment: Alignment.center,
              children: [
                CardRewardDialog(card: newCard),
                ConfettiWidget(
                  confettiController: confettiController..play(),
                  blastDirectionality: BlastDirectionality.explosive,
                  colors: const [
                    Colors.yellow,
                    Colors.red,
                    Colors.orange,
                    Colors.blue
                  ],
                  particleDrag: 0.05,
                  emissionFrequency: 0.02,
                  numberOfParticles: 20,
                ),
              ],
            ),
          );
        }
      } else {
        print('NAMNM: Card ${newCard.name} (ID: ${newCard.id}) already exists');
        coins += 10; // Phần thưởng thay thế nếu trùng
        await saveProgress();
        if (context.mounted && isDialogOpen) {
          Navigator.pop(context); // Đóng dialog chờ
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thẻ đã tồn tại! Nhận +10 Coins thay thế'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      print('NAMNM: Error opening blind bag: $e');
      if (context.mounted && isDialogOpen) {
        Navigator.pop(context); // Đóng dialog chờ nếu lỗi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi rèn thẻ: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      rethrow; // Ném lỗi để xử lý ngoài hàm nếu cần
    }
  }

  String getRewardMessage(Cards card) {
    final rarityText = card.rarity == 1
        ? 'Thường'
        : card.rarity == 2
            ? 'Hiếm'
            : 'Epic';
    return "Chúc mừng! Bạn nhận được thẻ bài: ${card.name} ($rarityText)\n+${card.rarity * 10} XP | +${card.rarity * 5} Coins!";
  }

  // Thêm thông tin tiến trình để hiển thị trong UI
  Map<String, dynamic> getProgressInfo() {
    return {
      'level': level,
      'xp': xp,
      'xpToNextLevel': xpPerLevel * level,
      'coins': coins,
      'cardCount': cards.length,
    };
  }
}

class BlindBag {
  final Random _random = Random();
  final Map<int, double> _rarityPool = {
    1: 0.6, // Thường
    2: 0.3, // Hiếm
    3: 0.1, // Epic
  };
  static const String _apiKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY'; // Thay bằng API key thực tế
  final _models = GenerativeModel(
    model:
        'gemini-2.0-flash-exp-image-generation', // Sử dụng gemini-1.5-flash (2.0-flash chưa tồn tại, cập nhật theo phiên bản thực tế)
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.35,
      topP: 0.95,
      maxOutputTokens: 10000,
      responseMimeType: 'application/json',
    ),
  );
  Future<Cards> openBag({int qualityBoost = 0}) async {
    double roll = _random.nextDouble() - qualityBoost * 0.01;
    double cumulative = 0.0;
    int rarity = 1;

    for (var entry in _rarityPool.entries) {
      cumulative += entry.value;
      if (roll <= cumulative) {
        rarity = entry.key;
        break;
      }
    }

    try {
      return await _generateCard(rarity);
    } catch (e) {
      print('NAMNM: Error generating card: $e');
      return Cards(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Thẻ Lỗi',
        description: 'Thẻ mặc định do lỗi tạo thẻ.',
        imagePath: '', // Có thể thay bằng đường dẫn mặc định nếu cần
        rarity: 1,
        type: 'Unknown',
        attack: 10,
        defense: 10,
        element: 'Thổ',
        effect: null,
      );
    }
  }

  Future<Cards> _generateCard(int rarity) async {
    final promptData = _generatePrompt(rarity);
    final name = promptData['name']! as String;
    final description = promptData['description']! as String;
    final type = promptData['type']! as String;
    final attack = promptData['attack']! as int;
    final defense = promptData['defense']! as int;
    final element = promptData['element']! as String;
    final effect = promptData['effect'] as String?;
    final imagePath = await _generateAndSaveImage(
        name, rarity, type, element, attack, defense);

    print(
        'NAMNM: Generated card - Name: $name, Attack: $attack, Defense: $defense, Element: $element, Type: $type');

    return Cards(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      imagePath: imagePath,
      rarity: rarity,
      type: type,
      attack: attack,
      defense: defense,
      element: element,
      effect: effect,
    );
  }

  Map<String, dynamic> _generatePrompt(int rarity) {
    // Các vai trò nhân vật lấy cảm hứng từ văn hóa Việt Nam
    final types = [
      'Thám Tử', // Người đi khám phá, tìm hiểu bí mật
      'Hộ Vệ', // Người bảo vệ làng xóm, đền chùa
      'Huyền Sư', // Thầy pháp, người sử dụng phép thuật
      'Lừa Sư', // Kẻ láu lỉnh, tinh quái
      'Ngự Thú', // Người thuần hóa thú dữ
      'Nguyên Sư', // Người điều khiển nguyên tố thiên nhiên
    ];

    // Nguyên tố dựa trên ngũ hành và yếu tố tự nhiên Việt Nam
    final elements = ['Kim', 'Mộc', 'Thủy', 'Hỏa', 'Thổ', 'Gió', 'Sấm'];

    // Tính từ phản ánh độ hiếm và phong cách Việt
    final adjectives = {
      1: ['Nhanh Nhẹn', 'Gan Dạ', 'Tinh Tế'], // Thường, dân dã
      2: ['Thiêng Liêng', 'Kỳ Bí', 'Lộng Lẫy'], // Hiếm, mang nét huyền thoại
      3: ['Truyền Kỳ', 'Vô Song', 'Thần Linh'], // Epic, mang tầm vóc sử thi
    };

    final type = types[_random.nextInt(types.length)];
    final element = elements[_random.nextInt(elements.length)];
    final adjective =
        adjectives[rarity]![_random.nextInt(adjectives[rarity]!.length)];

    Map<String, dynamic> promptData;

    // Câu chuyện và mô tả mang đậm chất Việt Nam
    switch (type) {
      case 'Thám Tử':
        promptData = {
          'name': '$adjective $element Thám',
          'description':
              'Một kẻ lang thang $adjective, dùng trí óc để khám phá bí ẩn trong rừng $element.',
          'type': type,
          'attack': rarity * 15 + _random.nextInt(25),
          'defense': rarity * 12 + _random.nextInt(20),
          'element': element,
          'effect': rarity > 1 ? 'Tăng 20% khả năng phát hiện bẫy' : null,
          'story':
              'Sinh ra bên dòng sông $element, họ đi khắp chốn tìm kho báu của tổ tiên.',
        };
        break;

      case 'Hộ Vệ':
        promptData = {
          'name': '$adjective $element Vệ',
          'description':
              'Người bảo vệ $adjective, giữ gìn đình làng trước sức mạnh của $element.',
          'type': type,
          'attack': rarity * 10 + _random.nextInt(20),
          'defense': rarity * 25 + _random.nextInt(30),
          'element': element,
          'effect': rarity > 1 ? 'Giảm 15% sát thương cho đồng đội' : null,
          'story':
              'Được tôi luyện từ đất $element, họ là lá chắn của quê hương.',
        };
        break;

      case 'Huyền Sư':
        promptData = {
          'name': '$adjective $element Sư',
          'description':
              'Thầy pháp $adjective, nắm giữ bí thuật $element từ thời cổ đại.',
          'type': type,
          'attack': rarity * 18 + _random.nextInt(25),
          'defense': rarity * 8 + _random.nextInt(15),
          'element': element,
          'effect': rarity > 2 ? 'Thi triển phép ngẫu nhiên mỗi lượt' : null,
          'story':
              'Dưới bóng cây đa $element, họ thì thầm lời tiên tri trong gió.',
        };
        break;

      case 'Lừa Sư':
        promptData = {
          'name': '$adjective $element Tặc',
          'description':
              'Kẻ tinh quái $adjective, dùng mưu mẹo và $element để qua mặt kẻ thù.',
          'type': type,
          'attack': rarity * 22 + _random.nextInt(30),
          'defense': rarity * 6 + _random.nextInt(12),
          'element': element,
          'effect': rarity > 1 ? 'Né 25% sát thương từ đòn trực diện' : null,
          'story':
              'Ẩn trong đồng lúa $element, họ đùa giỡn với số phận kẻ khác.',
        };
        break;

      case 'Ngự Thú':
        promptData = {
          'name': '$adjective $element Thú',
          'description':
              'Người thuần thú $adjective, điều khiển dã thú từ vùng $element.',
          'type': type,
          'attack': rarity * 12 + _random.nextInt(20),
          'defense': rarity * 15 + _random.nextInt(25),
          'element': element,
          'effect': rarity > 2 ? 'Gọi thú hỗ trợ gây 20% sát thương' : null,
          'story':
              'Giữa rừng sâu $element, họ kết bạn với những sinh vật hoang dã.',
        };
        break;

      case 'Nguyên Sư':
        promptData = {
          'name': '$adjective $element Nguyên',
          'description':
              'Bậc thầy $adjective, điều khiển sức mạnh nguyên tố $element từ trời đất.',
          'type': type,
          'attack': rarity * 20 + _random.nextInt(30),
          'defense': rarity * 10 + _random.nextInt(15),
          'element': element,
          'effect': rarity > 1 ? 'Tăng 20% sát thương hệ $element' : null,
          'story':
              'Từ ngọn núi $element, họ hòa mình vào dòng chảy của thiên nhiên.',
        };
        break;

      default:
        promptData = {
          'name': 'Hồn Bí Ẩn',
          'description': 'Một bóng hình chưa ai biết đến từ đất Việt cổ.',
          'type': 'Unknown',
          'attack': 10,
          'defense': 10,
          'element': 'Thổ',
          'effect': null,
          'story':
              'Không ai rõ họ đến từ đâu, chỉ biết họ lang thang giữa đồng lúa.',
        };
    }

    // Thêm chi tiết dựa trên độ hiếm, mang nét văn hóa Việt
    if (rarity == 3) {
      promptData['description'] +=
          ' Là nhân vật trong những bài ca dao lưu truyền ngàn đời.';
    } else if (rarity == 2) {
      promptData['description'] +=
          ' Hiếm ai gặp mặt, chỉ nghe qua lời kể bên bếp lửa.';
    }

    return promptData;
  }

  Future<String> _generateAndSaveImage(String name, int rarity, String type,
      String element, int attack, int defense) async {
    String directory = await DirHelper.getAppPath();
    String imagePath = '$directory/card_$name.png';
    final file = File(imagePath);

    try {
      final geminiResponse = await _models.generateContent([
        Content.text(
          'Generate an image of a fantasy $type card named "$name" with '
          '${rarity == 1 ? 'common' : rarity == 2 ? 'rare' : 'epic'} rarity. '
          'Describe its appearance and theme in detail (e.g., colors, symbols, background), '
          'then provide the image.'
          'Return the result in JSON format with "description" and "image" fields where "image" is a direct URL to the generated image.',
        ),
      ]);

      final responseText = geminiResponse.text ?? '{}';
      _logLargeString('NAMNM Gemini response', responseText);

      dynamic decodedResponse;
      try {
        decodedResponse = jsonDecode(responseText);
      } catch (e) {
        print('NAMNM JSON decode failed: $e');
        decodedResponse = {};
      }

      Map<String, dynamic> jsonResponse;
      if (decodedResponse is Map<String, dynamic>) {
        jsonResponse = decodedResponse;
      } else if (decodedResponse is List && decodedResponse.isNotEmpty) {
        jsonResponse = decodedResponse[0] as Map<String, dynamic>;
        print('NAMNM JSON is a list, using first element: $jsonResponse');
      } else {
        jsonResponse = {
          'description': 'Invalid response from Gemini',
          'image': null
        };
        print('NAMNM Unexpected JSON format: $decodedResponse');
      }

      // Ánh xạ các trường từ Gemini
      final description = jsonResponse['description'] as String? ??
          'A fantasy card with unique design.';
      String? imageUrl = jsonResponse['image'] as String?;

      // Nếu image không phải URL mà là prompt, gọi Pollinations AI
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        print(
            'NAMNM Image field is a prompt, generating URL with Pollinations AI');
        imageUrl =
            'https://image.pollinations.ai/prompt/${Uri.encodeComponent(imageUrl)}';
      }

      if (imageUrl != null && imageUrl.startsWith('http')) {
        print('NAMNM Downloading image from: $imageUrl');
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final contentType = response.headers['content-type'];
          print('NAMNM Content-Type: $contentType');
          if (contentType?.contains('image') == true) {
            final imageBytes = response.bodyBytes;
            if (!await file.exists()) {
              await file.create(recursive: true);
            }
            await file.writeAsBytes(imageBytes);
            print('NAMNM Saved image to: $imagePath');
          } else {
            print(
                'NAMNM URL did not return an image, Content-Type: $contentType');
          }
        } else {
          print(
              'NAMNM Failed to download image from URL: $imageUrl, Status: ${response.statusCode}');
        }
      } else {
        print('NAMNM No valid image URL provided');
      }
    } catch (e) {
      print('NAMNM: Error in _generateAndSaveImage: $e');
      // Tạo ảnh mặc định nếu lỗi
      imagePath = '$directory/adventure_map.png';
      if (!await file.exists()) {
        await file.create(recursive: true);
        // Giả lập ghi ảnh mặc định (thay bằng asset thực tế nếu có)
        await file.writeAsBytes(Uint8List(0));
      }
    }

    return imagePath;
  }

  void _logLargeString(String prefix, String text) {
    const int chunkSize = 1000; // Giới hạn mỗi đoạn log
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = i + chunkSize < text.length ? i + chunkSize : text.length;
      print('$prefix [${i ~/ chunkSize}]: ${text.substring(i, end)}');
    }
  }
}

class RewardInventoryScreen extends StatefulWidget {
  final ProgressionEngine progression;

  const RewardInventoryScreen({required this.progression, super.key});

  @override
  _RewardInventoryScreenState createState() => _RewardInventoryScreenState();
}

class _RewardInventoryScreenState extends State<RewardInventoryScreen>
    with SingleTickerProviderStateMixin {
  late List<Cards> cards;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _selectedRarityFilter = 0;
  int _currentCardIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    cards = widget.progression.cards;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> saveProgress() async {
    final prefs = await SharedPreferences.getInstance();

    final directory = await DirHelper.getAppPath();
    final file = File('$directory/cards.json');
    try {
      if (await file.exists()) {
        await file.delete();
      }
      await file.create(recursive: true);
      await file.writeAsString(
        jsonEncode(cards.map((card) => card.toJson()).toList()),
      );
      print('NAMNM: Saved ${cards.length} cards to storage');
    } catch (e) {
      print('NAMNM: Error saving cards to JSON: $e');
    }
  }

  void _startBattle() {
    if (cards.length >= 10) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CardBattleScreen(
            playerCards: cards,
            onBattleEnd: (resultCards, lostCards) {
              setState(() {
                // Remove lost cards
                for (var lostCard in lostCards) {
                  cards.removeWhere(
                      (card) => card.id == lostCard.id); // Match by unique ID
                }
                // Add Epic card if won
                if (resultCards.isNotEmpty) {
                  cards.addAll(resultCards);
                }
              });
              saveProgress(); // Save updated cards list
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cần ít nhất 10 thẻ bài để đấu!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredCards = _selectedRarityFilter == 0
        ? cards
        : cards.where((card) => card.rarity == _selectedRarityFilter).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Quay lại',
        ),
        title: const Text(
          'Kho Báu Thẻ Bài',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.yellow, blurRadius: 8),
              Shadow(color: Colors.orange, blurRadius: 4),
            ],
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orange, Colors.red],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom:
                  BorderSide(color: Colors.yellow.withOpacity(0.5), width: 2),
            ),
          ),
        ),
        actions: [
          PopupMenuButton<int>(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.yellow, Colors.orange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child:
                  const Icon(Icons.filter_list, color: Colors.white, size: 28),
            ),
            onSelected: (value) {
              setState(() {
                _selectedRarityFilter = value;
                _currentCardIndex = 0;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Tất cả', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.pets, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('Thường', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Hiếm', style: TextStyle(color: Colors.blue)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.diamond, color: Colors.purple, size: 20),
                    SizedBox(width: 8),
                    Text('Epic', style: TextStyle(color: Colors.purple)),
                  ],
                ),
              ),
            ],
            color: Colors.black87,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [Colors.black87, Colors.grey],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: filteredCards.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    Expanded(child: _buildCardFlipper(filteredCards)),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        onPressed: _startBattle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text(
                          'Đấu Thẻ Bài',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Kho báu trống rỗng!',
            style: TextStyle(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: Colors.yellow, blurRadius: 4)],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thu thập thêm thẻ bài nhé!',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFlipper(List<Cards> filteredCards) {
    final card = filteredCards[_currentCardIndex];
    final rarityColor = card.rarity == 1
        ? Colors.grey
        : card.rarity == 2
            ? Colors.blue
            : Colors.purple;
    final rarityText = card.rarity == 1
        ? 'Thường'
        : card.rarity == 2
            ? 'Hiếm'
            : 'Epic';

    return Column(
      children: [
        Expanded(
          child: Center(
            child: FlipCard(
              flipOnTouch: true,
              front: _buildCardFront(card, rarityColor),
              back: _buildCardBack(card, rarityColor, rarityText),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _currentCardIndex > 0
                    ? () => setState(() => _currentCardIndex--)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.arrow_left, color: Colors.white),
              ),
              Text(
                '${_currentCardIndex + 1}/${filteredCards.length}',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              ElevatedButton(
                onPressed: _currentCardIndex < filteredCards.length - 1
                    ? () => setState(() => _currentCardIndex++)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.arrow_right, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCardFront(Cards card, Color rarityColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.black87, Colors.grey],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: rarityColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(17)),
              child: Image.file(
                File(card.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image from ${card.imagePath}: $error');
                  return Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image,
                        size: 80, color: Colors.white),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              card.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(color: rarityColor, blurRadius: 5)],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(Cards card, Color rarityColor, String rarityText) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 200,
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [rarityColor.withOpacity(0.9), Colors.black.withOpacity(0.7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: rarityColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              card.name,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: rarityColor.withOpacity(0.5), blurRadius: 6)
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              card.description,
              style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.category, color: rarityColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        card.type,
                        style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_martial_arts,
                              color: rarityColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            card.attack.toString(),
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.shield, color: rarityColor, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            card.defense.toString(),
                            style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rarityColor, rarityColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rarityColor, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: rarityColor.withOpacity(0.4),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                rarityText,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(color: rarityColor.withOpacity(0.5), blurRadius: 2)
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Class quản lý thời gian
// Class quản lý thời gian
class _QuizTimer {
  final Map<int, DateTime> _startTimes = {};
  final Map<int, Duration> _questionTimes = {};

  /// Bắt đầu đếm thời gian cho câu hỏi tại index
  void start(int index) {
    _startTimes[index] = DateTime.now();
    print('Timer started for question $index at ${_startTimes[index]}');
  }

  /// Kết thúc và tính thời gian cho câu hỏi tại index
  void end(int index) {
    if (_startTimes.containsKey(index)) {
      final endTime = DateTime.now();
      _questionTimes[index] = endTime.difference(_startTimes[index]!);
      print(
          'Timer ended for question $index: ${_questionTimes[index]!.inMilliseconds}ms');
      _startTimes.remove(index); // Xóa thời gian bắt đầu sau khi tính xong
    } else {
      print('Warning: No start time recorded for question $index');
      _questionTimes[index] =
          Duration.zero; // Gán 0 nếu không có thời gian bắt đầu
    }
  }

  /// Trả về map chứa thời gian của các câu hỏi đã hoàn thành
  Map<int, Duration> getTimes() => Map.unmodifiable(_questionTimes);

  /// Lấy thời gian của một câu hỏi cụ thể, trả về Duration.zero nếu chưa có
  Duration getTime(int index) => _questionTimes[index] ?? Duration.zero;

  /// Xóa toàn bộ dữ liệu thời gian
  void reset() {
    _startTimes.clear();
    _questionTimes.clear();
    print('QuizTimer reset');
  }

  /// Xóa dữ liệu khi không cần thiết (giữ tương thích với dispose cũ)
  void dispose() {
    reset();
  }
}

class PhoneFriendDialog extends StatefulWidget {
  final String correctAnswer;

  const PhoneFriendDialog({required this.correctAnswer, super.key});

  @override
  _PhoneFriendDialogState createState() => _PhoneFriendDialogState();
}

class _PhoneFriendDialogState extends State<PhoneFriendDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _phoneShake;
  double _progress = 1.0; // Giá trị ban đầu của thanh đếm ngược
  bool _showAnswer = false;
  Timer? _timer; // Khai báo Timer để hủy khi dispose

  @override
  void initState() {
    super.initState();
    // SoundUtils.playSound(Sounds.audiencePhone); // Giả định bạn có âm thanh

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _phoneShake = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Đếm ngược 5 giây trước khi hiển thị đáp án
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress = (_progress - 0.01)
              .clamp(0.0, 1.0); // Giới hạn _progress từ 0.0 đến 1.0
          if (_progress <= 0) {
            _showAnswer = true;
            _controller.stop();
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Hủy timer khi widget bị dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.blueGrey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.blueAccent.withOpacity(0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon điện thoại rung
            AnimatedBuilder(
              animation: _phoneShake,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _phoneShake.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.phone, color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Tiêu đề gay cấn
            Text(
              'Gọi Điện Người Thân!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.blueAccent, blurRadius: 8),
                ],
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Thanh đếm ngược
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[800],
              ),
              child: FractionallySizedBox(
                widthFactor: _progress, // Đã được giới hạn >= 0
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.redAccent, Colors.blueAccent],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Ý kiến người thân
            Text(
              _showAnswer ? 'Người thân nói:' : 'Đang chờ ý kiến...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Hiển thị đáp án khi đếm ngược xong
            if (_showAnswer)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.3),
                      Colors.blue.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  widget.correctAnswer,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Nút đóng khi đáp án hiển thị
            if (_showAnswer) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.blueAccent.withOpacity(0.5),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AudiencePollDialog extends StatefulWidget {
  final Map<String, int> pollResults;

  const AudiencePollDialog({required this.pollResults, super.key});

  @override
  _AudiencePollDialogState createState() => _AudiencePollDialogState();
}

class _AudiencePollDialogState extends State<AudiencePollDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _crowdShake;
  double _revealProgress = 0.0; // Tiến trình hiển thị kết quả
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    // SoundUtils.playSound(Sounds.audiencePhone); // Giả định bạn có âm thanh

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _crowdShake = Tween<double>(begin: -0.01, end: 0.01).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Đếm ngược 2 giây trước khi hiển thị kết quả
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showResults = true;
          _controller.stop();
        });
      }
    });

    // Animation tăng dần thanh biểu đồ
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _revealProgress = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.blueGrey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.yellowAccent.withOpacity(0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.yellowAccent.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon khán giả rung
            AnimatedBuilder(
              animation: _crowdShake,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_crowdShake.value * 10, 0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.yellowAccent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.people,
                        color: Colors.yellowAccent,
                        size: 50,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Tiêu đề gay cấn
            Text(
              'Bình Chọn Khán Giả!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.yellowAccent, blurRadius: 8),
                ],
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Thông báo chờ hoặc kết quả
            Text(
              _showResults ? 'Khán giả đã chọn:' : 'Khán giả đang bình chọn...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Danh sách kết quả
            if (_showResults)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.pollResults.length,
                  itemBuilder: (_, index) {
                    final entry = widget.pollResults.entries.elementAt(index);
                    final isCorrect = entry.value >= 40; // Đáp án đúng có % cao
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  entry.key,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: isCorrect
                                            ? Colors.greenAccent
                                            : Colors.redAccent,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: Stack(
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    Container(
                                      height: 24,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 1000),
                                      curve: Curves.easeOut,
                                      height: 24,
                                      width: MediaQuery.of(context).size.width *
                                          0.4 *
                                          (entry.value / 100) *
                                          _revealProgress,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        gradient: LinearGradient(
                                          colors: isCorrect
                                              ? [
                                                  Colors.greenAccent,
                                                  Colors.green,
                                                ]
                                              : [
                                                  Colors.blueAccent,
                                                  Colors.blue,
                                                ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isCorrect
                                                ? Colors.greenAccent
                                                    .withOpacity(0.5)
                                                : Colors.blueAccent
                                                    .withOpacity(0.5),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Center(
                                      child: Text(
                                        '${entry.value}%',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          shadows: [
                                            Shadow(
                                                color: Colors.black,
                                                blurRadius: 2),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Nút đóng khi kết quả hiển thị
            if (_showResults) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellowAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.yellowAccent.withOpacity(0.5),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HintDialog extends StatefulWidget {
  final String hint;

  const HintDialog({required this.hint, super.key});

  @override
  _HintDialogState createState() => _HintDialogState();
}

class _HintDialogState extends State<HintDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bulbShake;
  double _revealProgress = 0.0; // Tiến trình hiển thị gợi ý
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    // SoundUtils.playSound(Sounds.question); // Giả định bạn có âm thanh

    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _bulbShake = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Đếm ngược 1.5 giây trước khi hiển thị gợi ý
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showHint = true;
          _controller.stop();
          _revealProgress = 1.0; // Hiển thị gợi ý đầy đủ
        });
      }
    });

    // Animation tăng dần thanh tiến trình
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _revealProgress = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.purple[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.blueAccent.withOpacity(0.7), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withOpacity(0.5),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon đèn sáng rung
            AnimatedBuilder(
              animation: _bulbShake,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _bulbShake.value,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.blueAccent.withOpacity(0.6),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.lightbulb,
                            color: Colors.white, size: 30),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Tiêu đề hấp dẫn
            Text(
              'Gợi Ý Bí Ẩn!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.blueAccent, blurRadius: 8),
                ],
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Thanh tiến trình khai sáng
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[800],
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeInOut,
                width:
                    MediaQuery.of(context).size.width * 0.6 * _revealProgress,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.cyanAccent],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Gợi ý hoặc thông báo chờ
            Text(
              _showHint ? 'Đây là gợi ý của bạn:' : 'Đang khai sáng...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Hiển thị gợi ý khi hoàn tất
            if (_showHint)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent.withOpacity(0.3),
                      Colors.cyan.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  widget.hint,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Nút đóng khi gợi ý hiển thị
            if (_showHint) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.blueAccent.withOpacity(0.5),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
