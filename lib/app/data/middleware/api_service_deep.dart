import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:collection/collection.dart'; // Cho PriorityQueue
import 'dart:collection';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'dart:typed_data';
import '../models/quiz_question_model.dart';
import '../../core/constants/quiz_constant.dart';

class MissingApiKeyException implements Exception {
  final String message;

  MissingApiKeyException([this.message = 'API key is missing']);

  @override
  String toString() => 'MissingApiKeyException: $message';
}

class RateLimitException implements Exception {}

class NetworkException implements Exception {}

class QuizGenerationException implements Exception {
  final String message;
  const QuizGenerationException(this.message);
}

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _primaryKeyName = 'primary_api_key';
  static const _backupKeyName = 'backup_api_key';
  static const _statusKeyName = 'api_key_status';

  // Key mặc định (nên lấy từ biến môi trường hoặc server)
  static const String _defaultPrimaryKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY';
  static const String _defaultBackupKey =
      'AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY';

  Future<String> getApiKey() async {
    try {
      // Đọc trạng thái key
      final statusJson = await _storage.read(key: _statusKeyName);
      final status = statusJson != null
          ? jsonDecode(statusJson)
          : {'active': _primaryKeyName};

      // Lấy key hiện tại
      String activeKeyName = status['active'];
      String? storedKey = await _storage.read(key: activeKeyName);

      // Nếu không có key, khởi tạo
      if (storedKey == null || storedKey.isEmpty) {
        storedKey = activeKeyName == _primaryKeyName
            ? _defaultPrimaryKey
            : _defaultBackupKey;
        await _storage.write(key: activeKeyName, value: storedKey);
      }

      // Kiểm tra key (giả lập, cần API thực tế)
      if (await _isKeyValid(storedKey)) {
        return storedKey;
      } else {
        // Chuyển đổi sang key khác
        return await _switchToBackupKey(activeKeyName);
      }
    } catch (e) {
      print('Error accessing secure storage: $e');
      return await _switchToBackupKey(_primaryKeyName); // Fallback khi lỗi
    }
  }

  // Chuyển đổi key khi key hiện tại không hợp lệ
  Future<String> _switchToBackupKey(String currentKeyName) async {
    final newKeyName =
        currentKeyName == _primaryKeyName ? _backupKeyName : _primaryKeyName;
    String? newKey = await _storage.read(key: newKeyName);

    if (newKey == null || newKey.isEmpty) {
      newKey = newKeyName == _primaryKeyName
          ? _defaultPrimaryKey
          : _defaultBackupKey;
      await _storage.write(key: newKeyName, value: newKey);
    }

    // Cập nhật trạng thái
    await _storage.write(
      key: _statusKeyName,
      value: jsonEncode({'active': newKeyName}),
    );
    print('Switched to $newKeyName');
    return newKey;
  }

  // Kiểm tra key hợp lệ (giả lập, cần thay bằng API thực tế)
  Future<bool> _isKeyValid(String key) async {
    // Ví dụ: Gọi API thử, trả về true nếu key hoạt động
    // Ở đây giả lập random để minh họa
    return Future.delayed(Duration(milliseconds: 100), () => true);
  }

  // Cập nhật key mới
  Future<void> updateApiKey(String newKey, {bool isPrimary = true}) async {
    final keyName = isPrimary ? _primaryKeyName : _backupKeyName;
    await _storage.write(key: keyName, value: newKey);
    await _storage.write(
      key: _statusKeyName,
      value: jsonEncode({'active': keyName}),
    );
  }
}

class RetryHandler {
  final int maxRetries;
  final Random _random = Random();
  static const int _baseDelayMs = 200; // Giảm từ giây xuống mili-giây

  RetryHandler({this.maxRetries = 3});

  Future<T> execute<T>(Future<T> Function() task) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await task();
      } catch (e) {
        lastError = e;
        if (attempt == maxRetries) break;

        await _waitWithBackoff(attempt);
      }
    }
    throw lastError ?? TimeoutException('Max retries reached');
  }

  Future<void> _waitWithBackoff(int attempt) async {
    final delayMs = (_baseDelayMs * pow(2, attempt - 1)).toInt();
    final jitter = _random.nextInt(100); // Jitter nhỏ hơn
    await Future.delayed(Duration(milliseconds: delayMs + jitter));
  }
}

class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);

  @override
  String toString() => 'Validation Error: $message';
}

class QuizValidator {
  static const _requiredFields = [
    'question',
    'answer',
    'distractors',
    'metadata'
  ];

  final Logger _logger;

  QuizValidator(this._logger);

  Future<List<Map<String, dynamic>>> validate(
      List<Map<String, dynamic>> questions) async {
    final results = await Future.wait(
      questions.map((q) => Future(() {
            try {
              _validateStructure(q);
              return q;
            } on ValidationException catch (e) {
              _logger.w('Invalid question format: ${e.message}');
              return null;
            }
          })),
    );
    return results.whereType<Map<String, dynamic>>().toList();
  }

  void _validateStructure(Map<String, dynamic> question) {
    final missingFields =
        _requiredFields.where((field) => !question.containsKey(field));
    if (missingFields.isNotEmpty) {
      throw ValidationException('Missing fields: ${missingFields.join(', ')}');
    }
    final distractors = question['distractors'] as List<dynamic>? ?? [];
    if (distractors.length < 3) {
      throw ValidationException('Insufficient distractors');
    }
  }
}

class AntiRepetitionEngine {
  final _questionCache = <String, DateTime>{};
  final _trapHistory = <String, int>{};
  static const _maxHistorySize = 1000;
  static const _maxTrapSize = 50;

  void updateHistory(List<Map<String, dynamic>> questions,
      {double correctRate = 0.5}) {
    for (final q in questions) {
      final hash = _generateEnhancedHash(q);
      if (_questionCache.containsKey(hash)) continue;
      if (_questionCache.length >= _maxHistorySize) {
        _questionCache.remove(_questionCache.keys.first); // FIFO đơn giản
      }
      _questionCache[hash] = DateTime.now();

      final distractors = q['distractors'] as List<dynamic>? ?? [];
      for (final trap in distractors.map((d) => d['type'].toString()).toSet()) {
        _trapHistory.update(trap, (v) => v + 1, ifAbsent: () => 1);
        if (_trapHistory.length > _maxTrapSize) {
          _trapHistory.remove(_trapHistory.keys.first);
        }
      }
    }
    if (_questionCache.length % 50 == 0) _applyTrapDecay(correctRate);
  }

  Map<String, dynamic> _getConstraints({double minDelay = 0.0}) {
    final now = DateTime.now();
    final freshQuestions = _questionCache.entries
        .where((e) => now.difference(e.value).inSeconds < minDelay)
        .length;

    final trapList = _trapHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sắp xếp giảm dần

    return {
      'unique_questions': _questionCache.length,
      'fresh_questions': freshQuestions,
      'top_traps': trapList
          .take(3)
          .map((e) => {'type': e.key, 'count': e.value})
          .toList(),
    };
  }

  String _generateEnhancedHash(Map<String, dynamic> q) {
    final distractors = (q['distractors'] as List<dynamic>? ?? [])
        .map((d) => d['content']?.toString() ?? '')
        .toList()
      ..sort(); // Sắp xếp tăng dần

    final parts = [
      q['question']?.toString() ?? '',
      q['answer']?.toString() ?? '',
      distractors.join('|'),
      q['metadata']?['cognitive_level']?.toString() ?? '',
    ];
    return sha256.convert(utf8.encode(parts.join('|'))).toString();
  }

  void _applyTrapDecay(double correctRate) {
    final decayFactor = 0.9 - (correctRate * 0.2);
    _trapHistory.updateAll((k, v) => (v * decayFactor).ceil());
    _trapHistory.removeWhere((_, v) => v <= 0);
  }
}

