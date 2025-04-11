// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Cho HapticFeedback
import 'package:nemoai/app/core/constants/assets_constant.dart';
import 'package:nemoai/app/data/providers/viewmodel/auth_view_model.dart';
import 'package:nemoai/app/ui/widgets/common_text_form_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/utils.dart';
import '../../../data/providers/base_view.dart';
import '../../../routes/routes.dart';
import 'package:lottie/lottie.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  AuthViewModel? model;
  late AnimationController _mapController;
  int explorationXP = 0;

  @override
  void initState() {
    super.initState();
    _mapController = AnimationController(
      duration: const Duration(seconds: 20), // Bản đồ cuộn chậm
      vsync: this,
    )..repeat(reverse: true);
    _loadXP();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadXP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      explorationXP = prefs.getInt('explorationXP') ?? 0;
    });
  }

  Future<void> _saveXP(int newXP) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('explorationXP', newXP);
    setState(() {
      explorationXP = newXP;
    });
  }

  void _handleGuideTap() {
    setState(() {
      explorationXP += 20; // Rương ẩn
      _saveXP(explorationXP);
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rương bí mật mở: +20 XP!')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<AuthViewModel>(
      onModelReady: (model) {
        this.model = model;
      },
      builder: (context, model, child) {
        return SafeArea(
          child: GestureDetector(
            onTap: () {
              FocusManager.instance.primaryFocus?.unfocus();
              model.keyboard(false);
            },
            child: Scaffold(
              body: buildLoginPage(context),
            ),
          ),
        );
      },
    );
  }

  Widget buildLoginPage(BuildContext context) {
    return Stack(
      children: [
        AnimatedBuilder(
          animation: _mapController,
          builder: (_, __) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue[900]!.withOpacity(0.8),
                  Colors.blue[700]!.withOpacity(0.8),
                ],
              ),
              image: DecorationImage(
                image: const AssetImage(
                    'assets/images/adventure_map.png'), // Bản đồ nền
                fit: BoxFit.cover,
                alignment: AlignmentTween(
                  begin: Alignment(-0.1, 0.0),
                  end: Alignment(0.1, 0.0),
                ).evaluate(_mapController),
                opacity: 0.4,
              ),
            ),
          ),
        ),
        SingleChildScrollView(
          child: Form(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTapUp: (_) => _handleGuideTap(), // Rương ẩn khi nhấn Lottie
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: const DecorationImage(
                        image: AssetImage(
                            'assets/images/rune_border.png'), // Viền rune
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: Lottie.asset(
                          'assets/lottie/aiNemo.json',
                          fit: BoxFit.cover,
                          repeat: true,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'XP: $explorationXP',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.yellow, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 10),
                CommonTextFormField(
                  prefixIconWidget:
                      const Icon(Icons.email, color: Colors.white),
                  controller: model!.emailController,
                  hintTextWidget: 'Email',
                ),
                const SizedBox(height: 10),
                CommonTextFormField(
                  prefixIconWidget:
                      const Icon(Icons.password, color: Colors.white),
                  controller: model!.passwordController,
                  hintTextWidget: 'Password',
                  obsocuringCharacter: '*',
                  obscureText: true,
                  maxLines: 1,
                ),
                const SizedBox(height: 10),
                _buildLoginButton(context, 'Đăng nhập', Colors.green, () async {
                  String email = model!.emailController.text;
                  String password = model!.passwordController.text;

                  if (email.isEmpty || password.isEmpty) {
                    AppUtils.showError('Vui lòng nhập thông tin của bạn');
                    return;
                  }

                  final credential =
                      await model!.signInWithEmailAndPassword(email, password);
                  if (credential != null) {
                    _saveXP(explorationXP + 10); // Thưởng XP khi đăng nhập
                    Navigator.pushNamed(context, '/home');
                  }
                }),
                const SizedBox(height: 10),
                _buildLoginButton(context, 'Đăng nhập với Google', Colors.red,
                    () async {
                  final credential = await model!.signInWithGoogle();
                  if (credential != null) {
                    _saveXP(explorationXP + 15); // Thưởng nhiều hơn cho Google
                    Navigator.pushNamed(context, '/home');
                  }
                }, icon: AssetConstant.googleIcon),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Bạn chưa có tài khoản?',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.registerRoute),
                        child: const Text(
                          'Đăng ký',
                          style: TextStyle(
                            color: Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(
    BuildContext context,
    String title,
    Color baseColor,
    VoidCallback onTap, {
    String? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [baseColor, baseColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellow.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: baseColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Image.asset(icon, width: 24, height: 24),
                  ),
                ],
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
