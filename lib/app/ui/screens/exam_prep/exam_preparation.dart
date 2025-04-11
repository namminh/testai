import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/exam_prep_view_model.dart';
import 'package:nemoai/app/ui/screens/home/home_widget/app_bar.dart';
import '../../../core/utils/utils.dart';
import '../../../data/providers/base_view.dart';
import '../../../routes/routes.dart';
import '../../widgets/common_sized_box.dart';
import 'quiz_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart'; // Cho HapticFeedback
import '../../../core/utils/soundUtils.dart'; // Giả định bạn có SoundUtils
import 'dart:math';

class ExamPreparation extends StatefulWidget {
  const ExamPreparation({Key? key}) : super(key: key);

  @override
  _ExamPreparationState createState() => _ExamPreparationState();
}

class _ExamPreparationState extends State<ExamPreparation>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  int _userXP = 0; // Điểm kinh nghiệm
  int _userLevel = 1; // Cấp độ
  List<String> _badges = []; // Huy hiệu

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userXP = prefs.getInt('userXp') ?? 0;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _generateQuiz(ExamPrepViewModel model) async {
    if (!_validateInputs(model)) {
      _showInputError();
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await model.generateQuestionsTrain();
      if (model.questions.isNotEmpty) {
        _awardXP(20); // Thưởng 20 XP khi tạo quiz
        Navigator.pushNamed(context, Routes.quizRoute);
      } else {
        setState(() => _errorMessage = 'Không tạo được câu hỏi.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Lỗi: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _awardXP(int xp) async {
    setState(() => _userXP += xp);
    final newLevel = (_userXP ~/ 100) + 1;
    if (newLevel > _userLevel) {
      setState(() => _userLevel = newLevel);
      _awardBadge('Level Up $newLevel');
      _showLevelUpDialog(
        context,
        newLevel,
        (gold, item) {
          setState(() {});
          _awardXP(_userXP);
        },
      );
    }
  }

  void _awardBadge(String badge) {
    if (!_badges.contains(badge)) {
      setState(() => _badges.add(badge));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chúc mừng! Bạn nhận được huy hiệu: $badge')),
      );
    }
  }

  bool _validateInputs(ExamPrepViewModel model) {
    return model.subjectController.text.isNotEmpty &&
        model.topicController.text.isNotEmpty &&
        model.soCau.text.isNotEmpty &&
        model.ngonNgu.text.isNotEmpty &&
        model.level.text.isNotEmpty;
  }

  void _showInputError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vui lòng điền đầy đủ thông tin.')),
    );
  }

  void _showLevelUpDialog(
      BuildContext context, int level, Function(int, String?) onLevelUpReward) {
    showDialog(
      context: context,
      barrierDismissible: false, // Không đóng dialog bằng cách nhấn ngoài
      builder: (_) => _LevelUpDialog(
        level: level,
        onLevelUpReward: onLevelUpReward,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (model) {
        model.ngonNgu.text =
            model.ngonNgu.text.isEmpty ? 'Tiếng Việt' : model.ngonNgu.text;
        model.level.text =
            model.level.text.isEmpty ? 'Trung bình' : model.level.text;
      },
      builder: (context, model, child) => Scaffold(
        appBar: HomeAppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Luyện thi',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[50]!, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(
                  top: 16,
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                      value: (_userXP % 100) / 100,
                      color: Colors.green,
                      backgroundColor: Colors.grey[300],
                    ),
                    const SizedBox(height: 10),
                    Text('XP: $_userXP / ${(_userLevel * 100)}'),
                    _InputField(
                      controller: model.subjectController,
                      hintText: 'Môn/Subject',
                      icon: Icons.book,
                    ),
                    _InputField(
                      controller: model.topicController,
                      hintText: 'Chủ đề/Topic',
                      icon: Icons.topic,
                    ),
                    _InputField(
                      controller: model.soCau,
                      hintText: 'Số câu/Count',
                      icon: Icons.format_list_numbered,
                      keyboardType: TextInputType.number,
                    ),
                    _InputField(
                      controller: model.ngonNgu,
                      hintText: 'Ngôn ngữ/Language',
                      icon: Icons.language,
                    ),
                    _InputField(
                      controller: model.level,
                      hintText: 'Mức độ/Level',
                      icon: Icons.signal_cellular_alt,
                    ),
                    const SizedBox(height: 20),
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (_, child) => Transform.scale(
                        scale: 1.0 + _animationController.value * 0.1,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading ? null : () => _generateQuiz(model),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[700],
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Bắt Đầu Thử Thách',
                              style:
                                  TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildQuizHistory(model),
                  ],
                ),
              ),
              if (_isLoading)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child:
                      const Center(child: CircularProgressIndicator.adaptive()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizHistory(ExamPrepViewModel model) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[500]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: const Row(
              children: [
                Icon(Icons.history, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  'Lịch Sử Làm Bài',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(model.auth.user?.uid)
                  .collection('quizHistory')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Lỗi tải lịch sử'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có lịch sử làm bài'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var data = snapshot.data!.docs[index];
                    return ListTile(
                      title: Text('Quiz ${index + 1} - ${data['subject']}'),
                      subtitle: Text('Topic: ${data['topic']}'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => QuizDetailPage(data: data)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(icon, color: Colors.blue[700]),
          filled: true,
          fillColor: Colors.white.withOpacity(0.9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _LevelUpDialog extends StatefulWidget {
  final int level;
  final Function(int, String?)
      onLevelUpReward; // Callback để trả về phần thưởng

  const _LevelUpDialog({required this.level, required this.onLevelUpReward});

  @override
  _LevelUpDialogState createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int _goldReward = 50; // Phần thưởng cơ bản
  String? _itemReward;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _generateRewards();
    _animationController.forward();
    HapticFeedback.heavyImpact(); // Rung mạnh khi lên cấp
    SoundUtils.playSound(Sounds.correct); // Giả định bạn có âm thanh levelup
  }

  void _generateRewards() {
    if (_random.nextDouble() < 0.2) {
      // 20% cơ hội nhận vật phẩm hiếm
      _itemReward = widget.level % 5 == 0 ? 'Huy Hiệu Vàng' : 'Ngôi Sao Cấp Độ';
    }
    if (widget.level % 10 == 0) {
      // Thưởng lớn mỗi 10 cấp
      _goldReward += 100;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.purple[800],
      contentPadding: const EdgeInsets.all(16),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/lottie/bagde.json', // File Lottie cho hiệu ứng lên cấp
            width: 150,
            height: 150,
            controller: _animationController,
            onLoaded: (composition) {
              _animationController.duration = composition.duration;
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Chúc mừng! Bạn đã đạt cấp ${widget.level}!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          AnimatedOpacity(
            opacity: _animationController.isCompleted ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 500),
            child: Column(
              children: [
                Text(
                  'Phần thưởng: +$_goldReward Đồng Vàng',
                  style: const TextStyle(color: Colors.yellow, fontSize: 16),
                ),
                if (_itemReward != null)
                  Text(
                    'Vật phẩm hiếm: $_itemReward!',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 16),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Tiếp tục chinh phục những đỉnh cao mới!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (_animationController.isCompleted)
          TextButton(
            onPressed: () {
              widget.onLevelUpReward(
                  _goldReward, _itemReward); // Trả về phần thưởng
              Navigator.pop(context);
            },
            child: const Text(
              'Tuyệt vời!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
      ],
    );
  }
}