class QuizGenerator {
  final _secureStorage = SecureStorage();
  final _retryHandler = RetryHandler(maxRetries: 3);
  final _antiRepetitionEngine = AntiRepetitionEngine();
  final _cognitivel = AdaptiveLearningEngine();
  final _cacheService = CacheService();
  late final GenerativeModel _model;
  late final _logger = Logger();

  final List<QuizQuestion> quizTemp = QuizConstant.quiz;

  late final _validator = QuizValidator(_logger);
  QuizGenerator() {
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    final apiKey = await _secureStorage.getApiKey();
    _model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.35,
        topP: 0.95,
        maxOutputTokens: 10000,
        responseMimeType: 'application/json',
      ),
    );
  }

  Future<List<Map<String, dynamic>>> generateQuiz({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String difficulty,
    required String age,
    String learning = 'visual,auditory,kinesthetic',
    List<QuizQuestion> answeredQuestions = const [],
    String userhistory = '',
    double time = 0.0,
  }) async {
    final stopwatch = Stopwatch()..start();
    final cacheKey =
        _generateCacheKey(subject, topic, language, difficulty, age);
    print('NAMNM cacheKey $cacheKey');
    try {
      return await _retryHandler.execute(() async {
        final cachedData = await _cacheService.getCachedData(cacheKey) ?? [];
        final filteredQuestions = cachedData
            .where((q) => !answeredQuestions
                .any((a) => _deepQuestionCompare(q, a.toJson())))
            .toList();

        final remainingCount = count - filteredQuestions.length;
        if (remainingCount <= 0) {
          return filteredQuestions.take(count).toList()
            ..shuffle(); // Sửa lỗi ở đây
        }

        final newQuestions = await _generateNewQuestions(
          topic: topic,
          subject: subject,
          point: point,
          count: remainingCount,
          language: language,
          age: age,
          difficulty: difficulty,
          userhistory: userhistory,
          learning: learning,
          time: time,
        );

        final uniqueQuestions = LinkedHashSet<Map<String, dynamic>>(
          equals: _deepQuestionCompare,
          hashCode: _generateQuestionHash,
        )..addAll([...filteredQuestions, ...newQuestions]);

        final result = uniqueQuestions.toList()
          ..shuffle(); // Xáo trộn toàn bộ kết quả
        await _cacheService.updateCaches(cacheKey, result);
        return result.take(count).toList();
      });
    } finally {
      _logger.i('Quiz generation took ${stopwatch.elapsedMilliseconds}ms');
    }
  }

// So sánh sâu câu hỏi
  bool _deepQuestionCompare(Map<String, dynamic> a, Map<String, dynamic> b) {
    return a['question'] == b['question'] &&
        a['answer'] == b['answer'] &&
        _areDistractorsEqual(a['distractors'], b['distractors']);
  }

// So sánh danh sách nhiễu
  bool _areDistractorsEqual(dynamic a, dynamic b) {
    if (a is! List || b is! List) return false;
    if (a.length != b.length) return false;
    final aSorted = a.map((d) => '${d['type']}${d['content']}').toList()
      ..sort();
    final bSorted = b.map((d) => '${d['type']}${d['content']}').toList()
      ..sort();
    return aSorted.join() == bSorted.join();
  }

