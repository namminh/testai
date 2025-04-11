import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/auth_view_model.dart';
import 'package:nemoai/app/ui/screens/auth_screen/login_screen.dart';
import '../../../core/utils/utils.dart';
import '../exam_prep/Selection_game.dart';

class AuthStateScreen extends StatelessWidget {
  AuthStateScreen({super.key});
  final authViewModel = AuthViewModel();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: authViewModel.userState,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator()); // Loading indicator
          } else {
            return snapshot.hasData ? SubjectSelectionScreen() : LoginScreen();
          }
        },
      ),
    );
  }
}
