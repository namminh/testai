import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/auth_view_model.dart';
import 'package:nemoai/app/data/providers/viewmodel/exam_prep_view_model.dart';
import 'package:nemoai/app/data/models/quiz_question_model.dart';
import 'package:nemoai/app/data/providers/base_view.dart';
import 'package:nemoai/app/routes/routes.dart';
import 'package:share_plus/share_plus.dart'; // Để chia sẻ mã mời

class FriendScreen extends StatefulWidget {
  @override
  _FriendScreenState createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen>
    with SingleTickerProviderStateMixin {
  final AuthViewModel authViewModel = AuthViewModel();
  ExamPrepViewModel model = ExamPrepViewModel();
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (model) => this.model = model,
      builder: (context, model, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Sảnh Thách Đấu Bạn Bè',
              style: TextStyle(
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(color: Colors.yellowAccent, blurRadius: 8),
                ],
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.yellow[800]!, Colors.amber[600]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            actions: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: IconButton(
                      icon: const Icon(Icons.share,
                          color: Colors.white, size: 28),
                      onPressed: _shareChallenge,
                      tooltip: 'Chia sẻ thử thách',
                    ),
                  );
                },
              ),
            ],
          ),
          extendBodyBehindAppBar: true,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.purple[900]!, Colors.deepPurple[900]!],
              ),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(authViewModel.useremail)
                  .collection('quizHistoryFriend')
                  .orderBy('timestamp', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Lỗi: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Colors.amber)));
                }

                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Chưa có thử thách nào từ bạn bè!\nHãy mời bạn bè tham gia!',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontFamily: 'FantasyFont',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == docs.length) {
                      return const Center(
                          child: CircularProgressIndicator(
                              valueColor:
                                  AlwaysStoppedAnimation(Colors.amber)));
                    }
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        color: Colors.transparent,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[800]!, Colors.blue[600]!],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.7), width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.amber.withOpacity(0.4),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: const Icon(Icons.shield,
                                      color: Colors.amber, size: 32),
                                );
                              },
                            ),
                            title: Text(
                              '${data['subject'] ?? 'Unknown'} - ${data['topic'] ?? 'Unknown'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'FantasyFont',
                              ),
                            ),
                            subtitle: Text(
                              'Từ: ${data['friendEmail'] ?? 'Bạn ẩn danh'}',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 14),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios,
                                color: Colors.amber),
                            onTap: () => _loadChallenge(data),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _shareChallenge,
            backgroundColor: Colors.amber,
            child: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Tạo thử thách mới',
          ),
        );
      },
    );
  }

  Future<void> _loadChallenge(Map<String, dynamic> data) async {
    try {
      if (data['questions'] == null || (data['questions'] as List).isEmpty) {
        throw Exception('Không tìm thấy câu hỏi');
      }

      List<QuizQuestion> loadedQuestions = [];
      for (var questionData in data['questions']) {
        if (questionData is Map<String, dynamic>) {
          loadedQuestions.add(QuizQuestion.fromJson(questionData));
        }
      }

      if (loadedQuestions.isEmpty) {
        throw Exception('Không có câu hỏi hợp lệ');
      }

      setState(() {
        model.friendGame = true;
        model.questions = loadedQuestions;
        model.subjectController.text = data['subject'] ?? '';
        model.topicController.text = data['topic'] ?? '';
        model.selectedAnswers.clear();
      });

      // Thêm phần thưởng khi chấp nhận thử thách
      await _addReward(10, 5); // +10 XP, +5 Coins
      Navigator.pushNamed(context, Routes.quizGame);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi tải thử thách: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareChallenge() async {
    try {
      if (model.questions.isEmpty) {
        throw Exception('Chưa có bài kiểm tra để chia sẻ');
      }

      final inviteCode = DateTime.now().millisecondsSinceEpoch.toString();
      await FirebaseFirestore.instance
          .collection('invites')
          .doc(inviteCode)
          .set({
        'userEmail': authViewModel.useremail,
        'subject': model.subjectController.text,
        'topic': model.topicController.text,
        'questions': model.questions.map((q) => q.toJson()).toList(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      final shareText =
          'Tham gia thử thách của tôi trong NemoAI!\nMã: $inviteCode\nLink: nemoai.com/invite/$inviteCode';
      await Share.share(shareText);

      // Thêm phần thưởng khi chia sẻ
      await _addReward(5, 10); // +5 XP, +10 Coins
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã tạo lời mời thành công!\n+5 XP | +10 Coins'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Lỗi chia sẻ: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  // Hàm thêm phần thưởng (giả lập, cần tích hợp với hệ thống thực tế)
  Future<void> _addReward(int xp, int coins) async {
    try {
      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(authViewModel.useremail);
      await userDoc.update({
        'xp': FieldValue.increment(xp),
        'coins': FieldValue.increment(coins),
      });
      print('Added reward: +$xp XP, +$coins Coins');
    } catch (e) {
      print('Error adding reward: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);

    final nextSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(authViewModel.useremail)
        .collection('quizHistoryFriend')
        .orderBy('timestamp', descending: true)
        .startAfterDocument(_lastDoc!)
        .limit(10)
        .get();

    setState(() {
      _lastDoc = nextSnapshot.docs.isNotEmpty ? nextSnapshot.docs.last : null;
      _isLoadingMore = false;
    });
  }
}
