import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/topic_summarizer_view.dart';
import 'package:nemoai/app/ui/app.dart';
import 'package:nemoai/app/ui/screens/auth_screen/auth_screen.dart';
import 'package:nemoai/app/ui/screens/auth_screen/login_screen.dart';
import 'package:nemoai/app/ui/screens/auth_screen/register_screen.dart';
import 'package:nemoai/app/ui/screens/explain_topic_screen/topic_summarizer.dart';
import 'package:nemoai/app/ui/screens/home/home_page.dart';
import 'package:nemoai/app/ui/screens/onboarding_screen/onboard_screen.dart';
import 'package:nemoai/app/ui/screens/profile/profile_screen.dart';
import 'package:nemoai/app/ui/screens/splash_screen/splash_screen.dart';
import '../ui/screens/chat_screen/chat_screen.dart';
import '../ui/screens/exam_prep/exam_preparation.dart';
import '../ui/screens/exam_prep/questions_page.dart';
import '../ui/screens/exam_prep/question_game.dart';
import '../ui/screens/exam_prep/Selection_game.dart';
import '../ui/screens/exam_prep/board_screen.dart';
import '../ui/screens/exam_prep/friend_screen.dart';
import '../ui/screens/subcription/subcription_page.dart';

import '../ui/screens/settings_screen/settings_screen.dart';
import 'routes.dart';
import '../../app/ui/age_verifi.dart';

class PageRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case Routes.splashRoute:
        return MaterialPageRoute(builder: (context) => const SplashScreen());

      case Routes.onboardRoute:
        return MaterialPageRoute(builder: (context) => const Onboardscreen());
      case Routes.authRoute:
        return MaterialPageRoute(builder: (context) => AuthStateScreen());
      case Routes.homeRoute:
        return MaterialPageRoute(builder: (context) => const HomePage());
      case Routes.profileRoute:
        return MaterialPageRoute(builder: (context) => ProfileScreen());
      case Routes.topicRoute:
        return MaterialPageRoute(builder: (context) => TopicScreen());
      case Routes.examRoute:
        return MaterialPageRoute(builder: (context) => ExamPreparation());
      case Routes.topic:
        return MaterialPageRoute(builder: (context) => TopicScreen());

      case Routes.subcription:
        return MaterialPageRoute(builder: (context) => SubscriptionPage());
      case Routes.countdown:
        return MaterialPageRoute(
            builder: (context) => const LeaderboardScreen());
      case Routes.friend:
        return MaterialPageRoute(builder: (context) => FriendScreen());

      case Routes.quizRoute:
        return MaterialPageRoute(builder: (context) => const QuestionsPage());
      case Routes.quizGame:
        return MaterialPageRoute(builder: (context) => const QuestionsGame());
      case Routes.chatRoute:
        return MaterialPageRoute(builder: (context) => ChatScreen());
      case Routes.loginRoute:
        return MaterialPageRoute(builder: (context) => LoginScreen());
      case Routes.selection:
        return MaterialPageRoute(
            builder: (context) => SubjectSelectionScreen());

      case Routes.age:
        return MaterialPageRoute(
            builder: (context) => const AgeVerificationScreen());
      case Routes.registerRoute:
        return MaterialPageRoute(builder: (context) => const RegisterScreen());
      case Routes.settingsRoute:
        return MaterialPageRoute(builder: (context) => const SettingsScreen());
      default:
        return MaterialPageRoute(
            builder: (BuildContext conktext) => const Scaffold(
                  body: Text('This Page does not Exist'),
                ));
    }
  }
}
