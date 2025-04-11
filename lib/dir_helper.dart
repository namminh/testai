import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DirHelper {
  static Future<String> getAppPath() async {
    String mainPath = await _getMainPath();
    String appPath = "$mainPath/AIQuiz";
    await _createPathIfNotExist(appPath);
    return appPath;
  }

  static Future<String> _getMainPath() async {
    String appDownloadsPath = "";
    if (Platform.isAndroid) {
      // Kiểm tra quyền mà không yêu cầu
      if (await Permission.storage.isGranted) {
        final dir = await getExternalStorageDirectory();
        if (dir != null) {
          List<String> paths = dir.path.split('/');
          for (var i in paths) {
            if (i == "Android") break;
            appDownloadsPath += "$i/";
          }
          print('NAMNM External Storage Path: $appDownloadsPath');
          return appDownloadsPath;
        }
      }
      // Fallback về thư mục ứng dụng nếu không có quyền
      final dir = await getApplicationDocumentsDirectory();
      appDownloadsPath = dir.path;
      print('NAMNM Fallback to App Dir: $appDownloadsPath');
    } else {
      // iOS luôn dùng thư mục ứng dụng
      final dir = await getApplicationDocumentsDirectory();
      appDownloadsPath = dir.path;
      print('NAMNM iOS Path: $appDownloadsPath');
    }
    return appDownloadsPath;
  }

  static Future<void> _createPathIfNotExist(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      try {
        await directory.create(recursive: true);
        print('NAMNM Created directory: $path');
      } catch (e) {
        print('NAMNM Error creating directory: $e');
        // Fallback về thư mục ứng dụng nếu lỗi
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackPath = '${fallbackDir.path}/AIQuiz';
        if (!await Directory(fallbackPath).exists()) {
          await Directory(fallbackPath).create(recursive: true);
        }
        print('NAMNM Fallback to: $fallbackPath');
      }
    }
  }

  // Hàm yêu cầu quyền được di chuyển ra ngoài
  static Future<bool> requestStoragePermission() async {
    if (await Permission.storage.isGranted) {
      print('NAMNM Storage permission already granted');
      return true;
    }

    var status = await Permission.storage.request();
    if (status.isGranted) {
      print('NAMNM Storage permission granted');
      return true;
    } else if (status.isPermanentlyDenied) {
      print('NAMNM Storage permission permanently denied');
      await openAppSettings();
      return false;
    }
    print('NAMNM Storage permission denied');
    return false;
  }
}
