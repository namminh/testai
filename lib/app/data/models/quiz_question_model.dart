class QuizQuestion {
  final String question;
  final String hints;
  final String answer;
  final String explanation;
  final String cognitiveLevel;
  final String questionStyle;
  final String vocabularyLevel;
  final String learningTip; // Trường mới

  final String learningStyle; // Trường mới
  final String activity; // Trường mới
  final List<Distractor> distractors;

  QuizQuestion({
    required this.question,
    required this.hints,
    required this.answer,
    required this.explanation,
    required this.cognitiveLevel,
    required this.questionStyle,
    required this.vocabularyLevel,
    required this.learningStyle, // Thêm vào constructor
    required this.learningTip, // Thêm vào constructor

    required this.activity, // Thêm vào constructor
    required this.distractors,
  });

  // Hàm fromJson để ánh xạ từ JSON
  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    return QuizQuestion(
      question: json['question']?.toString() ?? 'Câu hỏi mẫu',
      hints: json['hints']?.toString() ?? 'Không có gợi ý',
      answer: json['answer']?.toString() ?? 'Đáp án mẫu',
      explanation: json['explanation']?.toString() ?? 'Giải thích mẫu',
      learningTip: json['learning_tip']?.toString() ?? 'Giải thích mẫu',

      cognitiveLevel:
          metadata['cognitive_level']?.toString() ?? 'Understanding',
      questionStyle: metadata['question_style']?.toString() ?? 'default',
      vocabularyLevel:
          metadata['vocabulary_level']?.toString() ?? 'INTERMEDIATE',
      learningStyle: metadata['learning_style']?.toString() ??
          'visual', // Ánh xạ trường mới
      activity: metadata['trend_relevance']?.toString() ??
          'no_activity', // Ánh xạ trường mới
      distractors: (json['distractors'] as List<dynamic>?)
              ?.map((d) => Distractor.fromJson(d))
              .toList() ??
          [],
    );
  }

  // Hàm toJson cải tiến
  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'hints': hints,
      'answer': answer,
      'explanation': explanation,
      'learning_tip': learningTip,
      'distractors': distractors.map((d) => d.toJson()).toList(),
      'metadata': {
        'difficulty': '\$difficulty', // Giá trị mẫu như trong JSON
        'question_style': questionStyle,
        'cognitive_level': cognitiveLevel,
        'vocabulary_level': vocabularyLevel,
        'learning_style': learningStyle, // Thêm trường mới
        'trend_relevance': activity, // Thêm trường mới
      },
    };
  }
}

// Class Distractor (giả định)
class Distractor {
  final String type;
  final String content;

  Distractor({required this.type, required this.content});

  factory Distractor.fromJson(Map<String, dynamic> json) {
    return Distractor(
      type: json['type']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
    };
  }
}
