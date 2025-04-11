import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

class SoundUtils {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static double _currentVolume = 1.0; // Giá trị âm lượng mặc định

  // Phát âm thanh với tùy chọn âm lượng
  static Future<void> playSound(String soundPath, {double? volume}) async {
    try {
      await _audioPlayer.stop(); // Dừng âm thanh đang phát
      if (volume != null) {
        await setVolume(volume); // Đặt âm lượng nếu được cung cấp
      }
      await _audioPlayer.play(AssetSource(soundPath));
    } catch (e) {
      print("Error playing sound: $e");
    }
  }

  // Dừng âm thanh
  static Future<void> stopSound() async {
    await _audioPlayer.stop();
  }

  // Điều chỉnh âm lượng
  static Future<void> setVolume(double volume) async {
    try {
      // Giới hạn giá trị âm lượng từ 0.0 đến 1.0
      if (volume < 0.0 || volume > 1.0) {
        throw Exception("Volume must be between 0.0 and 1.0");
      }
      _currentVolume = volume;
      await _audioPlayer.setVolume(volume);
    } catch (e) {
      print("Error setting volume: $e");
    }
  }

  // Truy xuất âm lượng hiện tại (tùy chọn)
  static double getCurrentVolume() {
    return _currentVolume;
  }
}

class Sounds {
  static String audiencePhone = "sounds/audiencePhone.mp3";

  static String correct = "sounds/correct.mp3";

  static String fiftyFifty = "sounds/fiftyFifty.mp3";

  static String incorrect = "sounds/incorrect.mp3";

  static String question = "sounds/question.mp3";

  static String result = "sounds/result.mp3";

  static String appstart = "sounds/wwm_appstart.mp3";
}
