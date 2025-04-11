import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nemoai/app/data/providers/viewmodel/base_model.dart';
import 'package:nemoai/app/data/providers/viewmodel/chat_view_model.dart';
import 'package:nemoai/app/data/providers/viewmodel/exam_prep_view_model.dart';

import '../../../core/utils/utils.dart';
import '../../middleware/api_services.dart';
import 'package:nemoai/app/data/models/quiz_question_model.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:convert';

class TopicSummarizerView extends BaseModel {
  List<QuizQuestion> questionsTemp = [];
  GoogleGenerativeServices generativeServices = GoogleGenerativeServices();
  final _cacheManager = DefaultCacheManager();

  String summary = '';

  keyboard(bool value) {
    Function(bool value) keyboard = ChatViewModel().keyboardAppear;
    return keyboard;
  }

  String constructPromptAnlystic() {
    return '''
# **ROLE**: Educational Analytics Expert  
**GOAL**: Analyze player's incorrect answers and generate detailed weakness assessments  in "Tiếng Việt"

### **INPUT REQUIREMENTS**  
```json  
{  
  "player_answers": [  
    {  
      "question": ${questionsTemp.last.question},  
      
    }  
  ]  
}  
ANALYSIS PROCESS
Error Fragmentation

-Quantify error distribution across:

-Cognitive levels (Remembering/Analyzing/Applying)

-Question types (Definition/Cause-Effect)

-Vocabulary complexity

Pattern Detection
def detect_patterns(answers):  
    patterns = {  
        "spatial_confusion": "Mistakes in geometric geography",  
        "historical_misconception": "Chronological misunderstanding"  
    }  
    return patterns  
Competency Profiling

Metric	Analysis	Example
Spatial Reasoning	73% error in shape questions	Italy → Brazil confusion
Analytical Skills	60% failure at Analysis level	Can't connect features to functions
SAMPLE OUTPUT
"Key weaknesses identified:  
1. **Spatial Reasoning** (82% errors):  
   - Confuses country geographical features  
   - Lacks map-cultural correlation skills  

2. **Multi-factor Analysis** (65%):  
   - Fails to connect geometric + historical data  
   - Example: 'Boot-shaped country' requires Italy + Roman history knowledge  

**Recommendations:**  
- Interactive layered map exercises  
- Geography-culture-history connection drills"  
''';
  }

  Future<void> loadIncorrectFromCache() async {
    final fileInfo = await _cacheManager.getFileFromCache("incorrect");
    try {
      final fileContent = await fileInfo!.file.readAsString();
      final decodedData = jsonDecode(fileContent)['data'];
      if (decodedData is List) {
        final data = List<Map<String, dynamic>>.from(decodedData);
        // Convert Map data to QuizQuestion objects
        final cachedQuestions =
            data.map((item) => QuizQuestion.fromJson(item)).toList();
        questionsTemp.addAll(cachedQuestions);
        questionsTemp.shuffle();
      }
    } catch (e) {
      print('Error loading questions from cache: $e');
    }
  }

  Future<void> summarizeTopic() async {
    try {
      loadIncorrectFromCache();

      final String summaryText =
          await generativeServices.getText(constructPromptAnlystic());
      summary = summaryText;

      updateUI(); // Update UI with the retrieved summary
      notifyListeners();
    } catch (e) {
      // Handle potential errors during API call
      if (e is SocketException) {
        AppUtils.showError('No Internet Connection. Please try again later $e');
        log("No Internet Connection. Please try again later $e");
      } else {
        AppUtils.showError('An unknown error occurred: $e');
      }
      if (kDebugMode) {
        print("Error generating summary: $e");
      }
    }
  }
}
