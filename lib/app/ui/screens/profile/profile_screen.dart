import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/assets_constant.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/auth_view_model.dart';
import '../../widgets/custom_listtile.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import '../home/home_widget/app_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseView<AuthViewModel>(
      onModelReady: (model) {},
      builder: (context, model, child) => Scaffold(
        appBar: HomeAppBar(
          title: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                colors: [Colors.amber[300]!, Colors.white],
                stops: const [0.0, 0.7],
              ).createShader(bounds);
            },
            child: const Text(
              'Sảnh Vinh Danh',
              style: TextStyle(
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue[900]!,
                    Colors.blue[600]!,
                    Colors.yellow[800]!,
                  ],
                ),
              ),
              child: SafeArea(child: _buildProfilePage(context, model)),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Lottie.asset(
                'assets/lottie/aiNemo.json',
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                repeat: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePage(BuildContext context, AuthViewModel model) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 32),
          _UserInfoWidget(model: model),
          const SizedBox(height: 40),
          _buildAchievements(model),
          const SizedBox(height: 40),
          _buildLogoutButton(context, model),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAchievements(AuthViewModel model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Huy Hiệu Vinh Quang',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'FantasyFont',
              shadows: [
                Shadow(color: Colors.amber, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(model.useriid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(
                  child: Text(
                    'Chưa có huy hiệu nào!\nChinh phục thử thách để nhận ngay!',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final badges = (userData['badges'] as List<dynamic>?) ?? [];
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children:
                    badges.map((badge) => _BadgeItem(badge: badge)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthViewModel model) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: GestureDetector(
        onTap: () async {
          bool? confirm = await _showConfirmDialog(context);
          if (confirm == true) {
            _handleSignOut(context, model);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[900]!, Colors.red[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomListTile(
            leading:
                const Icon(Icons.logout_rounded, color: Colors.white, size: 28),
            title: 'Rời Cuộc Phiêu Lưu',
            subtitle: 'Thoát khỏi hành trình',
            trailing: const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white),
            titleStyle: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'FantasyFont',
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        content: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[900]!, Colors.blue[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.7), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Rời Cuộc Phiêu Lưu?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FantasyFont',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Bạn có chắc muốn rời bỏ hành trình này không?',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ở lại',
                        style: TextStyle(color: Colors.white)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Rời đi',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context, AuthViewModel model) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Lottie.asset(
          'assets/lottie/logout_animation.json', // Thêm animation logout nếu có
          width: 100,
          height: 100,
        ),
      ),
    );
    try {
      await model.signOut();
      if (!context.mounted) return;
      Navigator.pop(context);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã rời cuộc phiêu lưu!\nHẹn gặp lại, dũng sĩ!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }
}

class _UserInfoWidget extends StatefulWidget {
  final AuthViewModel model;

  const _UserInfoWidget({required this.model});

  @override
  _UserInfoWidgetState createState() => _UserInfoWidgetState();
}

class _UserInfoWidgetState extends State<_UserInfoWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _confettiController.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Column(
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.amber[400]!, Colors.orange[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.6),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 3),
                ),
                padding: const EdgeInsets.all(10),
                child: CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white,
                  backgroundImage: widget.model.userphoto != null &&
                          widget.model.userphoto!.isNotEmpty
                      ? NetworkImage(widget.model.userphoto!)
                      : const AssetImage(AssetConstant.profileIcon)
                          as ImageProvider,
                ),
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.model.useriid)
                  .snapshots(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                if (snapshot.hasError) {
                  return Text('Lỗi: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 16));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.amber));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return const Text('Không tìm thấy dữ liệu',
                      style: TextStyle(color: Colors.white, fontSize: 16));
                }
                final userData = snapshot.data!.data() as Map<String, dynamic>;

                final xp = (userData['totalScore'] as int? ?? 0) * 100;
                final level = (xp ~/ 1000) + 1; // Giả lập level dựa trên XP
                final xpToNextLevel = 1000;

                return Column(
                  children: [
                    Text(
                      'Dũng Sĩ: ${userData['name'] ?? 'Không có tên'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'FantasyFont',
                        shadows: [
                          Shadow(color: Colors.amber, blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userData['email'] ?? 'Không có email',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.8), fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stars, color: Colors.yellow[200], size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Level $level - $xp XP',
                          style: TextStyle(
                            color: Colors.yellow[200],
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'FantasyFont',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 200,
                      height: 10,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: Colors.grey[800],
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        width: 200 * ((xp % 1000) / 1000),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.amber[400]!, Colors.orange[800]!],
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${xp % 1000}/$xpToNextLevel XP tới Level ${level + 1}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: const [Colors.green, Colors.yellow, Colors.blue, Colors.red],
          particleDrag: 0.05,
          emissionFrequency: 0.02,
          numberOfParticles: 20,
        ),
      ],
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final dynamic badge;

  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow[800]!, Colors.amber[600]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Icon(Icons.star, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 8),
              Text(
                badge.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FantasyFont',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
