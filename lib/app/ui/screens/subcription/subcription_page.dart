import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../../../routes/routes.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage>
    with SingleTickerProviderStateMixin {
  final PurchaseService _purchaseService = PurchaseService();
  String _purchaseStatus = 'Chưa mua';
  bool _isLoading = false;
  int _xpPoints = 0;
  int _coins = 0;
  late AnimationController _animationController;
  late Animation<double> _buttonScale;
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _buttonScale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _purchaseService.init().then((_) {
      setState(() {
        _purchaseStatus = _purchaseService.isAvailable
            ? 'Sẵn sàng nâng cấp!'
            : 'Dịch vụ không khả dụng';
      });
      _checkPurchaseStatus();
    });

    _purchaseService.onPurchaseUpdated = (status) {
      setState(() {
        _purchaseStatus = status;
        _isLoading = status == 'Đang xử lý';
        if (status.contains('Mua thành công')) {
          _xpPoints += 100;
          _coins += 50;
          _confettiController.play();
          _showRewardDialog();
          _navigateToQuizGame();
        }
      });
    };
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    _purchaseService.dispose();
    super.dispose();
  }

  Future<void> _checkPurchaseStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('purchases')
          .where('userId', isEqualTo: userId)
          .where('productId', isEqualTo: 'aiquiz_basic_30day')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final purchaseData = querySnapshot.docs.first.data();
        final timestamp = (purchaseData['timestamp'] as Timestamp).toDate();
        final expiryDate = timestamp.add(const Duration(days: 30));
        if (DateTime.now().isBefore(expiryDate)) {
          _navigateToQuizGame();
        } else {
          setState(() {
            _purchaseStatus = 'Gói đã hết hạn';
          });
        }
      }
    } catch (e) {
      setState(() {
        _purchaseStatus = 'Lỗi kiểm tra trạng thái: $e';
      });
    }
  }

  void _navigateToQuizGame() {
    Navigator.pushNamed(context, Routes.quizRoute);
  }

  void _showRewardDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[900]!, Colors.blue[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withOpacity(0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie/reward.json', // Thêm animation phần thưởng nếu có
                width: 100,
                height: 100,
              ),
              const SizedBox(height: 16),
              const Text(
                'Chúc mừng, Dũng sĩ VIP!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'FantasyFont',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Bạn nhận được:',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.yellow[200], size: 30),
                  const SizedBox(width: 8),
                  Text(
                    '+100 XP',
                    style: TextStyle(fontSize: 18, color: Colors.yellow[200]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.monetization_on, color: Colors.amber, size: 30),
                  const SizedBox(width: 8),
                  Text(
                    '+50 Coins',
                    style: const TextStyle(fontSize: 18, color: Colors.amber),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Tiếp tục phiêu lưu',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Cửa Hàng Báu Vật',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'FantasyFont',
            shadows: [
              Shadow(color: Colors.amber, blurRadius: 8),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple[900]!, Colors.blue[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple[900]!, Colors.blue[800]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Trạng thái mua
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _purchaseStatus.contains('Mua thành công')
                                ? Icons.check_circle
                                : _isLoading
                                    ? Icons.hourglass_empty
                                    : Icons.info,
                            color: Colors.amber,
                            size: 30,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _purchaseStatus,
                              style: const TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'FantasyFont',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Thông tin gói VIP
                    AnimatedScale(
                      scale: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[800]!, Colors.blue[600]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amber, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Gói VIP 30 Ngày',
                              style: TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'FantasyFont',
                                shadows: [
                                  Shadow(color: Colors.amber, blurRadius: 8),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_open,
                                    color: Colors.white70, size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  'Mở khóa tính năng độc quyền',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white70),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.star,
                                    color: Colors.yellow[200], size: 24),
                                const SizedBox(width: 8),
                                const Text(
                                  '+100 XP & +50 Coins',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.yellow),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Nút mua
                    _isLoading
                        ? Lottie.asset(
                            'assets/lottie/loading.json', // Thêm animation loading nếu có
                            width: 80,
                            height: 80,
                          )
                        : MouseRegion(
                            onEnter: (_) => _animationController.forward(),
                            onExit: (_) => _animationController.reverse(),
                            child: ScaleTransition(
                              scale: _buttonScale,
                              child: ElevatedButton(
                                onPressed: _purchaseService.isAvailable
                                    ? () async {
                                        setState(() {
                                          _isLoading = true;
                                          _purchaseStatus = 'Đang xử lý';
                                        });
                                        try {
                                          await _purchaseService
                                              .buySubscription(
                                                  'aiquiz_basic_30day');
                                        } catch (e) {
                                          setState(() {
                                            _isLoading = false;
                                            _purchaseStatus = 'Lỗi: $e';
                                          });
                                        }
                                      }
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 50, vertical: 20),
                                  backgroundColor: Colors.amber,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 5,
                                  shadowColor: Colors.amber.withOpacity(0.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.upgrade,
                                        color: Colors.white, size: 24),
                                    SizedBox(width: 10),
                                    Text(
                                      'Nâng cấp ngay',
                                      style: TextStyle(
                                        fontSize: 20,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'FantasyFont',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                    const SizedBox(height: 30),
                    // Hiển thị điểm thưởng
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.amber.withOpacity(0.7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star, color: Colors.yellow[200], size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'XP: $_xpPoints',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.yellow),
                          ),
                          const SizedBox(width: 16),
                          Icon(Icons.monetization_on,
                              color: Colors.amber, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Coins: $_coins',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.yellow,
              Colors.blue,
              Colors.purple,
              Colors.orange
            ],
            particleDrag: 0.05,
            emissionFrequency: 0.02,
            numberOfParticles: 30,
          ),
        ],
      ),
    );
  }
}

class PurchaseService {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  Function(String)? onPurchaseUpdated;

  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    _isAvailable = await _inAppPurchase.isAvailable();
    if (!_isAvailable) {
      _updateStatus('In-app purchase không khả dụng');
      return;
    }
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription.cancel(),
      onError: (error) => _updateStatus('Lỗi lắng nghe giao dịch: $error'),
    );
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    const Set<String> productIds = {'aiquiz_basic_30day'};
    final response = await _inAppPurchase.queryProductDetails(productIds);
    if (response.notFoundIDs.isNotEmpty) {
      _updateStatus('Không tìm thấy sản phẩm: ${response.notFoundIDs}');
      return;
    }
    if (response.error != null) {
      _updateStatus('Lỗi khi tải sản phẩm: ${response.error}');
      return;
    }
    _products = response.productDetails;
    _updateStatus('Đã tải sản phẩm thành công');
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _updateStatus('Giao dịch đang chờ xử lý');
          break;
        case PurchaseStatus.error:
          _updateStatus('Lỗi giao dịch: ${purchaseDetails.error?.message}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final purchaseToken = purchaseDetails.purchaseID ?? 'Không có token';
          _updateStatus('Mua thành công! Purchase Token: $purchaseToken');
          _savePurchaseToken(purchaseToken);
          if (purchaseDetails.pendingCompletePurchase) {
            _inAppPurchase.completePurchase(purchaseDetails);
          }
          break;
        case PurchaseStatus.canceled:
          _updateStatus('Giao dịch đã bị hủy');
          break;
      }
    }
  }

  Future<void> _savePurchaseToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      await FirebaseFirestore.instance.collection('purchases').add({
        'token': token,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
        'productId': 'aiquiz_basic_30day',
      });
      print('Lưu token vào Firestore thành công: $token');
    } catch (e) {
      print('Lỗi khi lưu token vào Firestore: $e');
      _updateStatus('Lỗi lưu token: $e');
    }
  }

  Future<void> buySubscription(String productId) async {
    if (_products.isEmpty) {
      _updateStatus('Không có sản phẩm để mua');
      throw Exception('Danh sách sản phẩm trống');
    }
    final product = _products.firstWhere((element) => element.id == productId);
    final purchaseParam = PurchaseParam(productDetails: product);
    await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  void _updateStatus(String status) {
    print(status);
    onPurchaseUpdated?.call(status);
  }

  void dispose() {
    _subscription.cancel();
  }
}