// Tạo hash cho câu hỏi
  int _generateQuestionHash(Map<String, dynamic> question) {
    final q = question['question']?.toString() ?? '';
    final a = question['answer']?.toString() ?? '';
    final d = (question['distractors'] as List<dynamic>? ?? [])
        .map((d) => '${d['type']}${d['content']}')
        .toList()
      ..sort();
    return '$q|$a|${d.join('|')}'.hashCode;
  }

  // Thêm hash cả metadata vào cache key
  String _generateCacheKey(
    String subject,
    String topic,
    String age,
    String language,
    String difficulty,
  ) {
    return 'quiz_${subject.hashCode}_${topic.hashCode}_${difficulty}_${language}_$age';
  }

  Future<List<Map<String, dynamic>>> _generateNewQuestions({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String age,
    required String difficulty,
    String learning = 'visual,auditory,kinesthetic',
    double time = 0.0,
    String userhistory = '',
  }) async {
    try {
      // Chọn prompt dựa trên tuổi
      String prompt;
      switch (age) {
        case '18':
          prompt = _buildQuizPrompt(
            topic: topic,
            subject: subject,
            point: point,
            count: count,
            language: language,
            difficulty: difficulty,
          );
          break;
        case '17':
          prompt = _buildQuizOlympiaPrompt(
            topic: topic,
            subject: subject,
            point: point,
            count: count,
            language: language,
            difficulty: difficulty,
            learning: learning,
          );
          break;
        case '10':
          prompt = _buildQuizKidPrompt(
            topic: topic,
            subject: subject,
            point: point,
            count: count,
            language: language,
            difficulty: difficulty,
            learningStyle: learning,
            userHistory: userhistory,
          );
          break;
        case 'luyện tập':
          prompt = _buildTrainPrompt(
            topic: topic,
            subject: subject,
            point: point,
            count: count,
            language: language,
            difficulty: difficulty,
            time: time,
          );
          break;
        default:
          throw Exception('NAMNM: Unsupported age value - $age');
      }

      final response = await _model.generateContent([Content.text(prompt)]);
      final parsedData = _parseApiResponse(response.text ?? '');
      final validatedData = await _validator.validate(parsedData);

      _antiRepetitionEngine.updateHistory(validatedData,
          correctRate: _calculateCorrectAnswerRate(point));
      return validatedData;
    } catch (e) {
      print('NAMNM tạo cau hỏi faile $e');
      return _handleGenerationError(topic, e);
    }
  }

  String _buildQuizKidPrompt({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String difficulty,
    String learningStyle = 'kinesthetic,visual,auditory',
    String userHistory = '',
  }) {
    final antiRepetitionGuards =
        _antiRepetitionEngine._getConstraints(minDelay: 0.1);
    final double correctRate = _calculateCorrectAnswerRate(point);
    final String dynamicStyle =
        _adjustLearningStyle(learningStyle, correctRate);
    final int gradeLevel = _inferGradeLevel(subject);

    // Sử dụng hàm nâng cao cho mức độ khó
    final String enhancedDifficulty =
        _getEnhancedDifficulty(point, gradeLevel, correctRate);

    // Mở rộng giới hạn từ vựng và độ dài câu hỏi cho câu hỏi phức tạp
    final int enhancedMaxWords = gradeLevel * 4;
    final String cognitiveLevel = _getAdvancedCognitiveLevel(point, gradeLevel);

    return '''
<Prompt>
  <Role type="generator">Advanced Intelligence Challenge Creator</Role>
  <TaskParameters>
    <Quantitative>
      <Count variable="$count" min="5" max="20"/>
      <DifficultyLevels base="${gradeLevel + 2}" adjuster="$correctRate" userScore="$point" target="$enhancedDifficulty"/>
      <QuestionLength maxWords="$enhancedMaxWords" style="complex_analytical"/>
    </Quantitative>
    <Qualitative>
      <Topic domain="$subject" subdomain="$topic" context="advanced_competition" contextLocation="Vietnam"/>
      <LanguageSupport lang="$language" tone="intellectual_challenging" vocabLevel="${_getAdvancedVocabLevel(gradeLevel)}"/>
      <LearningStyle values="$dynamicStyle" distribution="higher_order_thinking"/>
      <AdvancedSource source="olympiad,STEM_competition,IQ_challenges" update="weekly"/>
    </Qualitative>
    <UserState>
      <CorrectRate variable="$correctRate"/>
      <UserHistory variable="$userHistory" filter="incorrect_answers" weight="0.7"/>
    </UserState>
    <DynamicAntiRepetition source="json" data="$antiRepetitionGuards">
      <TrapPriority type="deep_concepts" weight="0.8"/>
      <SemanticGuard threshold="0.9" action="skip_similar"/>
    </DynamicAntiRepetition>
    
    <QuestionTypes distribution="critical_thinking">
      <Type name="logic_puzzle" weight="0.3"/>
      <Type name="mathematical_challenge" weight="0.25"/>
      <Type name="pattern_recognition" weight="0.2"/>
      <Type name="scientific_problem" weight="0.15"/>
      <Type name="lateral_thinking" weight="0.1"/>
    </QuestionTypes>
  </TaskParameters>

  <ProcessingPipeline>
    <Stage name="DifficultyCalibration" input="$gradeLevel" target="above_grade" range="6-9"/>
    <Stage name="KnowledgeBinding" input="$subject,$topic" source="AdvancedSource"/>
    <Stage name="DistractorGeneration" maxDistractors="4" style="logical_trap,common_misconception,calculation_error,partial_truth"/>
    <Stage name="ComplexityTuning" style="$dynamicStyle" tone="thought_provoking"/>
    
    <AdvancedCognition>
      <BloomsTaxonomy target="analysis,evaluation,creation" distribution="40,30,30"/>
      <DepthOfKnowledge level="3-4" integration="across_subjects"/>
      <MetacognitiveChallenge level="high" type="strategic_thinking"/>
    </AdvancedCognition>
  </ProcessingPipeline>

  <SmartQuestionFeatures>
    <ContextAwareDistractors>
      <ConceptualChallenges context="Vietnam,Global" ageRange="9-13"/>
      <DifficultyAdjustment level="$enhancedDifficulty" cognitive="$cognitiveLevel"/>
    </ContextAwareDistractors>
    
    <MultimediaElements>
      <Visual type="complex_diagram,data_visualization,challenge_illustration" condition="true" prominence="high"/>
      <Interactive type="simulation,problem_modeling" condition="true" prominence="high"/>
    </MultimediaElements>
    
    <CompetitionContext>
      <Format type="smarter_than_5th_grader" difficulty="challenging"/>
      <TimeConstraint seconds="30" pressure="moderate"/>
      <LeaderboardIntegration enabled="true" metrics="speed,accuracy"/>
    </CompetitionContext>
    
    <ExtendedExplanations>
      <ConceptualUnderstanding depth="principle_level"/>
      <AlternativeSolutions count="2" approach="different_methods"/>
      <LearningExtension type="advanced_concept" relation="builds_upon_basic"/>
    </ExtendedExplanations>
  </SmartQuestionFeatures>
</Prompt>
**Response Template**:
```json
{
  "questions": [
    {
      "question": "${_getAdvancedQuestion(gradeLevel, difficulty, topic, language)}",
      "hints": "${_getProgressiveHint(gradeLevel, dynamicStyle, gradeLevel)}",
      "answer": "${_getAdvancedAnswer(gradeLevel, difficulty, topic, language)}",
      "distractors": ${_getComplexDistractors(gradeLevel, difficulty, topic, language)},
      "explanation": "${_getDetailedExplanation(gradeLevel, difficulty, topic, language)}",
      "learning_tip": "${_getSampleLearningTip17(dynamicStyle)}",
      "metadata": {
        "difficulty": "$difficulty",
        "question_style": "${getQuestionStyleFromCognitiveLevel(cognitiveLevel)}",
        "cognitive_level": "$cognitiveLevel",
        "vocabulary_level": "${_getAdvancedVocabLevel(gradeLevel)}",
        "learning_style": "$dynamicStyle"
      }
    }
  ]
}
''';
  }

  String _getEnhancedDifficulty(int point, int gradeLevel, double correctRate) {
    // Mảng các mức độ khó từ thấp đến cao
    final difficultyLevels = [
      'challenging', // Thách thức
      'advanced', // Nâng cao
      'gifted', // Năng khiếu
      'olympiad_prep', // Chuẩn bị Olympic
      'competition_level', // Mức độ thi đấu
      'genius_level' // Mức thiên tài
    ];

    // Xác định mức khó cơ sở dựa trên điểm số - bắt đầu từ mức cao
    int baseIndex = 2; // Bắt đầu từ mức "gifted"
    if (point >= 90)
      baseIndex = 5; // Genius level
    else if (point >= 80)
      baseIndex = 4; // Competition level
    else if (point >= 70) baseIndex = 3; // Olympiad prep

    // Điều chỉnh dựa trên tỷ lệ trả lời đúng
    int adjustedIndex = baseIndex;
    if (correctRate >= 0.9)
      adjustedIndex += 1; // Rất tốt, tăng độ khó
    else if (correctRate >= 0.75)
      adjustedIndex += 0; // Giữ nguyên
    else if (correctRate >= 0.6) adjustedIndex -= 1; // Giảm nhẹ

    // Đảm bảo chỉ số nằm trong phạm vi hợp lệ và không thấp hơn "challenging"
    adjustedIndex = adjustedIndex.clamp(0, difficultyLevels.length - 1);

    // Trả về mức độ khó tương ứng
    return difficultyLevels[adjustedIndex];
  }

  String _getAdvancedCognitiveLevel(int point, int gradeLevel) {
    // Mảng cấp độ nhận thức theo thang Bloom từ thấp đến cao
    final cognitiveLevels = [
      'understanding', // Hiểu
      'applying', // Áp dụng
      'analyzing', // Phân tích
      'evaluating', // Đánh giá
      'creating' // Sáng tạo
    ];

    // Trả về cấp độ nhận thức cao bất kể điểm số
    // Tối thiểu từ mức phân tích trở lên
    int baseIndex = 2; // Mức "analyzing"

    if (point >= 85)
      baseIndex = 4; // Creating
    else if (point >= 70) baseIndex = 3; // Evaluating

    return cognitiveLevels[baseIndex];
  }

  int _inferGradeLevel(String subject) {
    // Luôn trả về mức cao nhất trong phạm vi tiểu học để
    // tạo câu hỏi phức tạp nhất có thể
    return 5;
  }

  String _getAdvancedVocabLevel(int gradeLevel) {
    // Mức từ vựng nâng cao 2 cấp so với tiêu chuẩn
    return "advanced_middle_school"; // Tương đương lớp 7-8
  }

  String _getAdvancedQuestion(
      int gradeLevel, String difficulty, String topic, String language) {
    if (language == 'Vietnamese') {
      return "Trong một cuộc thi, 5 học sinh xếp hàng. An đứng cạnh Bình nhưng không đứng cạnh Cường. Dũng đứng ở vị trí thứ tư tính từ trái sang. Cường không đứng ở hai đầu. Em không đứng cạnh Dũng. Ai đứng ở vị trí giữa?";
    } else {
      return "In a contest, 5 students are standing in a row. Alex stands next to Ben but not next to Charlie. David is in the fourth position from the left. Charlie is not at either end. Emily is not next to David. Who is standing in the middle position?";
    }
  }

  String _getAdvancedAnswer(
      int gradeLevel, String difficulty, String topic, String language) {
    return language == 'Vietnamese' ? "Cường" : "Charlie";
  }

  String _getComplexDistractors(
      int gradeLevel, String difficulty, String topic, String language) {
    if (language == 'Vietnamese') {
      return jsonEncode([
        {
          "type": "logical_error",
          "content": "An",
          "reasoning":
              "Lỗi khi không xem xét điều kiện An cạnh Bình nhưng không cạnh Cường"
        },
        {
          "type": "calculation_error",
          "content": "Bình",
          "reasoning": "Lỗi khi xác định vị trí giữa (thứ 3)"
        },
        {
          "type": "misconception",
          "content": "Em",
          "reasoning": "Lỗi khi xem xét mối quan hệ với Dũng"
        },
        {
          "type": "common_mistake",
          "content": "Dũng",
          "reasoning":
              "Biết Dũng ở vị trí thứ 4 nên không thể ở giữa (vị trí 3)"
        }
      ]);
    } else {
      return jsonEncode([
        {
          "type": "logical_error",
          "content": "Alex",
          "reasoning":
              "Error when not considering condition that Alex is next to Ben but not next to Charlie"
        },
        {
          "type": "calculation_error",
          "content": "Ben",
          "reasoning": "Error in identifying the middle position (3rd)"
        },
        {
          "type": "misconception",
          "content": "Emily",
          "reasoning": "Error when considering relationship with David"
        },
        {
          "type": "common_mistake",
          "content": "David",
          "reasoning":
              "Known that David is in 4th position so cannot be in middle (3rd position)"
        }
      ]);
    }
  }

  String _getDetailedExplanation(
      int gradeLevel, String difficulty, String topic, String language) {
    if (language == 'Vietnamese') {
      return "Để giải bài toán này, ta xét từng điều kiện: 1) Dũng ở vị trí thứ 4 từ trái sang. 2) Cường không đứng ở hai đầu và là người đứng ở giữa. 3) An đứng cạnh Bình nhưng không cạnh Cường. 4) Em không đứng cạnh Dũng. Từ các điều kiện này, ta thử vị trí của Cường ở giữa (vị trí 3): Dũng ở vị trí 4, Em không đứng cạnh Dũng nên Em ở vị trí 1, An và Bình phải đứng cạnh nhau và không cạnh Cường, nên An ở vị trí 2 và Bình ở vị trí 5. Kiểm tra lại thấy thỏa mãn mọi điều kiện, nên Cường đứng ở vị trí giữa.";
    } else {
      return "To solve this problem, we consider each condition: 1) David is in the 4th position from the left. 2) Charlie is not at either end and is the person in the middle. 3) Alex stands next to Ben but not next to Charlie. 4) Emily is not next to David. From these conditions, we try Charlie's position in the middle (position 3): David is at position 4, Emily is not next to David so Emily is at position 1, Alex and Ben must be next to each other and not next to Charlie, so Alex is at position 2 and Ben is at position 5. Checking back, this satisfies all conditions, so Charlie is standing in the middle position.";
    }
  }

  String _getProgressiveHint(int level, String style, int gradeLevel) {
    if (level == 1) {
      return "Hãy bắt đầu bằng cách xác định vị trí của Dũng (vị trí 4) và làm việc từ đó.";
    } else {
      return "Cường không đứng ở hai đầu, nên có thể ở vị trí 2, 3 hoặc 4. Nhưng Dũng đã ở vị trí 4.";
    }
  }

  int _mapDifficultyToScore(String difficulty, int point, int gradeLevel) {
    const difficultyMap = {
      'advanced': 4,
      'olympiad_prep': 6,
      'competition_level': 8,
      'genius_level': 10,
      'hard': 3,
      'medium': 2,
      'easy': 1
    };
    final baseScore = difficultyMap[difficulty.toLowerCase()] ?? 4;
    return baseScore + (point ~/ 20) + gradeLevel ~/ 2;
  }

  String _getDifficultyDescriptor(int score) {
    if (score <= 6) return 'challenging';
    if (score <= 10) return 'very_advanced';
    return 'exceptional';
  }

  String _buildQuizPrompt({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String difficulty,
    String learning = 'digital_interactive,visual,auditory,kinesthetic',
  }) {
    final double correct = _calculateCorrectAnswerRate(point);
    final vocabularyLevel = _getVocabularyLevel(point);
    final antiRepetitionGuards =
        jsonEncode(_antiRepetitionEngine._getConstraints(minDelay: 60.0));

    return '''
<Prompt>
  <Role strategy="deception_first">Trendy MCQ Architect for Teens</Role>

  <!-- Input Parameters -->
  <TaskParameters>
    <QuantitativeParams>
      <Count min="7" max="20" variable="$count" type="adaptive"/>
      <DifficultyLevels type="enum" values="easy,medium,hard" variable="$difficulty"/>
    </QuantitativeParams>
    <QualitativeParams>
      <Topic ontology-linked="true" context="teen_friendly">
        <Main domain="$subject"/>
        <Subdomains hierarchy="3">
          <Primary>$topic</Primary>
          <Related use="distractor_generation"/>
        </Subdomains>
        <TrendSource source="GoogleTrends,TikTok,YouTube" update="6h"/>
      </Topic>
      <LanguageSupport mode="dynamic">
        <Primary lang="$language" fallback="en-US"/>
        <TranslationEngine version="NLP-3.0"/>
      </LanguageSupport>
      <LearningStyle type="priority" values="$learning" distribution="40%,30%,20%,10%"/>
    </QualitativeParams>
    <UserState>
      <CorrectRate variable="$correct"/>
      <CognitiveLevel variable="${_cognitivel.getCognitiveLevel(baseDifficulty: point)}"/>
      <VocabularyLevel variable="$vocabularyLevel" scale="CEFR"/>
    </UserState>
    <DynamicAntiRepetition source="json" data="$antiRepetitionGuards">
      <TrapPriority type="least_used" weight="0.7"/>
      <SemanticGuard threshold="0.9" action="skip_similar"/>
    </DynamicAntiRepetition>
  </TaskParameters>

  <!-- Processing Logic -->
  <AdaptiveSystem>
    <PerformanceMonitor>
      <UserMetrics>
        <Correctness score="$correct" weight="0.6"/>
        <ResponseTime weight="0.4"/>
      </UserMetrics>
      <AdjustmentLogic>
        <RuleSet complexity="low">
          <Condition>score < 40%</Condition>
          <Action>reduce_cognitive_load level="1"</Action>
        </RuleSet>
      </AdjustmentLogic>
    </PerformanceMonitor>
  </AdaptiveSystem>
  <ProcessingPipeline>
    <Stage order="1" name="TrendBinding" timeout="1s" input="$subject,$topic" source="TrendSource"/>
    <Stage order="2" name="DistractorGeneration" timeout="1s" maxDistractors="4" style="trend_based,fun_creative"/>
    <Stage order="3" name="TuningValidation" timeout="2s"/>
  </ProcessingPipeline>
  <SmartQuestionFeatures>
    <ContextAwareDistractors max="4">
      <CulturalRelevance detector="auto" context="Vietnam,Global" age="10-17"/>
      <TrendRelevance type="dynamic" source="TrendSource"/>
      <TemporalContext range="6m"/>
    </ContextAwareDistractors>
    <AutoHintGenerator>
      <KnowledgeGapPredictor accuracy="90%" personalized="$correct"/>
      <Multimedia type="video,image" examples="TikTok_clip,infographic"/>
      <MisconceptionLibrary size="1M+" categorized_by="$topic,$subject"/>
    </AutoHintGenerator>
  </SmartQuestionFeatures>
  <!-- Output and Metrics -->
  <MetadataArchitecture>
    <CognitiveMapping>
      <Level source="$_cognitivel" target="Bloom"/>
      <Vocabulary tier="$vocabularyLevel" scale="CEFR"/>
    </CognitiveMapping>
    <PerformanceTags>
      <GenerationTime metric="ms"/>
      <DistractorEfficiency score="0-100"/>
      <DeceptionIndex type="AI-calculated"/>
    </PerformanceTags>
  </MetadataArchitecture>
</Prompt>
**Response Template**:
```json
{
  "questions": [
    {
      "question": "Tác phẩm nào sau đây là tác phẩm nổi tiếng nhất của Nguyễn Du?",
      "hints": "Hãy nghĩ về tác phẩm được coi là kiệt tác văn học viết bằng chữ Nôm. Thử viết một đoạn ngắn mô phỏng phong cách của Nguyễn Du.",
      "answer": "Truyện Kiều",
      "distractors": [
        {"type": "chrono", "content": "Văn tế thập loại chúng sinh"},
        {"type": "semantic", "content": "Thơ chữ Hán"},
        {"type": "partial_truth", "content": "Thơ chữ Nôm"}
      ],
      "explanation": "1) Truyện Kiều là tác phẩm nổi tiếng nhất của Nguyễn Du, viết bằng chữ Nôm với phong cách độc đáo. Hãy thử viết một đoạn ngắn theo phong cách này để hiểu sâu hơn. | 2) Nhiều người nhầm lẫn với các tác phẩm khác, nhưng Truyện Kiều là kiệt tác có sức sống lâu dài trong văn học Việt Nam.",
      "metadata": {
        "difficulty": "$difficulty",
        "question_style": "${getQuestionStyleFromCognitiveLevel(_cognitivel.getCognitiveLevel(baseDifficulty: point))}",
        "cognitive_level": "${_cognitivel.getCognitiveLevel(baseDifficulty: point)}",
        "vocabulary_level": "${_getVocabularyLevel(point)}",
        "learning_style": "kinesthetic",
      }
    }
  ]
}

''';
  }

  int _inferGradeLevel17(String subject) {
    // Chuẩn hóa chuỗi
    String normalizedSubject = subject.trim().toLowerCase();
    print(
        "Debug: Normalized input = '$normalizedSubject', codeUnits = ${normalizedSubject.codeUnits}");

    // RegExp chính: khớp "lớp" với Unicode
    final RegExp gradePattern = RegExp(r'lớp\s*(\d+)', unicode: true);
    var match = gradePattern.firstMatch(normalizedSubject);

    // Fallback: nếu không khớp, thử RegExp đơn giản hơn
    if (match == null) {
      final RegExp fallbackPattern = RegExp(r'\d+');
      match = fallbackPattern.firstMatch(normalizedSubject);
      print("Debug: Dùng fallback RegExp cho '$normalizedSubject'");
    }

    // Nếu vẫn không khớp, trả về 1
    if (match == null) {
      print(
          "Debug: Không tìm thấy số lớp trong '$normalizedSubject', mặc định trả về 1");
      return 8;
    }

    // Lấy số lớp
    final int grade = int.parse(match.group(match.groupCount)!);
    print("Debug: Tìm thấy số lớp $grade trong '$normalizedSubject'");

    // Giới hạn trong lớp 1-5
    if (grade >= 6 && grade <= 12) {
      return grade;
    } else {
      print("Debug: Lớp $grade ngoài phạm vi 1-5, trả về 1");
      return 6;
    }
  }

  String _buildQuizOlympiaPrompt({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String difficulty,
    String learning = 'visual,auditory,kinesthetic,digital_interactive',
    String userHistory = '',
  }) {
    // Kiểm tra null và gán giá trị mặc định
    final double correct =
        _calculateCorrectAnswerRate(point) ?? 0.5; // Mặc định 50%
    final antiRepetitionGuards = jsonEncode(
        _antiRepetitionEngine._getConstraints(minDelay: 60.0) ??
            {'default': 'no_constraints'});
    final vocabularyLevel =
        _getVocabularyLevel(point) ?? 'B1'; // Mặc định CEFR B1
    final dynamicStyle = _adjustLearningStyle(learning, correct) ??
        learning; // Giữ nguyên nếu null
    final ageGroup = _inferGradeLevel17(subject);
    final cognitiveLevel =
        _cognitivel.getCognitiveLevel(baseDifficulty: point) ??
            'application'; // Mặc định
    final difficultyScore = _mapDifficultyToScore(difficulty, point, ageGroup);
    final String difficultyDescriptor =
        _getDifficultyDescriptor(difficultyScore);

    print(
        'NAMNM cognitiveLevel $cognitiveLevel ageGroup $ageGroup subject $subject topic $topic dynamicStyle $dynamicStyle antiRepetitionGuards $antiRepetitionGuards');

    return '''
<Prompt>
  <Role type="generator">Olympia Elite Quiz Master</Role>
  <TaskParameters>
    <Quantitative>
      <Count variable="$count" min="5" max="30"/>
      <DifficultyLevels base="$ageGroup" adjuster="$correct" userScore="$point" target="$difficulty" descriptor="$difficultyDescriptor"/>
    </Quantitative>
    <Qualitative>
      <Topic domain="$subject" subdomain="$topic" context="academic_competitive" contextLocation="Vietnam"/>
      <LanguageSupport lang="$language" tone="serious_challenging" vocabLevel="$vocabularyLevel"/>
      <LearningStyle values="$dynamicStyle"/>
      <AcademicSource source="MOET,Springer,arXiv,IMO" update="daily"/>
    </Qualitative>
    <UserState>
      <CorrectRate variable="$correct"/>
      <UserHistory variable="$userHistory" filter="incorrect_answers" weight="0.9"/>
    </UserState>
    <DynamicAntiRepetition source="json" data="$antiRepetitionGuards">
      <TrapPriority type="least_used" weight="0.8"/>
      <SemanticGuard threshold="0.85" action="skip_similar"/>
    </DynamicAntiRepetition>
    
    <QuestionTypes distribution="dynamic">
      <Type name="multiple_choice" weight="${point > 70 ? 0.5 : 0.7}"/>
      <Type name="open_ended" weight="${point > 70 ? 0.2 : 0.1}"/>
      <Type name="matching" weight="0.1"/>
      <Type name="diagram_based" weight="${dynamicStyle.contains('visual') ? 0.2 : 0.1}"/>
      <Type name="case_study" weight="${cognitiveLevel == 'analysis' ? 0.2 : 0.1}"/>
    </QuestionTypes>
    
    <CompetencyFramework>
      <Standard source="MOET,PISA,TIMSS" alignment="0.9"/>
      <SkillsMapping 21stCentury="critical_thinking,problem_solving,creativity"/>
      <ProficiencyLevels scale="1-6" currentLevel="${(point / 20).ceil()}"/>
    </CompetencyFramework>
  </TaskParameters>

  <ProcessingPipeline>
    <Stage name="AgeCheck" input="$ageGroup" enforce="vocab,context,complexity" range="10-18"/>
    <Stage name="KnowledgeBinding" input="$subject,$topic" source="AcademicSource"/>
    <Stage name="DistractorGeneration" maxDistractors="4" style="academic_misconception,logical_challenge,age_$ageGroup"/>
    <Stage name="HintTuning" style="$dynamicStyle" tone="serious_interactive"/>
    
    <AdaptiveLearning>
      <ZoneProximalDevelopment threshold="0.75" adjust="true"/>
      <PerformanceTracking iterations="5" memory="last_20_questions"/>
      <DynamicDifficulty algorithm="bayesian_optimization" target="engagement_maximization"/>
    </AdaptiveLearning>
  </ProcessingPipeline>

  <SmartQuestionFeatures>
    <ContextAwareDistractors>
      <EducationalContext context="Vietnam,Global" ageRange="$ageGroup"/>
      <DifficultyAdjustment level="$difficulty" cognitive="$cognitiveLevel"/>
    </ContextAwareDistractors>
    <InteractiveFeature options="concept_map,simulation" enable="true"/>
    
    <MultimediaElements>
      <Visual type="diagram,chart,image" condition="${dynamicStyle.contains('visual')}"/>
      <Audio type="narration,sound_effect" condition="${dynamicStyle.contains('auditory')}"/>
      <Interactive type="simulation,drag_drop,hotspot" condition="${dynamicStyle.contains('kinesthetic')}"/>
    </MultimediaElements>
    
    <CulturalContext>
      <LocalRelevance region="Vietnam" elements="history,geography,society,science"/>
      <CurrentEvents timeframe="last_3_months" source="VnExpress,TuoiTre,MOET"/>
      <CulturalSensitivity level="high" adaptTo="studentRegion"/>
    </CulturalContext>
    
    <FeedbackSystem>
      <DetailLevel base="${difficulty}" adjust="userPerformance"/>
      <MisconceptionDetection patterns="common_errors_${subject}" response="targetedHint"/>
      <GrowthMindset messages="true" frequency="0.3"/>
    </FeedbackSystem>
  </SmartQuestionFeatures>
  
  <ProcessingOptimization>
    <CacheStrategy time="24h" condition="!topicChanged"/>
    <PreRendering count="next_10_questions" trigger="sessionStart"/>
    <DistributedProcessing enable="true" nodes="3"/>
  </ProcessingOptimization>
</Prompt>
**Response Format**:
```json
{
  "questions": [
    {
      "question": "${_getSampleQuestion17(difficulty, topic, language)}",
      "hints": "${_getSampleHint17(dynamicStyle)}",
      "answer": "${_getSampleAnswer17(difficulty, topic)}",
      "distractors": ${_getSampleDistractors17(difficulty, topic, language)},
      "explanation": "${_getSampleExplanation17(difficulty, topic, language)}",
      "learning_tip": "${_getSampleLearningTip17(dynamicStyle)}",
      "metadata": {
        "difficulty": "$difficulty",
        "cognitive_level": "$cognitiveLevel",
        "vocabulary_level": "$vocabularyLevel",
        "learning_style": "$dynamicStyle"
      }
    }
  ]
}
''';
  }

