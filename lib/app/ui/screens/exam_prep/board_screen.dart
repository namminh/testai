import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../../../core/utils/soundUtils.dart'; // Assuming you have this for sound effects

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  _LeaderboardScreenState createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  final int _pageSize = 10;
  DocumentSnapshot? _lastDocument;
  List<QueryDocumentSnapshot> _players = [];
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        setState(() {
          _errorMessage = 'Không có internet! Kiểm tra lại nhé!';
          _isLoading = false;
        });
        return;
      }
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('totalScore', descending: true)
          .limit(_pageSize)
          .get();
      setState(() {
        _players = snapshot.docs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _isLoading = false;
      });
      if (_players.isNotEmpty) {
        _confettiController.play(); // Celebrate leaderboard load
        SoundUtils.playSound(Sounds.correct); // Play a cheerful sound
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Oops! Có lỗi rồi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshData() async {
    await _loadInitialData();
    HapticFeedback.lightImpact(); // Feedback on refresh
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bảng Vàng Siêu Sao',
          style: TextStyle(
            fontFamily: 'FantasyFont',
            fontSize: 28,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white, size: 30),
            onPressed: _refreshData,
            tooltip: 'Làm mới bảng vàng!',
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange[400]!, // Bright, playful gradient
              Colors.red[400]!,
              Colors.yellow[300]!,
            ],
          ),
          image: const DecorationImage(
            image: AssetImage(
                'assets/images/treasure_background.png'), // Adventure theme
            fit: BoxFit.cover,
            opacity: 0.2,
          ),
        ),
        child: Stack(
          children: [
            _isLoading
                ? _buildLoadingWidget()
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _players.isEmpty
                        ? _buildEmptyWidget()
                        : _buildLeaderboardList(),
            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [
                  Colors.red,
                  Colors.yellow,
                  Colors.blue,
                  Colors.green
                ],
                emissionFrequency: 0.05,
                numberOfParticles: 30,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SpinKitFadingCube(color: Colors.white, size: 60),
          const SizedBox(height: 20),
          Text(
            'Đang tìm kiếm các siêu sao...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FantasyFont',
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 80, color: Colors.white70),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontFamily: 'FantasyFont',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow[600],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text(
              'Thử lại nào!',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'FantasyFont',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/empty_treasure.png', // Add a fun empty chest image
            width: 120,
            height: 120,
          ),
          const SizedBox(height: 16),
          const Text(
            'Chưa có siêu sao nào!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontFamily: 'FantasyFont',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy chơi để trở thành người đầu tiên!',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontFamily: 'FantasyFont',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return ListView.builder(
      itemCount: _players.length + 1,
      itemBuilder: (context, index) {
        if (index == _players.length) {
          return _lastDocument != null
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton(
                    onPressed: () async {
                      final snapshot = await FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('totalScore', descending: true)
                          .startAfterDocument(_lastDocument!)
                          .limit(_pageSize)
                          .get();
                      setState(() {
                        _players.addAll(snapshot.docs);
                        _lastDocument = snapshot.docs.isNotEmpty
                            ? snapshot.docs.last
                            : null;
                      });
                      SoundUtils.playSound(
                          Sounds.appstart); // Sound on load more
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[400],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Khám phá thêm!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'FantasyFont',
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink();
        }

        final playerData = _players[index].data() as Map<String, dynamic>;
        final playerName = playerData['name'] ?? 'Siêu Sao Ẩn Danh';
        final playerScore = playerData['totalScore'] ?? 0;
        final lastUpdated = playerData['lastUpdated'] as Timestamp?;

        return AnimatedLeaderboardTile(
          index: index,
          name: playerName,
          score: playerScore,
          lastUpdated: lastUpdated,
        );
      },
    );
  }
}

class AnimatedLeaderboardTile extends StatelessWidget {
  final int index;
  final String name;
  final int score;
  final Timestamp? lastUpdated;

  const AnimatedLeaderboardTile({
    Key? key,
    required this.index,
    required this.name,
    required this.score,
    this.lastUpdated,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      padding: EdgeInsets.symmetric(
          horizontal: 16.0, vertical: index < 3 ? 8.0 : 4.0),
      child: Card(
        elevation: index < 3 ? 8 : 4, // Higher elevation for top 3
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _getRankColor(index), width: 2),
        ),
        color: Colors.white.withOpacity(0.9),
        child: ListTile(
          leading: _buildRankIcon(index),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    fontFamily: 'FantasyFont',
                    shadows: [Shadow(color: Colors.grey[400]!, blurRadius: 2)],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (index < 3) // Crown for top 3
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child:
                      Icon(Icons.star, color: _getRankColor(index), size: 20),
                ),
            ],
          ),
          subtitle: lastUpdated != null
              ? Text(
                  'Cập nhật: ${DateFormat('dd/MM').format(lastUpdated!.toDate())}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on, color: Colors.yellow[700], size: 24),
              const SizedBox(width: 4),
              Text(
                formatCurrency(score * 1000),
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'FantasyFont',
                ),
              ),
            ],
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Chúc mừng $name! Điểm: ${formatCurrency(score * 1000)}')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankIcon(int index) {
    final rankColors = [
      Colors.yellow[800]!,
      Colors.grey[400]!,
      Colors.brown[400]!
    ];
    final rankIcons = [
      Icons.emoji_events, // Gold trophy
      Icons.star, // Silver star
      Icons.star_half, // Bronze half-star
    ];

    if (index < 3) {
      return AnimatedScale(
        scale: 1.1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: CircleAvatar(
          backgroundColor: rankColors[index],
          child: Icon(rankIcons[index], color: Colors.white, size: 28),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: Colors.blue[200],
      child: Text(
        '${index + 1}',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: 'FantasyFont',
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.yellow[800]!;
      case 1:
        return Colors.grey[400]!;
      case 2:
        return Colors.brown[400]!;
      default:
        return Colors.blue[300]!;
    }
  }
}

String formatCurrency(int amount) {
  final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  return formatter.format(amount);
}
