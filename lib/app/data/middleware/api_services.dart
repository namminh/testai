import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:nemoai/app/core/utils/utils.dart';
import '../models/chat_model.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:typed_data';
import '../../data/models/cache_info.dart';
import '../../data/models/player.dart';

class GoogleGenerativeServices {
  final _cacheManager = DefaultCacheManager();
  final Map<String, CacheInfo> _cache = {};
  final Map<String, String> _textCache = {};
  late int count = 0;
  final Map<String, AnalysisSummary> analysis = {};

  final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.0-flash-exp',
    apiKey:
        'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY', // Replace with your API key
    requestOptions: const RequestOptions(),
  );

  // Cache for getText (Simple Cache)
  Future<String> getText(String message) async {
    if (_textCache.containsKey(message)) {
      return _textCache[message]!;
    }

    try {
      final prompts = message;
      final content = [Content.text(prompts)];

      final response = await _model.generateContent(content);
      final result = response.text ?? '';
      _textCache[message] = result; // Lưu vào cache
      return result;
    } catch (e) {
      if (e is SocketException) {
        log("No Internet Connection. Please try again later $e");
      } else {
        log('An unknown error occurred: $e');
      }
    }
    return '';
  }

  Future<List<Map<String, dynamic>>?> _getCachedQuiz(String cacheKey) async {
    // 1. Check in-memory cache
    // if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired()) {
    //   print('NAMNM _getCachedQuiz');
    //   return _cache[cacheKey]!.data;
    // }

    // 2. Check file cache
    try {
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null) {
        final fileContent = await fileInfo.file.readAsString();
        final decodedData = jsonDecode(fileContent)['data'];
        if (decodedData is List) {
          final data = List<Map<String, dynamic>>.from(decodedData);

          // Update in-memory cache
          _cache[cacheKey] = CacheInfo(data: data);
          print('NAMNM _getCachedQuiz data cacheKey $cacheKey');
          return data;
        }
      }
    } catch (e) {
      log('Error reading from cache file: $e');
    }
    return null;
  }

  Future<void> _cacheQuizData(
      String cacheKey, List<Map<String, dynamic>> result) async {
    // 1. Cập nhật in-memory cache
    if (_cache.containsKey(cacheKey)) {
      // Lấy cache cũ và nối thêm dữ liệu mới
      final existingCache = _cache[cacheKey]!;
      final combinedData = [...existingCache.data, ...result];
      _cache[cacheKey] = CacheInfo(data: combinedData);
    } else {
      // Nếu chưa có, tạo cache mới
      _cache[cacheKey] = CacheInfo(data: result);
    }

    // 2. Cập nhật file cache
    try {
      // Đọc dữ liệu hiện tại từ cache file (nếu có)
      FileInfo? fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      List<Map<String, dynamic>> currentData = [];
      if (fileInfo != null) {
        try {
          final fileContent = await fileInfo.file.readAsString();
          final decodedData = jsonDecode(fileContent)['data'];
          if (decodedData is List) {
            currentData = List<Map<String, dynamic>>.from(decodedData);
          }
        } catch (e) {
          log('Error decode cache file: $e');
        }
      }

      // Kết hợp dữ liệu hiện tại và dữ liệu mới
      final combinedData = [...currentData, ...result];

      // Lưu lại vào file cache
      await _cacheManager.putFile(
        cacheKey,
        Uint8List.fromList(utf8.encode(jsonEncode({'data': combinedData}))),
        key: cacheKey,
        maxAge: const Duration(days: 1),
        eTag: DateTime.now().toIso8601String(),
      );
    } catch (e) {
      log('Error writing to cache file: $e');
    }
  }

// API Interaction Functions
  Future<List<Map<String, dynamic>>> _fetchAndCacheQuiz(
      String prompt, String cacheKey) async {
    try {
      // 2. If not in cache, fetch from API
      print('NAMNM Fetching from API for $cacheKey');
      final result = await _getQuizFromApi(prompt);

      // 3. Check API response
      if (result.isEmpty) {
        print('NAMNM API returned an empty response for $cacheKey');
        throw Exception('API returned an empty response');
      }

      // 4. Cache the data (in-memory and file)
      await _cacheQuizData(cacheKey, result);

      // 5. Return shuffled data
      print('NAMNM API returned and cached data for $cacheKey');
      return _shuffleQuestions(result);
    } on SocketException catch (e) {
      log('SocketException in _fetchAndCacheQuiz: $e');
      rethrow;
    } catch (e) {
      log('Error in _fetchAndCacheQuiz: $e');
      rethrow;
    }
  }

// Main Function - getquiz
  Future<List<Map<String, dynamic>>> getquiz(
      String prompt, String cacheKey) async {
    //final cacheKey = '1234567'; // Move cacheKey generation here
    try {
      // Try to get data from cache first
      final cachedData = await _getCachedQuiz(cacheKey);
      if (cachedData is List) {
        print(
            'NAMNM getquiz Độ dài của cachedData (List): ${cachedData!.length}');
        // if ({cachedData!.length.toInt()} <= 10)
        // {
        //    return await _fetchAndCacheQuiz(prompt, cacheKey);
        // }
      }
      if (cachedData == null) {
        return await _fetchAndCacheQuiz(prompt, cacheKey);
      } else if (cachedData != null && count <= 3) {
        print('NAMNM _shuffleQuestions count: ${count}');
        count++;
        return _shuffleQuestions(cachedData);
      }

      count = 0;
      return await _fetchAndCacheQuiz(prompt, cacheKey);
    } on SocketException catch (e) {
      log("No Internet Connection. Please try again later $e");
      rethrow;
    } catch (e) {
      log('An unknown error occurred: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> _shuffleQuestions(List<dynamic> questions) {
    final List<Map<String, dynamic>> shuffledQuestions =
        List<Map<String, dynamic>>.from(questions);
    shuffledQuestions.shuffle();
    print('NAMNM shuffledQuestions ');
    return shuffledQuestions;
  }

  Future<List<Map<String, dynamic>>> _getQuizFromApi(String prompt) async {
    try {
      final prompts = prompt;
      final content = [Content.text(prompts)];
      print('NAMNM goi API');
      final response = await _model.generateContent(
        content,
        generationConfig: GenerationConfig(
            topP: 0,
            temperature: 0,
            maxOutputTokens: 10000,
            responseMimeType: 'application/json'),
      );
      final result = response.text!;
      final jsonResponse = jsonDecode(result.toString()) as List<dynamic>;
      return jsonResponse.map((item) => item as Map<String, dynamic>).toList();
    } on SocketException catch (e) {
      log('SocketException in _getQuizFromApi: $e');
      rethrow;
    } catch (e) {
      log('Error in _getQuizFromApi: $e');
      rethrow;
    }
  }

  // getTextFromImage (No Cache - For now)
  Future<ChatModel?> getTextFromImage(File photo, String message) async {
    try {
      final prompt = TextPart(message);
      final imageParts = [
        DataPart('image/jpeg', await photo.readAsBytes()),
      ];
      final response = await _model.generateContent([
        Content.multi([prompt, ...imageParts])
      ]);
      log(response.text.toString());
      return ChatModel(
          role: response.candidates.first.content.role.toString(),
          text: response.text.toString());
    } catch (e) {
      if (e is SocketException) {
        log("No Internet Connection. Please try again later $e");
      } else {
        log('An unknown error occurred: $e');
      }
      return null;
    }
  }
}