// Hàm phụ trợ giả định (cần định nghĩa trong mã thực tế)
  double _calculateCorrectAnswerRate(int point) => point / 15; // Ví dụ
  String? _getVocabularyLevel(int point) => point < 30 ? 'A2' : 'B1'; // Ví dụ

// Hàm mẫu tạo câu hỏi (cần định nghĩa trong mã thực tế)
  String _getSampleQuestion17(
      String difficulty, String topic, String language) {
    return language == 'Vietnamese'
        ? "Tác giả nào viết 'Truyện Kiều'?"
        : "Who wrote 'The Tale of Kieu'?";
  }

  String _getSampleHint17(String style) =>
      "Nghĩ về nhà thơ nổi tiếng thời Nguyễn ";
  String _getSampleAnswer17(String difficulty, String topic) => "Nguyễn Du";
  String _getSampleDistractors17(
      String difficulty, String topic, String language) {
    return jsonEncode([
      {
        "type": "semantic",
        "content": language == 'Vietnamese'
            ? "Bà Huyện Thanh Quan"
            : "Ba Huyen Thanh Quan"
      },
      {
        "type": "close_meaning",
        "content": language == 'Vietnamese' ? "Hồ Xuân Hương" : "Ho Xuan Huong"
      },
      {
        "type": "trick",
        "content": language == 'Vietnamese' ? "Nguyễn Trãi" : "Nguyen Trai"
      }
    ]);
  }

  String _getSampleExplanation17(
      String difficulty, String topic, String language) {
    return language == 'Vietnamese'
        ? "Nguyễn Du là tác giả 'Truyện Kiều', tác phẩm nổi tiếng thời Nguyễn."
        : "Nguyen Du wrote 'The Tale of Kieu', a famous work from the Nguyen dynasty.";
  }

  String _getSampleLearningTip17(String style) =>
      "Vẽ sơ đồ về 'Truyện Kiều' để nhớ nhé ";

  String _buildTrainPrompt({
    required String topic,
    required String subject,
    required int point,
    required int count,
    required String language,
    required String difficulty,
    double time = 0.0,
  }) {
    final double correct_rate = _calculateCorrectAnswerRate(point);
    final cognitive_level = getQuestionStyleFromCognitiveLevel(
        _cognitivel.getCognitiveLevel(baseDifficulty: point));
    return '''
<Role type="generator">Adaptive Question Creator</Role>
<!-- Vai trò: Tạo câu hỏi thích ứng cho học sinh -->

<!-- Input Parameters -->
<TaskParameters>
  <Quantitative>
    <QuestionCount min="5" max="15" variable="$count"/>
    <!-- Số lượng câu hỏi từ 5 đến 15, tùy chỉnh theo nhu cầu -->
    <DifficultyLevels type="enum" values="easy,medium,hard" variable="$difficulty"/>
    <!-- Độ khó: dễ, trung bình, khó -->
  </Quantitative>
  
  <Qualitative>
    <Subject domain="$subject" subdomain="$topic"/>
    <!-- Chủ đề: ví dụ Toán - Đại số, Văn - Phân tích tác phẩm -->
    <Language primary="$language" fallback="vi-VN"/>
    <!-- Ngôn ngữ chính (mặc định tiếng Việt nếu không chỉ định) -->
  </Qualitative>
  
  <StudentProfile>
    <Performance variable="$correct_rate" range="0-100%"/>
    <!-- Tỷ lệ trả lời đúng của học sinh -->
    <LearningLevel variable="$cognitive_level" scale="basic,intermediate,advanced"/>
    <!-- Mức nhận thức: cơ bản, trung cấp, nâng cao -->
  </StudentProfile>
</TaskParameters>

<!-- Processing Logic -->
<AdaptiveMechanism>
  <PerformanceTracking>
    <Metrics>
      <Accuracy value="$correct_rate" weight="0.7"/>
      <CompletionTime value="$time" weight="0.3"/>
      <!-- Đánh giá dựa trên độ chính xác (70%) và thời gian làm bài (30%) -->
    </Metrics>
    <AdjustmentRules>
      <!-- Quy tắc điều chỉnh độ khó -->
      IF $correct_rate > 75% THEN $difficulty = "hard"
      IF $correct_rate BETWEEN 40% AND 75% THEN $difficulty = "medium"
      IF $correct_rate < 40% THEN $difficulty = "easy"
    </AdjustmentRules>
  </PerformanceTracking>
</AdaptiveMechanism>

<QuestionDesign>
  <SmartFeatures>
    <Distractors>
      <Relevance type="contextual" source="common_mistakes"/>
      <!-- Đáp án nhiễu dựa trên sai lầm phổ biến -->
      <Quantity value="3"/>
      <!-- 3 đáp án nhiễu + 1 đáp án đúng -->
    </Distractors>
    <Hints>
      <Type value="explanatory"/>
      <!-- Gợi ý giải thích cách làm -->
      <Trigger condition="$correct_rate < 50%"/>
      <!-- Hiện gợi ý nếu đúng dưới 50% -->
    </Hints>
  </SmartFeatures>
</QuestionDesign>

<!-- Output -->
<OutputFormat>
  <QuestionType value="multiple_choice"/>
  <!-- Định dạng: trắc nghiệm -->
  <Structure>
    <QuestionText/>
    <Options count="4"/>
    <CorrectAnswer/>
    <Hint optional="true"/>
  </Structure>
</OutputFormat>

<!-- Evaluation Metrics -->
<PerformanceMetrics>
  <SuccessRate variable="$correct_rate"/>
  <DifficultyFit score="0-100"/>
  <!-- Đo lường mức độ phù hợp của độ khó -->
</PerformanceMetrics>
**Response Format**:
```json
{
  "questions": [
    {
      "question": "Tác phẩm nào sau đây là tác phẩm nổi tiếng nhất của Nguyễn Du?",
      "hints": "Hãy nghĩ về tác phẩm được coi là kiệt tác văn học viết bằng chữ Nôm. Thử viết một đoạn ngắn mô phỏng phong cách của Nguyễn Du.",
      "answer": "Truyện Kiều",
      "distractors": [
        {"type": "chrono", "content": "Văn tế thập loại chúng sinh"},
        {"type": "semantic", "content": "Thơ chữ Hán"},
        {"type": "partial_truth", "content": "Thơ chữ Nôm"}
      ],
      "explanation": "1) Truyện Kiều là tác phẩm nổi tiếng nhất của Nguyễn Du, viết bằng chữ Nôm với phong cách độc đáo. Hãy thử viết một đoạn ngắn theo phong cách này để hiểu sâu hơn. | 2) Nhiều người nhầm lẫn với các tác phẩm khác, nhưng Truyện Kiều là kiệt tác có sức sống lâu dài trong văn học Việt Nam.",
      "learning_tip": "Đây là tác phẩm được viết bằng chữ Nôm và thường xuất hiện trong chương trình học cấp 2.",

      "metadata": {
        "difficulty": "$difficulty",
        "question_style": "${getQuestionStyleFromCognitiveLevel(_cognitivel.getCognitiveLevel(baseDifficulty: point))}",
        "cognitive_level": "${_cognitivel.getCognitiveLevel(baseDifficulty: point)}",
        "vocabulary_level": "${_getVocabularyLevel(point)}",
        "learning_style": "kinesthetic",
      }
    }
  ]
}

''';
  }

