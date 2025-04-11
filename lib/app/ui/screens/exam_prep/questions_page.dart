import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../../../data/models/quiz_question_model.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/exam_prep_view_model.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle; // Thêm import này
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../dir_helper.dart';

class QuestionsPage extends StatefulWidget {
  const QuestionsPage({super.key});

  @override
  _QuestionsPageState createState() => _QuestionsPageState();
}

class _QuestionsPageState extends State<QuestionsPage>
    with SingleTickerProviderStateMixin {
  late ExamPrepViewModel model;
  final Map<int, String?> selectedAnswers = {};
  int score = 0;
  bool submitted = false;
  List<List<String>>? _shuffledOptions;
  bool _isLoading = true;
  late ValueNotifier<int> _timeLeftNotifier;
  late AnimationController _dialogAnimationController;
  Map<String, int> _weakTopics = {}; // Theo dõi điểm yếu
  List<int> _incorrectIndices = []; // Lưu câu sai cho retry

  @override
  void initState() {
    super.initState();
    _timeLeftNotifier = ValueNotifier<int>(300);
    _dialogAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _startTimer();
  }

  void _startTimer() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeftNotifier.value > 0 && !submitted) {
        _timeLeftNotifier.value -= 1;
      } else if (_timeLeftNotifier.value <= 0 && !submitted) {
        timer.cancel();
        _submitQuiz();
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _submitQuiz() {
    setState(() {
      submitted = true;
      score = _calculateScore();
      _analyzeWeaknesses();
      model.saveQuizToFirestore();
      model.timeTrain =
          _timeLeftNotifier.value / _getTimeBasedOnDifficulty(model.level.text);
      _showResultsDialog();
    });
  }

  void _analyzeWeaknesses() {
    _weakTopics.clear();
    _incorrectIndices.clear();
    model.questions.asMap().forEach((index, q) {
      if (selectedAnswers[index] != q.answer) {
        _weakTopics.update(
            model!.topicController.text ?? 'Unknown', (value) => value + 1,
            ifAbsent: () => 1);
        _incorrectIndices.add(index);
      }
    });
  }

  Future<void> _smartRetry() async {
    setState(() {
      _isLoading = true;
      submitted = false;
      selectedAnswers.clear();
    });
    await model.generateQuestionsTrain();
    _initializeQuiz();
  }

  @override
  void dispose() {
    _timeLeftNotifier.dispose();
    _dialogAnimationController.dispose();
    super.dispose();
  }

  int _getTimeBasedOnDifficulty(String difficulty) {
    return switch (difficulty) {
      'easy' => 600,
      'medium' => 420,
      'hard' => 300,
      _ => 300,
    };
  }

  Future<void> _initializeQuiz() async {
    await model.generateQuestionsTrain();
    setState(() {
      _shuffledOptions = model.questions
          .asMap()
          .map((i, q) => MapEntry(i, model.shuffleAnswers(q, i)))
          .values
          .toList();
      _timeLeftNotifier.value = _getTimeBasedOnDifficulty(model.level.text);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (m) {
        model = m;
        _initializeQuiz();
      },
      builder: (context, _, __) => Scaffold(
        appBar: AppBar(
          title: const Text('Luyện Thi Trắc Nghiệm',
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            ValueListenableBuilder<int>(
              valueListenable: _timeLeftNotifier,
              builder: (_, time, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 20),
                    const SizedBox(width: 5),
                    Text(
                      _formatTime(time),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.analytics),
              onPressed: _showResultsDialog,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[900]!, Colors.blue[600]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
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
          child: _isLoading || _shuffledOptions == null
              ? const Center(child: CircularProgressIndicator())
              : _buildQuizPage(),
        ),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: _exportToPdf,
              backgroundColor: Colors.blue[700],
              child: const Icon(Icons.picture_as_pdf),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              onPressed: submitted ? _smartRetry : null,
              backgroundColor: submitted ? Colors.orange : Colors.grey,
              child: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizPage() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: model.questions.length,
            itemBuilder: (_, index) => _QuestionCard(
              question: model.questions[index],
              index: index,
              shuffledOptions: _shuffledOptions![index],
              selectedAnswer: selectedAnswers[index],
              submitted: submitted,
              onAnswerSelected: (value) =>
                  setState(() => selectedAnswers[index] = value),
            ),
          ),
        ),
        if (!submitted)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _submitQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Nộp Bài',
                  style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
          ),
      ],
    );
  }

  void _showResultsDialog() {
    _dialogAnimationController.reset();
    showGeneralDialog(
      context: context,
      pageBuilder: (_, __, ___) => ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0)
            .animate(_dialogAnimationController),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white.withOpacity(0.95),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                score >= model.questions.length / 2
                    ? Icons.emoji_events
                    : Icons.school,
                color: score >= model.questions.length / 2
                    ? Colors.amber
                    : Colors.blue,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Text('Kết Quả Luyện Thi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularPercentIndicator(
                radius: 60.0,
                lineWidth: 10.0,
                percent: score / model.questions.length,
                center: Text(
                  '${(score / model.questions.length * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                progressColor: score == model.questions.length
                    ? Colors.green
                    : (score >= model.questions.length / 2
                        ? Colors.orange
                        : Colors.red),
              ),
              const SizedBox(height: 20),
              Text('Điểm: $score/${model.questions.length}',
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 10),
              Text(
                _getMotivationalMessage(score, model.questions.length),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              if (_weakTopics.isNotEmpty)
                Text(
                  'Điểm yếu: ${_weakTopics.entries.map((e) => "${e.key} (${e.value} sai)").join(", ")}',
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => _showDetailedFeedback(context),
                child: const Text('Xem Phân Tích & Gợi Ý'),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Luyện Lại Câu Sai'),
              onPressed: () {
                Navigator.pop(context);
                _smartRetry();
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.close),
              label: const Text('Thoát'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 300),
    );
    _dialogAnimationController.forward();
  }

  String _getMotivationalMessage(int score, int total) {
    double percentage = score / total * 100;
    if (percentage == 100) return "Tuyệt vời! Bạn sẵn sàng cho kỳ thi rồi! 🌟";
    if (percentage >= 80)
      return "Rất tốt! Chỉ cần tinh chỉnh chút nữa thôi! 🎯";
    if (percentage >= 60) return "Khá ổn! Hãy tập trung vào điểm yếu nhé! 👍";
    if (percentage >= 50) return "Cần cố gắng hơn! Bạn làm được mà! 💪";
    return "Đừng nản! Luyện tập thêm để bứt phá nhé! 📚";
  }

  void _showDetailedFeedback(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phân Tích & Gợi Ý Học Tập'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...model.questions.asMap().entries.map((entry) {
                int idx = entry.key;
                QuizQuestion q = entry.value;
                return ListTile(
                  title: Text(q.question),
                  subtitle: Text(
                    'Đáp án của bạn: ${selectedAnswers[idx] ?? "Chưa chọn"}\n'
                    'Đáp án đúng: ${q.answer}\n'
                    'Giải thích: ${q.explanation}\n'
                    'Gợi ý: ${q.learningTip ?? "Ôn lại chủ đề ${model!.topicController.text}"}"',
                    style: TextStyle(
                      color: selectedAnswers[idx] == q.answer
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
              if (_weakTopics.isNotEmpty)
                Text(
                  'Lộ trình cải thiện: Ôn tập ${_weakTopics.keys.join(", ")} trước.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPdf() async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => model.questions
            .map((q) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(q.question,
                        style: pw.TextStyle(font: ttf, fontSize: 16)),
                    ..._shuffledOptions![model.questions.indexOf(q)]
                        .map((opt) => pw.Text('- $opt')),
                    pw.Text('Đáp án đúng: ${q.answer}',
                        style: pw.TextStyle(font: ttf, color: PdfColors.green)),
                    pw.Text('Giải thích: ${q.explanation ?? "Không có"}'),
                    pw.Text('Gợi ý: ${q.learningTip ?? "Ôn lại chủ đề này"}"'),
                    pw.Divider(),
                  ],
                ))
            .toList(),
      ),
    );

    final tempPath = await DirHelper.getAppPath();
    final path =
        '$tempPath/${model.topicController.text}_${model.subjectController.text}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('PDF đã lưu tại: $path')));
  }

  int _calculateScore() {
    return model.questions
        .asMap()
        .entries
        .where((entry) => selectedAnswers[entry.key] == entry.value.answer)
        .length;
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final int index;
  final List<String> shuffledOptions;
  final String? selectedAnswer;
  final bool submitted;
  final ValueChanged<String?> onAnswerSelected;

  const _QuestionCard({
    required this.question,
    required this.index,
    required this.shuffledOptions,
    this.selectedAnswer,
    required this.submitted,
    required this.onAnswerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(10),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildQuestionText('${index + 1}. ${question.question}'),
            const SizedBox(height: 10),
            ...shuffledOptions.map((option) => RadioListTile<String>(
                  title: _buildQuestionText(option),
                  value: option,
                  groupValue: selectedAnswer,
                  onChanged: submitted ? null : onAnswerSelected,
                  tileColor: submitted
                      ? (option == question.answer
                          ? Colors.green.withOpacity(0.2)
                          : selectedAnswer == option
                              ? Colors.red.withOpacity(0.2)
                              : null)
                      : null,
                  activeColor: submitted
                      ? (option == question.answer ? Colors.green : Colors.red)
                      : Colors.blue,
                )),
            if (submitted) ...[
              Text(
                'Giải thích: ${question.explanation}',
                style: const TextStyle(color: Colors.green),
              ),
              Text(
                'Gợi ý: ${question.learningTip ?? "Ôn lại chủ đề này"}"',
                style: const TextStyle(color: Colors.blue),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionText(String text) {
    final latexRegex =
        RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]|(\$[^\$]*\$)|(\$\$[^\$]*\$\$)');
    if (!latexRegex.hasMatch(text)) {
      return Text(text, style: const TextStyle(fontSize: 18));
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
        child: Math.tex(latex, textStyle: const TextStyle(fontSize: 18)),
      ));
      currentIndex = match.end;
    }
    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(
          children: spans,
          style: const TextStyle(fontSize: 18, color: Colors.black)),
    );
  }
}
