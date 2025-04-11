import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'app/data/providers/viewmodel/theme_model.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'app/core/di/locator.dart';
import 'app/ui/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

// Khởi tạo FlutterLocalNotificationsPlugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final appDocumentDirectory = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDirectory.path);
  var quizBox = await Hive.openBox('quizHistory');

  try {
    final distractors = message.data['distractors'] != null
        ? jsonDecode(message.data['distractors']) as List<dynamic>
        : [];
    final quizData = {
      'question': message.data['question'] ??
          message.notification?.body ??
          'Không có câu hỏi',
      'distractors': distractors.cast<String>(),
      'answer': message.data['answer'] ?? 'Không có đáp án',
      'hint': message.data['hint'] ?? 'Không có gợi ý',
      'explanation': message.data['explanation'] ?? 'Không có giải thích',
      'timestamp': DateTime.now().toIso8601String(),
    };
    await quizBox.add(quizData);
    print('Lưu câu hỏi từ thông báo nền: ${quizData['question']}');

    // Hiển thị thông báo cục bộ
    await _showNotification(quizData['question'], quizData);
  } catch (e) {
    print('Lỗi khi lưu thông báo nền vào Hive: $e');
  } finally {
    await quizBox.close();
  }
}

// Hiển thị thông báo cục bộ
Future<void> _showNotification(
    String message, Map<String, dynamic> quizData) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'quiz_channel',
    'Quiz Notifications',
    channelDescription: 'Thông báo câu đố hàng ngày',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    'Đố bạn',
    message,
    platformChannelSpecifics,
    payload: jsonEncode(quizData), // Truyền toàn bộ quizData qua payload
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Khởi tạo Hive
  final appDocumentDirectory = await getApplicationDocumentsDirectory();
  Hive.init(appDocumentDirectory.path);
  await Hive.openBox('quizHistory');

  // Khởi tạo Flutter Local Notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload != null) {
        final quizData = jsonDecode(response.payload!) as Map<String, dynamic>;
        print('Nhấn vào thông báo: ${quizData['question']}');
        // final navigator = MyApp.navigatorKey.currentState;
        // if (navigator != null) {
        //   navigator.pushNamed(Routes.quizScreen, arguments: quizData);
        // }
      }
    },
  );

  // Yêu cầu quyền thông báo
  await FirebaseMessaging.instance.requestPermission();
  await FirebaseMessaging.instance.subscribeToTopic('quiz_users');
  print('Subscribed to quiz_users');

  await setUpLocator();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => locator<ThemeModel>()),
      ],
      child: const MyApp(),
    ),
  );

  // Xử lý thông báo khi app khởi động từ terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('Khởi động từ thông báo: ${message.notification?.body}');
      // _navigateToQuizScreen(message);
    }
  });

  // Xử lý thông báo khi app chạy foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Thông báo foreground: ${message.notification?.body}');
    final distractors =
        jsonDecode(message.data['distractors'] ?? '[]') as List<dynamic>;
    final quizData = {
      'question': message.data['question'] ??
          message.notification?.body ??
          'Không có câu hỏi',
      'distractors': distractors.cast<String>(),
      'answer': message.data['answer'] ?? 'Không có đáp án',
      'hint': message.data['hint'] ?? 'Không có gợi ý',
      'explanation': message.data['explanation'] ?? 'Không có giải thích',
    };
    _showNotification(quizData['question'], quizData);
  });

  // Xử lý khi nhấn thông báo từ background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Mở từ thông báo: ${message.notification?.body}');
    // _navigateToQuizScreen(message);
  });
}

// // Điều hướng tới màn hình quiz
// void _navigateToQuizScreen(RemoteMessage message) {
//   if (message.data['click_action'] == 'FLUTTER_NOTIFICATION_CLICK') {
//     final navigator = MyApp.navigatorKey.currentState;
//     if (navigator != null) {
//       navigator.pushNamed(Routes.quizScreen, arguments: message.data);
//       print('Điều hướng tới quiz_screen với dữ liệu: ${message.data}');
//     } else {
//       print('Navigator chưa sẵn sàng');
//     }
//   }
// }