// Hàm hỗ trợ điều chỉnh phong cách học tập động
  String _adjustLearningStyle(String userHistory, double correctRate) {
    // Mở rộng phong cách học tập
    Map<String, double> styleScores = {
      'kinesthetic': 0.0,
      'visual': 0.0,
      'auditory': 0.0,
      'reading_writing': 0.0,
      'logical': 0.0,
      'social': 0.0,
      'solitary': 0.0,
    };

    // Mặc định nếu không có lịch sử
    if (userHistory.isEmpty) {
      final defaultScore = 1.0 / styleScores.length;
      return styleScores.keys
          .map((key) => '$key:${defaultScore.toStringAsFixed(2)}')
          .join(',');
    }

    // Phân tích lịch sử
    final historyEntries = userHistory.split(',');
    final List<Map<String, dynamic>> parsedHistory = [];

    // Phân tích và thêm timestamp (nếu có)
    for (var i = 0; i < historyEntries.length; i++) {
      final entry = historyEntries[i];
      final parts = entry.split(':');
      if (parts.length >= 2) {
        final style = parts[0].trim();
        final outcome = parts[1].trim();
        final timestamp = parts.length > 2 ? int.tryParse(parts[2]) : null;

        if (styleScores.containsKey(style)) {
          parsedHistory.add({
            'style': style,
            'outcome': outcome,
            'timestamp': timestamp ?? i, // Dùng index nếu không có timestamp
            'index': i,
          });
        }
      }
    }

    // Sắp xếp theo timestamp mới đến cũ
    parsedHistory.sort((a, b) => b['timestamp'] - a['timestamp']);

    // Áp dụng hệ số suy giảm cho mục cũ hơn
    final totalEntries = parsedHistory.length;
    for (var i = 0; i < parsedHistory.length; i++) {
      final entry = parsedHistory[i];
      final style = entry['style'];
      final outcome = entry['outcome'];

      // Hệ số suy giảm - mục gần đây có trọng số cao hơn
      final recencyWeight = 1.0 - (i / totalEntries) * 0.5; // 0.5 đến 1.0

      // Điểm dựa trên kết quả và trọng số mức độ khó (nếu có)
      double scoreAdjustment;
      if (outcome == 'correct') {
        scoreAdjustment = 1.0;
      } else if (outcome.startsWith('wrong_')) {
        // Phân tích mức độ khó từ wrong_easy, wrong_medium, wrong_hard
        final difficultyParts = outcome.split('_');
        if (difficultyParts.length > 1) {
          final difficulty = difficultyParts[1];
          scoreAdjustment = difficulty == 'hard'
              ? -0.3
              : difficulty == 'medium'
                  ? -0.5
                  : -0.7;
        } else {
          scoreAdjustment = -0.5; // Mặc định
        }
      } else {
        scoreAdjustment = -0.5; // wrong
      }

      // Áp dụng điểm và hệ số suy giảm
      styleScores[style] =
          styleScores[style]! + (scoreAdjustment * recencyWeight);
    }

    // Điều chỉnh dựa trên correctRate với trọng số động
    // Trọng số lịch sử tăng theo lượng dữ liệu
    final historyWeight = min(0.85, 0.5 + (totalEntries / 40) * 0.35);
    final correctRateWeight = 1.0 - historyWeight;

    styleScores.forEach((style, score) {
      // Điều chỉnh với correctRate và tính linh hoạt của phong cách
      final styleFlexibility = _getStyleFlexibility(style);
      final correctRateEffect = (correctRate - 0.5) * 2 * styleFlexibility;

      // Kết hợp điểm từ lịch sử và correctRate
      if (totalEntries > 0) {
        // Chuẩn hóa trong khoảng -1 đến 1
        final normalizedScore = score / totalEntries;
        styleScores[style] = (normalizedScore * historyWeight) +
            (correctRateEffect * correctRateWeight);
      } else {
        styleScores[style] = correctRateEffect * correctRateWeight;
      }
    });

    // Chuyển đổi thành điểm số dương và chuẩn hóa
    double minScore = styleScores.values.reduce(min);
    if (minScore < 0) {
      styleScores.forEach((style, score) {
        styleScores[style] = score - minScore;
      });
    }

    // Đảm bảo có giá trị tối thiểu
    styleScores.forEach((style, score) {
      styleScores[style] = max(0.05, score);
    });

    // Chuẩn hóa tổng = 1
    final totalScore = styleScores.values.reduce((a, b) => a + b);
    styleScores.forEach((style, score) {
      styleScores[style] = score / totalScore;
    });

    // Chỉ giữ lại 3-5 phong cách hàng đầu
    final sortedStyles = styleScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Lấy top phong cách và chuẩn hóa lại
    final topStyles = sortedStyles.take(4).toList();
    final topTotal = topStyles.fold(0.0, (sum, entry) => sum + entry.value);

    final result = topStyles
        .map((e) => '${e.key}:${(e.value / topTotal).toStringAsFixed(2)}')
        .join(',');

    return result;
  }

