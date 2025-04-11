import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/models/card.dart'; // Assuming this is the correct Cards model
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../../dir_helper.dart';

import 'dart:async';

import 'package:flutter/services.dart';
import 'card_detail.dart';

class CardBattleScreen extends StatefulWidget {
  final List<Cards> playerCards;
  final Function(List<Cards> resultCards, List<Cards> lostCards)
      onBattleEnd; // Updated callback

  const CardBattleScreen(
      {required this.playerCards, required this.onBattleEnd, Key? key})
      : super(key: key);

  @override
  _CardBattleScreenState createState() => _CardBattleScreenState();
}

class _CardBattleScreenState extends State<CardBattleScreen> {
  final Random _random = Random();
  late List<Cards> aiCards;
  List<Cards?> playerBoard = List.filled(6, null);
  List<Cards?> aiBoard = List.filled(6, null);
  bool battleStarted = false;
  bool isLoading = true;
  final random = Random();

  static const String _apiKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY'; // Your API key
  final _models = GenerativeModel(
    model:
        'gemini-2.0-flash-exp-image-generation', // Updated to a real model (gemini-2.0-flash-exp-image-generation doesn’t exist yet)
    apiKey: _apiKey,
    generationConfig: GenerationConfig(
      temperature: 0.35,
      topP: 0.95,
      maxOutputTokens: 10000,
      responseMimeType: 'application/json',
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeAICards();
  }

  Future<void> _initializeAICards() async {
    setState(() => isLoading = true);
    aiCards = await _generateAICards();
    _autoPlaceCards();
    setState(() => isLoading = false);
  }

  Future<List<Cards>> _generateAICards() async {
    final List<Cards> generatedCards = [];
    while (generatedCards.length < 6) {
      final card = await _generateCard(_random.nextInt(3) + 1,
          isAI: true); // Boost AI stats
      generatedCards.add(card);
    }
    return generatedCards;
  }

  Map<String, dynamic> _generatePrompt(int rarity, {bool isAI = false}) {
    final types = [
      'Destroyer', // Đối nghịch Explorer: Hủy diệt thay vì khám phá
      'Raider', // Đối nghịch Guardian: Tấn công thay vì bảo vệ
      'Sorcerer', // Đối nghịch Mystic: Phép thuật đen tối thay vì tri thức
      'Deceiver', // Đối nghịch Trickster: Lừa dối nguy hiểm hơn
      'Beastslayer', // Đối nghịch Beastmaster: Sát thủ thú thay vì thuần hóa
      'Chaosweaver', // Đối nghịch Elementalist: Hỗn loạn thay vì điều khiển
    ];
    // Nguyên tố giữ nguyên, nhưng sẽ được mô tả khác nhau
    final elements = ['Kim', 'Mộc', 'Thủy', 'Hỏa', 'Thổ', 'Băng', 'Sét'];

    // Tính từ đối lập: AI mang sắc thái hung dữ, người chơi mang sắc thái tích cực
    final adjectives = isAI
        ? {
            1: [
              'Tàn Nhẫn',
              'Xảo Quyệt',
              'Cuồng Loạn'
            ], // Thường, nhưng nguy hiểm
            2: ['Hắc Ám', 'Tàn Bạo', 'Khát Máu'], // Hiếm, đáng sợ
            3: ['Diệt Thế', 'Hủy Diệt', 'Ma Quái'], // Epic, kinh hoàng
          }
        : {
            1: ['Nhỏ Bé', 'Dũng Cảm', 'Tò Mò'], // Thường, tích cực
            2: ['Linh Thiêng', 'Bí Ẩn', 'Kỳ Diệu'], // Hiếm, cao quý
            3: ['Huyền Thoại', 'Vĩnh Cửu', 'Thần Thánh'], // Epic, vĩ đại
          };

    final type = types[_random.nextInt(types.length)];
    final element = elements[_random.nextInt(elements.length)];
    final adjective =
        adjectives[rarity]![_random.nextInt(adjectives[rarity]!.length)];
    final name = '$type $adjective $element';

    // Chỉ số đối lập: AI mạnh thủ nếu người chơi mạnh công và ngược lại
    final attackBoost =
        isAI ? _random.nextInt(25) : 0; // Tăng ngẫu nhiên cho AI
    final defenseBoost =
        isAI ? _random.nextInt(20) : 0; // Tăng ngẫu nhiên cho AI
    final baseAttack = rarity * 15 + _random.nextInt(25);
    final baseDefense = rarity * 12 + _random.nextInt(20);

    return {
      'name': name,
      'description': isAI
          ? 'Một $type $adjective gieo rắc hỗn loạn từ vùng $element tăm tối.'
          : 'Một $type $adjective từ vùng đất $element của Eldoria.',
      'type': type,
      'attack': isAI
          ? baseDefense + attackBoost // AI mạnh công khi người chơi mạnh thủ
          : baseAttack + attackBoost,
      'defense': isAI
          ? baseAttack + defenseBoost // AI mạnh thủ khi người chơi mạnh công
          : baseDefense + defenseBoost,
      'element': element,
      'effect': rarity > 1
          ? (isAI
              ? (type == 'Raider'
                  ? 'Tăng 15% sát thương xuyên giáp'
                  : 'Gây hiệu ứng ngẫu nhiên bất lợi cho kẻ thù')
              : (type == 'Guardian'
                  ? 'Chặn 15% sát thương cho đồng minh'
                  : 'Tăng 20% sát thương hệ $element'))
          : null,
    };
  }

  Future<String> _generateAndSaveImage(String name, int rarity, String type,
      String element, int attack, int defense) async {
    String directory = await DirHelper.getAppPath();
    String imagePath = '$directory/card_$name.png';
    final file = File(imagePath);

    try {
      final geminiResponse = await _models.generateContent([
        Content.text(
          'Generate an image of a fantasy $type card named "$name" with '
          '${rarity == 1 ? 'common' : rarity == 2 ? 'rare' : 'epic'} rarity. '
          'Describe its appearance and theme in detail (e.g., colors, symbols, background), '
          'then provide the image.'
          'Return the result in JSON format with "description" and "image" fields where "image" is a direct URL to the generated image.',
        ),
      ]);

      final responseText = geminiResponse.text ?? '{}';
      _logLargeString('NAMNM Gemini response', responseText);

      dynamic decodedResponse;
      try {
        decodedResponse = jsonDecode(responseText);
      } catch (e) {
        print('NAMNM JSON decode failed: $e');
        decodedResponse = {};
      }

      Map<String, dynamic> jsonResponse;
      if (decodedResponse is Map<String, dynamic>) {
        jsonResponse = decodedResponse;
      } else if (decodedResponse is List && decodedResponse.isNotEmpty) {
        jsonResponse = decodedResponse[0] as Map<String, dynamic>;
        print('NAMNM JSON is a list, using first element: $jsonResponse');
      } else {
        jsonResponse = {
          'description': 'Invalid response from Gemini',
          'image': null
        };
        print('NAMNM Unexpected JSON format: $decodedResponse');
      }

      // Ánh xạ các trường từ Gemini
      final description = jsonResponse['description'] as String? ??
          'A fantasy card with unique design.';
      String? imageUrl = jsonResponse['image'] as String?;

      // Nếu image không phải URL mà là prompt, gọi Pollinations AI
      if (imageUrl != null && !imageUrl.startsWith('http')) {
        print(
            'NAMNM Image field is a prompt, generating URL with Pollinations AI');
        imageUrl =
            'https://image.pollinations.ai/prompt/${Uri.encodeComponent(imageUrl)}';
      }

      if (imageUrl != null && imageUrl.startsWith('http')) {
        print('NAMNM Downloading image from: $imageUrl');
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          final contentType = response.headers['content-type'];
          print('NAMNM Content-Type: $contentType');
          if (contentType?.contains('image') == true) {
            final imageBytes = response.bodyBytes;
            if (!await file.exists()) {
              await file.create(recursive: true);
            }
            await file.writeAsBytes(imageBytes);
            print('NAMNM Saved image to: $imagePath');
          } else {
            print(
                'NAMNM URL did not return an image, Content-Type: $contentType');
          }
        } else {
          print(
              'NAMNM Failed to download image from URL: $imageUrl, Status: ${response.statusCode}');
        }
      } else {
        print('NAMNM No valid image URL provided');
      }
    } catch (e) {
      print('NAMNM: Error in _generateAndSaveImage: $e');
      // Tạo ảnh mặc định nếu lỗi
      imagePath = '$directory/adventure_map.png';
      if (!await file.exists()) {
        await file.create(recursive: true);
        // Giả lập ghi ảnh mặc định (thay bằng asset thực tế nếu có)
        await file.writeAsBytes(Uint8List(0));
      }
    }

    return imagePath;
  }

