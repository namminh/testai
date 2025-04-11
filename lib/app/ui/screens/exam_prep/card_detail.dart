import 'package:flutter/material.dart';
import '../../../data/models/card.dart'; // Assuming this is the correct Cards model
import 'dart:io';

class CardRewardDialog extends StatefulWidget {
  final Cards card; // Sửa Cards thành Card cho nhất quán với code trước

  const CardRewardDialog({required this.card, Key? key}) : super(key: key);

  @override
  _CardRewardDialogState createState() => _CardRewardDialogState();
}

class _CardRewardDialogState extends State<CardRewardDialog> {
  @override
  Widget build(BuildContext context) {
    // Màu sắc theo độ hiếm
    Color rarityColor;
    String rarityText;
    switch (widget.card.rarity) {
      case 1:
        rarityColor = Colors.grey;
        rarityText = 'Thường';
        break;
      case 2:
        rarityColor = Colors.blue;
        rarityText = 'Hiếm';
        break;
      case 3:
        rarityColor = Colors.purple;
        rarityText = 'Epic';
        break;
      default:
        rarityColor = Colors.black;
        rarityText = 'Không xác định';
    }

    // Màu sắc theo hệ ngũ hành
    Color elementColor;
    switch (widget.card.element.toLowerCase()) {
      case 'kim':
        elementColor = Colors.yellow[700]!;
        break;
      case 'mộc':
        elementColor = Colors.green;
        break;
      case 'thủy':
        elementColor = Colors.blue[900]!;
        break;
      case 'hỏa':
        elementColor = Colors.red;
        break;
      case 'thổ':
        elementColor = Colors.brown;
        break;
      default:
        elementColor = Colors.grey;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black87, Colors.grey[900]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: rarityColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: SingleChildScrollView(
          // Thêm cuộn để tránh overflow trên màn hình nhỏ
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tiêu đề
              Text(
                'Chúc mừng! Bạn nhận được thẻ mới!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: rarityColor, blurRadius: 8),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Ảnh thẻ bài
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: rarityColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: rarityColor.withOpacity(0.7),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(widget.card.imagePath),
                    width: 200,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print(
                          'NAMNM Error loading image from ${widget.card.imagePath}: $error');
                      return Container(
                        width: 200,
                        height: 300,
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.broken_image,
                          size: 100,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tên thẻ
              Text(
                widget.card.name,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: rarityColor, blurRadius: 5),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Mô tả
              Text(
                widget.card.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Thuộc tính: Công, Thủ, Hệ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Điểm công
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sports_martial_arts,
                            color: Colors.blue, size: 18), // Icon thủ
                        const SizedBox(width: 4),
                        Text(
                          'Công: ${widget.card.attack}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Điểm thủ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield,
                            color: Colors.blue, size: 18), // Icon thủ
                        const SizedBox(width: 4),
                        Text(
                          'Thủ: ${widget.card.defense}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Hệ ngũ hành
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: elementColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: elementColor),
                ),
                child: Text(
                  'Hệ: ${widget.card.element}',
                  style: TextStyle(
                    fontSize: 16,
                    color: elementColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Độ hiếm
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: rarityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rarityColor),
                ),
                child: Text(
                  'Độ hiếm: $rarityText',
                  style: TextStyle(
                    fontSize: 16,
                    color: rarityColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Nút xác nhận
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: rarityColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