// Hàm phụ trợ cho biết mức độ linh hoạt của từng phong cách
  double _getStyleFlexibility(String style) {
    switch (style) {
      case 'visual':
        return 0.8;
      case 'auditory':
        return 0.7;
      case 'kinesthetic':
        return 1.0;
      case 'reading_writing':
        return 0.6;
      case 'logical':
        return 0.9;
      case 'social':
        return 0.7;
      case 'solitary':
        return 0.8;
      default:
        return 0.7;
    }
  }

  getQuestionStyleFromCognitiveLevel(String cognitiveLevel) {
    switch (cognitiveLevel) {
      case 'Remembering':
        return 'factBased';
      case 'Understanding':
        return 'conceptual';
      case 'Applying':
        return 'application';
      case 'Analyzing':
        return 'comparison'; // Hoặc causeAndEffect
      case 'Evaluating':
        return 'problemSolving'; // Hoặc scenarioBased
      case 'Creating':
        return 'scenarioBased'; // Hoặc problemSolving
      default:
        return 'factBased';
    }
  }

  List<Map<String, dynamic>> _parseApiResponse(String response) {
    try {
      final jsonData = jsonDecode(response) as Map<String, dynamic>;
      final questions =
          List<Map<String, dynamic>>.from(jsonData['questions'] ?? []);
      if (questions.isEmpty) {
        print('NAMNM: No questions found in API response');
      }
      return questions;
    } catch (e) {
      print('NAMNM: Failed to parse API response - $e');
      return [];
    }
  }

  List<Map<String, dynamic>> _handleGenerationError(
      String topic, dynamic error) {
    // Log lỗi chi tiết
    _logger.e('NAMNM: Error generating questions for topic "$topic" - $error');

    // Xử lý các trường hợp lỗi cụ thể
    if (error is RateLimitException) {
      _logger.w('NAMNM: Rate limit exceeded, using fallback questions');
      return _generateFallbackQuestions(topic);
    }

    if (error is NetworkException) {
      _logger.w(
          'NAMNM: Network error, using fallback due to unavailable connection');
      return _generateFallbackQuestions(topic);
    }

    // Trường hợp lỗi chung
    _logger.w('NAMNM: Unexpected error, falling back to default questions');
    return _generateFallbackQuestions(topic);
  }

  List<Map<String, dynamic>> _generateFallbackQuestions(String topic) {
    return List<Map<String, dynamic>>.from(quizTemp);
  }
}