  void _logLargeString(String prefix, String text) {
    const int chunkSize = 1000; // Giới hạn mỗi đoạn log
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = i + chunkSize < text.length ? i + chunkSize : text.length;
      print('$prefix [${i ~/ chunkSize}]: ${text.substring(i, end)}');
    }
  }

  Future<Cards> _generateCard(int rarity, {bool isAI = false}) async {
    final promptData = _generatePrompt(rarity, isAI: isAI);
    final name = promptData['name']! as String;
    final description = promptData['description']! as String;
    final type = promptData['type']! as String;
    final attack = promptData['attack']! as int;
    final defense = promptData['defense']! as int;
    final element = promptData['element']! as String;
    final effect = promptData['effect'] as String?;
    final imagePath = await _generateAndSaveImage(
        name, rarity, type, element, attack, defense);

    return Cards(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      imagePath: imagePath,
      rarity: rarity,
      type: type,
      attack: attack,
      defense: defense,
      element: element,
      effect: effect,
    );
  }

  void _autoPlaceCards() {
    final availablePlayerCards = [...widget.playerCards];
    final availableAICards = [...aiCards];

    final sortedByDefense = [...availablePlayerCards]
      ..sort((a, b) => b.defense.compareTo(a.defense));
    final sortedByAttack = [...availablePlayerCards]
      ..sort((a, b) => b.attack.compareTo(a.attack));

    playerBoard = List.filled(6, null);
    // Đặt thẻ thủ trước
    for (int i = 0; i < 3 && i < sortedByDefense.length; i++) {
      playerBoard[i] = sortedByDefense[i];
      availablePlayerCards.remove(sortedByDefense[i]); // Loại thẻ đã dùng
    }
    // Đặt thẻ công từ danh sách còn lại
    final remainingByAttack = [...availablePlayerCards]
      ..sort((a, b) => b.attack.compareTo(a.attack));
    for (int i = 0; i < 3 && i < remainingByAttack.length; i++) {
      playerBoard[i + 3] = remainingByAttack[i];
    }

    // Tương tự cho AI
    final aiSortedByDefense = [...availableAICards]
      ..sort((a, b) => b.defense.compareTo(a.defense));
    final aiSortedByAttack = [...availableAICards]
      ..sort((a, b) => b.attack.compareTo(a.attack));

    aiBoard = List.filled(6, null);
    for (int i = 0; i < 3 && i < aiSortedByDefense.length; i++) {
      aiBoard[i] = aiSortedByDefense[i];
      availableAICards.remove(aiSortedByDefense[i]);
    }
    final aiRemainingByAttack = [...availableAICards]
      ..sort((a, b) => b.attack.compareTo(a.attack));
    for (int i = 0; i < 3 && i < aiRemainingByAttack.length; i++) {
      aiBoard[i + 3] = aiRemainingByAttack[i];
    }
  }

  Future<void> _startBattle() async {
    setState(() => battleStarted = true);

    int playerWinsCount = 0;
    int aiWinsCount = 0;
    List<Cards> lostCards = [];

    for (int i = 0; i < 3; i++) {
      // Player Attack vs AI Defense
      final playerAttackCard = playerBoard[i + 3];
      final aiDefenseCard = aiBoard[i];
      if (playerAttackCard != null && aiDefenseCard != null) {
        double playerAttack = playerAttackCard.attack.toDouble();
        double aiDefense = aiDefenseCard.defense.toDouble();
        // Áp dụng hiệu ứng nếu có
        if (playerAttackCard.effect?.contains('Tăng') == true) {
          playerAttack *= 1.2; // Ví dụ: Tăng 20% sát thương
        }
        if (aiDefenseCard.effect?.contains('Chặn') == true) {
          aiDefense *= 1.15; // Ví dụ: Chặn 15% sát thương
        }
        if (playerAttack > aiDefense) {
          playerWinsCount++;
        } else {
          lostCards.add(playerAttackCard);
        }
      }

      // AI Attack vs Player Defense
      final aiAttackCard = aiBoard[i + 3];
      final playerDefenseCard = playerBoard[i];
      if (aiAttackCard != null && playerDefenseCard != null) {
        double aiAttack = aiAttackCard.attack.toDouble();
        double playerDefense = playerDefenseCard.defense.toDouble();
        if (aiAttackCard.effect?.contains('xuyên giáp') == true) {
          aiAttack *= 1.15; // Ví dụ: Tăng 15% sát thương xuyên giáp
        }
        if (playerDefenseCard.effect?.contains('Chặn') == true) {
          playerDefense *= 1.15;
        }
        if (aiAttack > playerDefense) {
          aiWinsCount++;
          lostCards.add(playerDefenseCard);
        }
      }
    }

    final playerWins = playerWinsCount > aiWinsCount;
    final resultCards = await _determineOutcome(playerWins);
    await _showBattleResultDialog(
        playerWinsCount, aiWinsCount, [], playerWins, resultCards, lostCards);
  }

  Future<List<Cards>> _determineOutcome(bool playerWins) async {
    if (playerWins) {
      final epicCard =
          await _generateCard(3); // Generate an Epic card (rarity 3)
      return [epicCard];
    }
    return []; // On loss, return empty list to signal clearing playerCards
  }

  Future<void> _showBattleResultDialog(
    int playerWinsCount,
    int aiWinsCount,
    List<String> battleDetails, // Không dùng nữa, thay bằng matchups
    bool playerWins,
    List<Cards> resultCards,
    List<Cards> lostCards,
  ) async {
    // Tạo danh sách 10 cặp đấu
    List<Map<String, Cards?>> matchups = [];
    for (int i = 0; i < 3; i++) {
      matchups.add({
        'playerAttack': playerBoard[i + 3], // Công bạn (slots 5-9)
        'aiDefense': aiBoard[i], // Thủ AI (slots 0-4)
      });
      matchups.add({
        'aiAttack': aiBoard[i + 3], // Công AI (slots 5-9)
        'playerDefense': playerBoard[i], // Thủ bạn (slots 0-4)
      });
    }

    // Hiển thị từng cặp lần lượt
    int currentIndex = 0;

    while (currentIndex < matchups.length) {
      final matchup = matchups[currentIndex];
      final playerAttack = matchup['playerAttack'];
      final aiDefense = matchup['aiDefense'];
      final aiAttack = matchup['aiAttack'];
      final playerDefense = matchup['playerDefense'];

      Cards? attackCard;
      Cards? defenseCard;
      bool isPlayerAttack = false;

      if (playerAttack != null && aiDefense != null) {
        attackCard = playerAttack;
        defenseCard = aiDefense;
        isPlayerAttack = true;
      } else if (aiAttack != null && playerDefense != null) {
        attackCard = aiAttack;
        defenseCard = playerDefense;
        isPlayerAttack = false;
      }

      if (attackCard != null && defenseCard != null) {
        await showDialog(
          context: context,
          barrierDismissible:
              false, // Không cho tắt dialog bằng cách nhấn ngoài
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.blueGrey[800]!,
                    Colors.blueGrey[600]!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Trận ${currentIndex + 1}/6',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMatchupRow(attackCard!, defenseCard!,
                      isPlayerAttack: isPlayerAttack),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Chuyển sang cặp tiếp theo
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.orange[700],
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Tiếp tục',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
      currentIndex++;
    }

    // Hiển thị kết quả cuối cùng
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: playerWins
                  ? [Colors.green[800]!, Colors.green[400]!]
                  : (playerWinsCount == aiWinsCount
                      ? [Colors.grey[800]!, Colors.grey[600]!]
                      : [Colors.red[800]!, Colors.red[400]!]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                playerWins
                    ? 'Chiến Thắng!'
                    : (playerWinsCount == aiWinsCount ? 'Hòa!' : 'Thất Bại!'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bạn thắng: $playerWinsCount trận',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              Text(
                'AI thắng: $aiWinsCount trận',
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                playerWins
                    ? 'Bạn đã đánh bại AI và nhận được một thẻ bài Epic!'
                    : (playerWinsCount == aiWinsCount
                        ? 'Trận đấu kết thúc hòa, không mất thẻ bài!'
                        : 'Bạn đã thua và mất ${lostCards.length} thẻ bài!'),
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              if (lostCards.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Thẻ bị mất: ${lostCards.map((c) => c.name).join(", ")}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (playerWins && resultCards.isNotEmpty) {
                await showDialog(
                  context: context,
                  builder: (_) => CardRewardDialog(card: resultCards[0]),
                );
              }
              Navigator.pop(context);
              widget.onBattleEnd(resultCards, lostCards);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text(
              'Xác Nhận',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

// Hàm hiển thị cặp đấu
  Widget _buildMatchupRow(Cards attackCard, Cards defenseCard,
      {required bool isPlayerAttack}) {
    final bool attackWins = attackCard.attack > defenseCard.defense;
    final loserCard = attackWins ? defenseCard : attackCard;

    // Tính toán kết quả trận đấu
    final String resultText = attackWins
        ? 'Thắng (${attackCard.attack} > ${defenseCard.defense})'
        : 'Thua (${attackCard.attack} ≤ ${defenseCard.defense})';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCardWidget(attackCard,
                  isAttacker: true, isLoser: !attackWins),
              const Icon(Icons.arrow_forward, color: Colors.white70, size: 24),
              _buildCardWidget(defenseCard,
                  isAttacker: false, isLoser: attackWins),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            resultText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: attackWins ? Colors.greenAccent : Colors.redAccent,
              shadows: const [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          ),
        ],
      ),
    );
  }

// Hàm hiển thị thẻ bài với hiệu ứng hủy cho thẻ thua
  Widget _buildCardWidget(Cards card,
      {required bool isAttacker, required bool isLoser}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 100,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: isAttacker
              ? [Colors.red[700]!, Colors.red[400]!]
              : [Colors.green[700]!, Colors.green[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: card.rarity == 1
              ? Colors.grey
              : card.rarity == 2
                  ? Colors.blue
                  : Colors.purple,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLoser
                ? Colors.red.withOpacity(0.5)
                : Colors.yellow.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(card.imagePath),
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey[800],
                child: const Icon(Icons.broken_image,
                    color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            card.name,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isAttacker ? Icons.sports_martial_arts : Icons.shield,
                size: 12,
                color: Colors.yellowAccent,
              ),
              const SizedBox(width: 4),
              Text(
                isAttacker ? '${card.attack}' : '${card.defense}',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (isLoser)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Hủy',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Đấu Thẻ Bài Eldoria',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black87,
                Colors.grey,
              ],
            ),
            image: DecorationImage(
              image: AssetImage(
                  'assets/images/adventure_map.png'), // Add a thematic background
              fit: BoxFit.cover,
              opacity: 0.3,
            ),
          ),
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.yellow))
              : SafeArea(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person,
                                  color: Colors.red[300], size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Phe AI',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildBoard(aiBoard, isPlayer: false),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person,
                                  color: Colors.blue[300], size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Phe Bạn',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _buildBoard(playerBoard, isPlayer: true),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: battleStarted ? null : _startBattle,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 15),
                              backgroundColor: Colors.orange[700],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                            child: const Text(
                              'Bắt Đầu Trận Đấu',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
    );
  }

  Widget _buildBoard(List<Cards?> board, {required bool isPlayer}) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: isPlayer
              ? [
                  Colors.blue[900]!.withOpacity(0.8),
                  Colors.blue[600]!.withOpacity(0.6)
                ]
              : [
                  Colors.red[900]!.withOpacity(0.8),
                  Colors.red[600]!.withOpacity(0.6)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.7, // Adjusted for card-like proportions
        children: List.generate(6, (index) {
          final card = board[index];
          final isDefense = index < 3;
          return _buildCardSlot(card, isDefense, isPlayer);
        }),
      ),
    );
  }

  Widget _buildCardSlot(Cards? card, bool isDefense, bool isPlayer) {
    final rarityColor = card != null
        ? (card.rarity == 1
            ? Colors.grey
            : card.rarity == 2
                ? Colors.blue
                : Colors.purple)
        : Colors.grey[400]!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: LinearGradient(
          colors: [
            isDefense ? Colors.green[700]! : Colors.red[700]!,
            isDefense ? Colors.green[400]! : Colors.red[400]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: rarityColor.withOpacity(0.8), width: 2),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withOpacity(0.5),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: card != null
          ? Column(
              children: [
                // Card Image
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.file(
                      File(card.imagePath),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.broken_image,
                            color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
                // Card Details
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isDefense
                                ? Icons.shield
                                : Icons.sports_martial_arts,
                            size: 12,
                            color: Colors.yellowAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isDefense ? '${card.defense}' : '${card.attack}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (card.effect != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          card.effect!,
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Center(
              child: Text(
                'Trống',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontStyle: FontStyle.italic,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 2)
                  ],
                ),
              ),
            ),
    );
  }
}
