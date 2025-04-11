import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Cho HapticFeedback
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/assets_constant.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/auth_view_model.dart';
import '../../../routes/routes.dart';
import '../../widgets/common_text_form_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCourseId;
  AuthViewModel? model;
  late AnimationController _mapController;
  int explorationXP = 0;
  int tapCount = 0;
  DateTime? lastTapTime;

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
      explorationXP = prefs.getInt('userXp') ?? 0;
    });
  }

  Future<void> _saveXP(int newXP) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userXp', newXP);
    setState(() {
      explorationXP = newXP;
    });
  }

  void _handleLogoTap() {
    final now = DateTime.now();
    if (lastTapTime != null && now.difference(lastTapTime!).inSeconds < 2) {
      tapCount++;
    } else {
      tapCount = 1;
    }
    lastTapTime = now;

    if (tapCount == 3) {
      setState(() {
        tapCount = 0;
        _saveXP(explorationXP + 25); // Rương ẩn
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rương bí mật mở: +25 XP!')),
        );
      });
    }
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
              body: buildRegistrationPage(context),
            ),
          ),
        );
      },
    );
  }

  Widget buildRegistrationPage(BuildContext context) {
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
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),
                GestureDetector(
                  onTapUp: (_) => _handleLogoTap(), // Rương ẩn khi nhấn logo
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: const DecorationImage(
                        image: AssetImage(
                            'assets/images/rune_border.png'), // Viền rune
                        fit: BoxFit.cover,
                        opacity: 0.3,
                      ),
                    ),
                    child: SizedBox(
                      height: 120,
                      width: 120,
                      child: Image.asset(
                        AssetConstant.applogo,
                        fit: BoxFit.contain,
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
                const SizedBox(height: 20),
                CommonTextFormField(
                  prefixIconWidget:
                      const Icon(Icons.person, color: Colors.black),
                  controller: model!.nameController,
                  hintTextWidget: 'Enter Your Username',
                ),
                const SizedBox(height: 10),
                CommonTextFormField(
                  prefixIconWidget:
                      const Icon(Icons.email, color: Colors.black),
                  controller: model!.emailController,
                  hintTextWidget: 'Enter Your Email',
                ),
                const SizedBox(height: 10),
                CommonTextFormField(
                  prefixIconWidget:
                      const Icon(Icons.password, color: Colors.black),
                  controller: model!.passwordController,
                  hintTextWidget: 'Enter Your Password',
                  obsocuringCharacter: '*',
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                _buildRegisterButton(
                  context,
                  'Register',
                  Colors.green,
                  () async {
                    String name = model!.nameController.text;
                    String email = model!.emailController.text;
                    String password = model!.passwordController.text;

                    if (name.isEmpty || email.isEmpty || password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill in all fields')),
                      );
                      return;
                    }

                    final credential =
                        await model!.registerWithEmailAndPassword(
                      name,
                      email,
                      password,
                    );
                    if (credential != null) {
                      _saveXP(explorationXP + 15); // Thưởng XP khi đăng ký
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Huy hiệu Tân binh mở khóa!')),
                      );
                      Navigator.pushNamed(context, Routes.homeRoute);
                    }
                  },
                ),
                const SizedBox(height: 10),
                _buildRegisterButton(
                  context,
                  'Sign In with Google',
                  Colors.red,
                  () async {
                    final credential = await model!.signInWithGoogle();
                    if (credential != null) {
                      _saveXP(
                          explorationXP + 20); // Thưởng nhiều hơn cho Google
                      Navigator.pushNamed(context, '/home');
                    }
                  },
                  icon: AssetConstant.googleIcon,
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account?',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () =>
                            Navigator.pushNamed(context, Routes.loginRoute),
                        child: const Text(
                          'Sign In',
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

  Widget _buildRegisterButton(
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