// Thêm định nghĩa CacheEntry

class CacheService {
  final _memoryCache = <String, CacheEntry>{};
  final Duration expireDuration; // Thời gian hết hạn mặc định
  final int maxSize; // Kích thước tối đa của memory cache
  final _hitCount = <String, int>{}; // Đếm lượt truy cập
  final _accessTime = <String, DateTime>{}; // Theo dõi thời gian truy cập (LRU)
  final _logger = Logger(); // Giả định có Logger để ghi log

  CacheService({
    this.expireDuration = const Duration(minutes: 30),
    this.maxSize = 1000,
  });

  /// Lấy dữ liệu từ cache (memory hoặc file)
  Future<List<Map<String, dynamic>>?> getCachedData(String key) async {
    // Kiểm tra memory cache trước
    final memoryData = _getMemoryCache(key);
    if (memoryData != null) {
      _hitCount[key] = (_hitCount[key] ?? 0) + 1;
      _accessTime[key] = DateTime.now();
      return memoryData;
    }

    // Nếu không có trong memory, lấy từ file
    final fileData = await _getFileCache(key);
    if (fileData != null) {
      await updateCaches(key, fileData); // Cập nhật memory cache
      return fileData;
    }
    return null;
  }

  /// Cập nhật cache với dữ liệu mới
  Future<void> updateCaches(String key, List<Map<String, dynamic>> data) async {
    // Xóa mục cũ nếu vượt kích thước tối đa
    if (_memoryCache.length >= maxSize) {
      _evictLeastUsed();
    }

    // Lưu vào memory cache
    _memoryCache[key] = CacheEntry(data, DateTime.now().add(expireDuration));
    _hitCount[key] = _hitCount[key] ?? 0; // Khởi tạo hit count
    _accessTime[key] = DateTime.now();

    // Lưu vào file cache (nén dữ liệu)
    try {
      final encodedData = jsonEncode({'data': data});
      await DefaultCacheManager().putFile(
        key,
        utf8.encode(encodedData),
        maxAge: expireDuration,
        fileExtension: 'json',
      );
    } catch (e) {
      _logger.e('Failed to update file cache for key: $key, error: $e');
    }
  }

