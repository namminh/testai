import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../data/models/quiz_question_model.dart';
import '../../../../dir_helper.dart';

class QuizDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot data;

  const QuizDetailPage({Key? key, required this.data}) : super(key: key);

  @override
  State<QuizDetailPage> createState() => _QuizDetailPageState();
}

class _QuizDetailPageState extends State<QuizDetailPage> {
  bool _isExporting = false;

  Future<bool> _createPdf(List<QuizQuestion> questions) async {
    final pdf = pw.Document();
    final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
    final ttf = pw.Font.ttf(fontData);
    final fontBoldData = await rootBundle.load("assets/fonts/Roboto-Bold.ttf");
    final ttfBold = pw.Font.ttf(fontBoldData);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => questions.map((q) {
          final allOptions = [
            q.answer ?? 'Không có đáp án',
            ...(q.distractors ?? []).map((d) => d.content ?? 'Không có'),
          ]..shuffle();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(q.question,
                  style: pw.TextStyle(font: ttfBold, fontSize: 18)),
              pw.SizedBox(height: 10),
              ...allOptions.asMap().entries.map((e) => pw.Text(
                    '${String.fromCharCode(97 + e.key)}) ${e.value}',
                    style: pw.TextStyle(
                      font: e.value == q.answer ? ttfBold : ttf,
                      fontSize: 16,
                    ),
                  )),
              pw.Text('Đáp án đúng: ${q.answer}',
                  style: pw.TextStyle(font: ttf, color: PdfColors.green)),
              pw.Text('Giải thích: ${q.explanation ?? "Không có"}',
                  style: pw.TextStyle(font: ttf)),
              pw.Divider(),
            ],
          );
        }).toList(),
      ),
    );

    final tempPath = await DirHelper.getAppPath();
    final path =
        '${tempPath}/${widget.data['subject']}_${widget.data['topic']}_${DateTime.now().toIso8601String()}.pdf';

    final file = File(path);

    try {
      await file.writeAsBytes(await pdf.save());
      return true;
    } catch (e) {
      print('Lỗi lưu PDF: $e');
      return false;
    }
  }

  void _exportToPdf(List<QuizQuestion> questions) async {
    setState(() => _isExporting = true);
    final success = await _createPdf(questions);
    setState(() => _isExporting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(success ? 'PDF đã lưu thành công!' : 'Lỗi khi lưu PDF!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questions = (widget.data['questions'] as List)
        .map((item) => QuizQuestion.fromJson(item))
        .toList();
    final selectedAnswers =
        Map<int, String>.from(widget.data['selectedAnswers']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Chi Tiết Quiz - ${widget.data['subject']}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
        child: Stack(
          children: [
            ListView.builder(
              itemCount: questions.length,
              itemBuilder: (context, index) => _QuizItem(
                question: questions[index],
                index: index,
                selectedAnswer: selectedAnswers[index],
              ),
            ),
            if (_isExporting)
              Container(
                color: Colors.black.withOpacity(0.3),
                child:
                    const Center(child: CircularProgressIndicator.adaptive()),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isExporting ? null : () => _exportToPdf(questions),
        backgroundColor: Colors.blue[700],
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}

// Widget hiển thị câu hỏi
class _QuizItem extends StatelessWidget {
  final QuizQuestion question;
  final int index;
  final String? selectedAnswer;

  const _QuizItem({
    required this.question,
    required this.index,
    this.selectedAnswer,
  });
  Widget _buildQuestionText(String text) {
    final latexRegex =
        RegExp(r'\\\((.*?)\\\)|\\\[(.*?)\\\]|(\$[^\$]*\$)|(\$\$[^\$]*\$\$)');
    if (!latexRegex.hasMatch(text))
      return Text(text, style: const TextStyle(fontSize: 18));

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
    if (currentIndex < text.length)
      spans.add(TextSpan(text: text.substring(currentIndex)));

    return RichText(
      text: TextSpan(
          children: spans,
          style: const TextStyle(fontSize: 18, color: Colors.black)),
    );
  }

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
            Text('Đáp án chọn: ${selectedAnswer ?? "Chưa chọn"}',
                style: TextStyle(color: Colors.grey[700])),
            const SizedBox(height: 5),
            Text(
              'Đáp án đúng: ${question.answer}',
              style: const TextStyle(
                  color: Colors.green, fontWeight: FontWeight.bold),
            ),
            if (question.explanation != null) ...[
              const SizedBox(height: 10),
              Text('Giải thích: ${question.explanation}',
                  style: TextStyle(color: Colors.blue[700])),
            ],
          ],
        ),
      ),
    );
  }
}
