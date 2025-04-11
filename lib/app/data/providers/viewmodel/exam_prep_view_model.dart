import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/models/quiz_question_model.dart';
import '../../../core/utils/utils.dart';
import '../../middleware/api_services.dart';
import 'auth_view_model.dart';
import 'base_model.dart';

import '../../middleware/api_service_deep.dart';

class ExamPrepViewModel extends BaseModel {
  TextEditingController topicController = TextEditingController();
  TextEditingController subjectController = TextEditingController();
  TextEditingController soCau = TextEditingController();
  TextEditingController ngonNgu = TextEditingController();
  TextEditingController level = TextEditingController();
  String age = '18';
  String cacheKey = '';
  String userLearningStyle =
      'visual,auditory,kinesthetic'; // Lưu phong cách học tập của người dùng
  double timeTrain = 0; // Thời gian luyện tập
  GoogleGenerativeServices generativeServices = GoogleGenerativeServices();
  final QuizGenerator quizGenerator = QuizGenerator();
  List<QuizQuestion> questionsCorrect = [];
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  AuthViewModel auth = AuthViewModel();
  bool friendGame = false;
  List<QuizQuestion> questions = [];
  Map<int, String?> selectedAnswers = {};
  int correctAnswers = 0;
  int incorrectAnswers = 0;
  int point = 1;
  int quangcao = 0;
  String userHistory = '';
  List<Map<String, dynamic>> quizData = [];
  // Fetch modules for the user's course ID
  Stream<QuerySnapshot> getModules(String courseId) {
    print("Fetching modules for course ID: $courseId"); // Debug print
    return firestore
        .collection('courses')
        .doc(courseId)
        .collection('modules')
        .snapshots();
  }

  // Fetch subjects based on the selected module
  Stream<QuerySnapshot<Map<String, dynamic>>> getSubjects(String moduleId) {
    print("Fetching subjects for module ID: $moduleId"); // Debug print
    return firestore
        .collection('modules')
        .doc(moduleId)
        .collection('subjects')
        .snapshots();
  }

  Future<List> generateQuestionsTrain() async {
    try {
      String topic = topicController.text;
      String subject = subjectController.text;

      String userid = auth!.emailController.text;

      if (subject.isEmpty) {
        subject = "văn học, lịch sử, địa lý";
      }

      if (topic.isEmpty) {
        topic = "Kiến thức phổ thông";
      }

      if (userid.isEmpty) {
        userid = "namnmhp89@gmail.com";
      }
      if (level.text.isEmpty) {
        level.text = 'hard';
      }
      if (ngonNgu.text.isEmpty) {
        ngonNgu.text = 'vi';
      }
      age = 'luyện tập';
      final questionsResponse = await quizGenerator.generateQuiz(
          topic: topic,
          subject: subject,
          difficulty: level.text,
          count: soCau.text.isEmpty ? 15 : int.parse(soCau.text),
          point: point,
          language: ngonNgu.text,
          age: age,
          answeredQuestions: questionsCorrect,
          time: timeTrain);

      questions =
          questionsResponse.map((item) => QuizQuestion.fromJson(item)).toList();
      print('NAMNM timeTrain $timeTrain');
      updateUI(); // Update UI with the retrieved summary
      notifyListeners();
      quangcao++;
      return questions;
    } catch (error) {
      // Handle potential errors during API call
      if (kDebugMode) {}
    }
    return [];
  }

  Future<List> generateQuestionsOver18() async {
    try {
      String topic = topicController.text;
      String subject = subjectController.text;

      String userid = auth!.emailController.text;
      if (subject.isEmpty) {
        subject = "văn học, lịch sử, địa lý";
      }

      if (topic.isEmpty) {
        topic = "Kiến thức phổ thông";
      }

      if (userid.isEmpty) {
        userid = "namnmhp89@gmail.com";
      }
      if (level.text.isEmpty) {
        level.text = 'hard';
      }
      if (ngonNgu.text.isEmpty) {
        ngonNgu.text = 'vi';
      }
      final questionsResponse = await quizGenerator.generateQuiz(
          topic: topic,
          subject: subject,
          difficulty: level.text,
          count: 15,
          point: point,
          language: ngonNgu.text,
          age: age,
          answeredQuestions: questionsCorrect);

      // final questionsResponse =
      //     await generativeServices.getquiz(constructPromptOver18(), '123');

      questions =
          questionsResponse.map((item) => QuizQuestion.fromJson(item)).toList();

      updateUI(); // Update UI with the retrieved summary
      notifyListeners();
      quangcao++;
      return questions;
    } catch (error) {
      // Handle potential errors during API call
      if (kDebugMode) {}
    }
    return [];
  }

  Future<List> generateQuestionsUnder10() async {
    try {
      String topic = topicController.text;
      String subject = subjectController.text;

      String userid = auth!.emailController.text;

      if (subject.isEmpty) {
        subject = "Giáo dục tiểu học";
      }

      if (topic.isEmpty) {
        topic = "Toán, Tiếng Việt, Khoa học, Đạo đức, Tự nhiên và Xã hội";
      }

      if (userid.isEmpty) {
        userid = "namnmhp89@gmail.com";
      }
      if (level.text.isEmpty) {
        level.text = 'hard';
      }
      if (ngonNgu.text.isEmpty) {
        ngonNgu.text = 'vi';
      }
      final questionsResponse = await quizGenerator.generateQuiz(
          topic: topic,
          subject: subject,
          difficulty: level.text,
          count: 15,
          point: point,
          language: ngonNgu.text,
          age: age,
          learning: userLearningStyle,
          userhistory: userHistory,
          answeredQuestions: questionsCorrect);
      print('NAMNM userHistory $userHistory');
      questions =
          questionsResponse.map((item) => QuizQuestion.fromJson(item)).toList();

      updateUI(); // Update UI with the retrieved summary
      notifyListeners();
      quangcao++;
      return questions;
    } catch (error) {
      // Handle potential errors during API call
      if (kDebugMode) {}
    }
    return [];
  }

