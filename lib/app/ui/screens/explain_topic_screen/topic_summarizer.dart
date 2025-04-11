import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:nemoai/app/data/providers/base_view.dart';
import 'package:nemoai/app/data/providers/viewmodel/topic_summarizer_view.dart';
import '../home/home_widget/app_bar.dart';

// ignore: must_be_immutable
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});
  @override
  // ignore: library_private_types_in_public_api
  _TopicScreenState createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen>
    with TickerProviderStateMixin {
  TopicSummarizerView? model;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
  }

  void _initializeQuiz() async {
    setState(() async {
      _isLoading = true;
      await model!.summarizeTopic();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<TopicSummarizerView>(
      onModelReady: (model) {
        this.model = model;
        _initializeQuiz();
      },
      builder: (context, model, child) {
        return SafeArea(
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              model.keyboard(false);
            },
            child: Scaffold(
              appBar: HomeAppBar(
                title: ShaderMask(
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
                          'Nhận xét',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              body: buildTopicBody(context),
              // floatingActionButton: FloatingActionButton(
              //   onPressed: () {
              //     // createPdf();
              //   },
              //   child: const Icon(Icons.picture_as_pdf),
              // ),
            ),
          ),
        );
      },
    );
  }

  Widget buildTopicBody(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Section

          // Action Button
          ElevatedButton.icon(
            onPressed: _isLoading
                ? null // Disable button when loading
                : () async {
                    setState(() {
                      _isLoading = true;
                    });
                    try {
                      await model!.summarizeTopic();
                    } finally {
                      if (mounted) {
                        // Check if widget is still mounted
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  },
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  )
                : const Icon(Icons.analytics),
            label: Text(_isLoading ? 'Đang xử lý...' : 'Phân tích'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              // Tạo hiệu ứng mờ khi loading
              backgroundColor: _isLoading
                  ? Theme.of(context).primaryColor.withOpacity(0.7)
                  : null,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: model?.summary != null && model!.summary!.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            // Changed from Markdown to MarkdownBody
                            data: model!.summary,
                            selectable: true,
                            styleSheet: MarkdownStyleSheet(
                              p: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                              h1: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                // Fixed blockquote styling
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.analytics_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Nhấn nút "Phân tích" để xem kết quả',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