  /// Lấy từ memory cache
  List<Map<String, dynamic>>? _getMemoryCache(String key) {
    final entry = _memoryCache[key];
    if (entry == null || entry.isExpired) {
      _memoryCache.remove(key);
      _hitCount.remove(key);
      _accessTime.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Lấy từ file cache
  Future<List<Map<String, dynamic>>?> _getFileCache(String key) async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(key);
      if (fileInfo == null || !fileInfo.validTill.isAfter(DateTime.now())) {
        await DefaultCacheManager().removeFile(key);
        return null;
      }
      final content = await fileInfo.file.readAsString();
      final data = jsonDecode(content)['data'] as List;
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      _logger.w('Error reading file cache for key: $key, error: $e');
      await DefaultCacheManager().removeFile(key);
      return null;
    }
  }

  /// Xóa mục ít dùng nhất (LFU) hoặc gần đây nhất (LRU)
  void _evictLeastUsed() {
    if (_memoryCache.isEmpty) return;

    // Sử dụng PriorityQueue để tìm key ít dùng nhất nhanh hơn
    final queue = PriorityQueue<MapEntry<String, int>>(
      (a, b) => a.value.compareTo(b.value), // Sắp xếp theo hit count
    )..addAll(_hitCount.entries.where((e) => _memoryCache.containsKey(e.key)));

    if (queue.isNotEmpty) {
      final leastUsed = queue.removeFirst().key;
      _memoryCache.remove(leastUsed);
      _hitCount.remove(leastUsed);
      _accessTime.remove(leastUsed);
    }
  }

  /// Xóa toàn bộ cache
  Future<void> clearCache() async {
    _memoryCache.clear();
    _hitCount.clear();
    _accessTime.clear();
    await DefaultCacheManager().emptyCache();
  }

  /// Kiểm tra trạng thái cache
  Map<String, dynamic> getCacheStats() {
    return {
      'memory_size': _memoryCache.length,
      'hit_counts': _hitCount,
      'expired_entries':
          _memoryCache.entries.where((e) => e.value.isExpired).length,
    };
  }
}

class CacheEntry {
  final List<Map<String, dynamic>> data;
  final DateTime expiresAt;

  CacheEntry(this.data, this.expiresAt);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AdaptiveLearningEngine {
  // Lưu trữ điểm số và số lần trả lời cho từng cấp độ Bloom
  final Map<String, _ScoreData> _cognitiveScores = {
    'Remembering': _ScoreData(),
    'Understanding': _ScoreData(),
    'Applying': _ScoreData(),
    'Analyzing': _ScoreData(),
    'Evaluating': _ScoreData(),
    'Creating': _ScoreData(),
  };

  // Ngưỡng để chuyển cấp và giảm điểm
  final double _levelUpThreshold;
  static const double _decayFactor = 0.1; // Hệ số giảm điểm khi sai

  AdaptiveLearningEngine({double levelUpThreshold = 0.7})
      : _levelUpThreshold = levelUpThreshold;

  /// Trả về cấp độ Bloom cao nhất đạt ngưỡng dựa trên tỷ lệ đúng
  String getCognitiveLevel({int? baseDifficulty}) {
    String highestLevel = 'Remembering'; // Mặc định
    for (var entry in _cognitiveScores.entries) {
      final scoreData = entry.value;
      final accuracy =
          scoreData.attempts > 0 ? scoreData.score / scoreData.attempts : 0;
      if (accuracy >= _levelUpThreshold) {
        highestLevel = entry.key;
      } else if (scoreData.attempts > 0) {
        break; // Dừng khi gặp cấp độ không đạt ngưỡng
      }
    }
    return highestLevel;
  }

  /// Cập nhật điểm số dựa trên câu trả lời đúng/sai
  void updateCognitiveLevel(String level, bool isCorrect) {
    final scoreData = _cognitiveScores[level]!;
    scoreData.attempts++;
    scoreData.score += isCorrect ? 1 : -_decayFactor; // Tăng hoặc giảm điểm
    scoreData.score = scoreData.score.clamp(0, double.infinity); // Không âm
  }

  /// Reset toàn bộ dữ liệu
  void reset() {
    _cognitiveScores.forEach((_, data) => data.reset());
  }
}

/// Lớp phụ để lưu trữ điểm số và số lần trả lời
class _ScoreData {
  double score = 0;
  int attempts = 0;

  void reset() {
    score = 0;
    attempts = 0;
  }
}