  Future<List> generateQuestions10to18() async {
    try {
      String topic = topicController.text;
      String subject = subjectController.text;

      String userid = auth!.emailController.text;

      if (subject.isEmpty) {
        subject = "văn học, lịch sử, địa lý, sinh học";
      }

      if (topic.isEmpty) {
        topic = "Kiến thức phổ thông";
      }

      if (userid.isEmpty) {
        userid = "namnmhp89@gmail.com";
      }
      if (level.text.isEmpty) {
        level.text = 'hard';
      }
      if (ngonNgu.text.isEmpty) {
        ngonNgu.text = 'vi';
      }
      final questionsResponse = await quizGenerator.generateQuiz(
          topic: topic,
          subject: subject,
          difficulty: level.text,
          count: 15,
          point: point,
          language: ngonNgu.text,
          age: age,
          learning: userLearningStyle,
          answeredQuestions: questionsCorrect);

      questions =
          questionsResponse.map((item) => QuizQuestion.fromJson(item)).toList();

      updateUI(); // Update UI with the retrieved summary
      notifyListeners();
      quangcao++;
      return questions;
    } catch (error) {
      // Handle potential errors during API call
      if (kDebugMode) {}
    }
    return [];
  }

  void evaluateAnswers() {
    correctAnswers = 0;
    incorrectAnswers = 0;
    for (int i = 0; i < questions.length; i++) {
      String? selectedAnswer = selectedAnswers[i];
      if (selectedAnswer == questions[i].answer) {
        correctAnswers++;
      } else {
        incorrectAnswers++;
      }
    }
  }

  void resetQuiz() {
    questions.clear();
    selectedAnswers.clear();
    correctAnswers = 0;
    incorrectAnswers = 0;
  }

  Future<void> saveQuizToFirestore() async {
    try {
      await firestore
          .collection('users')
          .doc(auth.user!.uid)
          .collection('quizHistory')
          .add({
        'subject': subjectController.text,
        'topic': topicController.text,
        'questions': questions.map((q) => q.toJson()).toList(),
        'selectedAnswers': selectedAnswers
            .map((key, value) => MapEntry(key.toString(), value)),
        'timestamp': FieldValue.serverTimestamp(),
      });
      AppUtils.showSuccess('Lưu thành công');
      if (kDebugMode) {
        print('Quiz saved to Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving quiz to Firestore: $e');
      }
    }
  }

  Future<void> saveQuizToFriend(
      List<QuizQuestion> model, List<String> emailList) async {
    final batch = FirebaseFirestore.instance.batch();
    final currentUserEmail = AuthViewModel().useremail;

    for (final friendEmail in emailList) {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(friendEmail)
          .collection('quizHistoryFriend')
          .doc();
      batch.set(docRef, {
        'subject': subjectController.text,
        'topic': topicController.text,
        'questions': questions.map((q) => q.toJson()).toList(),
        'friendEmail': currentUserEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getQuizHistory() async {
    try {
      final snapshot = await firestore
          .collection('users')
          .doc(auth.user!.uid)
          .collection('quizHistory')
          .orderBy('timestamp', descending: true)
          .get();

      quizData = [];
      for (var doc in snapshot.docs) {
        quizData.add(doc.data());
      }

      return quizData;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting quiz history from Firestore: $e');
      }
      return [];
    }
  }

  Future<void> saveScoreToFirestore(int diem) async {
    try {
      final userDoc = firestore.collection('users').doc(auth.user!.uid);
      final userScoreCollection = userDoc.collection('userScores');

      // Lấy điểm hiện tại
      final snapshot = await userDoc.get();
      int currentScore = 0;
      if (snapshot.exists && snapshot.data()!.containsKey('totalScore')) {
        currentScore = snapshot.data()!['totalScore'];
      }

      // Cộng dồn điểm
      int newScore = currentScore + diem;

      // Cập nhật tổng điểm vào document của user
      await userDoc.set({'totalScore': newScore}, SetOptions(merge: true));

      // Lưu điểm mới vào subcollection 'userScores'
      await userScoreCollection.add({
        'score': diem,
        'timestamp': FieldValue.serverTimestamp(), // Thêm timestamp
      });

      AppUtils.showSuccess('Lưu thành công');
      if (kDebugMode) {
        print('Score saved to Firestore. Total score: $newScore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error saving score to Firestore: $e');
      }
    }
  }

  List<String> shuffleAnswers(QuizQuestion question, int questionIndex) {
    // Khởi tạo danh sách allOptions với câu trả lời đúng
    List<String> allOptions = [question.answer ?? 'Đáp án mẫu'];

    // Thêm các lựa chọn sai từ distractors (nếu có)
    if (question.distractors != null) {
      for (final distractor in question.distractors!) {
        if (distractor.content != null && distractor.content!.isNotEmpty) {
          allOptions.add(distractor.content!);
        }
      }
    }

    // Đảm bảo có ít nhất 4 lựa chọn
    while (allOptions.length < 4) {
      allOptions.add('Lựa chọn ${allOptions.length + 1}');
    }

    // Loại bỏ trùng lặp (nếu có)
    allOptions = allOptions.toSet().toList();

    // Trộn ngẫu nhiên danh sách
    allOptions.shuffle();

    return allOptions;
  }
}

extension on QuizQuestion {
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'hints': hints,
      'answer': answer,
      'explanation': explanation,
    };
  }
}
