import '../../data/models/quiz_question_model.dart';

class QuizConstant {
  static List<QuizQuestion> quiz = [
    // 1. Lập trình
    QuizQuestion(
      question:
          "Ngôn ngữ lập trình nào được sử dụng phổ biến nhất để phát triển ứng dụng di động iOS?",
      hints:
          "Đây là ngôn ngữ chính cho iOS, hãy tưởng tượng logo của Apple. (Visual)",
      answer: "Swift",
      explanation:
          "1) Swift là ngôn ngữ lập trình được Apple phát triển cho iOS. | 2) Nhiều người nhầm với Java vì nó phổ biến cho Android.",
      learningTip:
          "Vẽ biểu tượng Apple và viết 'Swift' lên đó để nhớ lâu hơn (Visual).",
      cognitiveLevel: "Understanding",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "visual",
      activity: "draw_a_picture",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Java",
        ),
        Distractor(type: "wrong", content: "Python"),
        Distractor(type: "wrong", content: "C++"),
      ],
    ),

    // 2. Toán học
    QuizQuestion(
      question: "Số nào sau đây là số chẵn?",
      hints: "Nghe từ 'chẵn' và nghĩ về số chia hết cho 2. (Auditory)",
      answer: "6",
      explanation:
          "1) Số chẵn là số chia hết cho 2, như 6. | 2) Nhiều người nhầm 7 vì gần số chẵn.",
      learningTip:
          "Lặp lại 'số chẵn chia hết cho 2' thành tiếng để nhớ (Auditory).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "auditory",
      activity: "listen_to_audio",
      distractors: [
        Distractor(
          type: "semantic",
          content: "7",
        ),
        Distractor(type: "wrong", content: "3"),
        Distractor(type: "wrong", content: "9"),
      ],
    ),

    // 3. Khoa học
    QuizQuestion(
      question: "Loài động vật nào sau đây có vú?",
      hints:
          "Thử cầm một quả bóng và nghĩ về loài nuôi con bằng sữa. (Kinesthetic)",
      answer: "Cá heo",
      explanation:
          "1) Cá heo là động vật có vú, nuôi con bằng sữa. | 2) Nhiều người nhầm cá sấu vì sống dưới nước.",
      learningTip:
          "Cầm quả bóng và giả vờ cho con bú để nhớ cá heo (Kinesthetic).",
      cognitiveLevel: "Understanding",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "kinesthetic",
      activity: "act_out",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Cá sấu",
        ),
        Distractor(type: "wrong", content: "Rắn"),
        Distractor(type: "wrong", content: "Cá mập"),
      ],
    ),

    // 4. Văn học
    QuizQuestion(
      question: "Tác phẩm nào của Nguyễn Du nổi tiếng nhất?",
      hints: "Hãy tưởng tượng một cuốn sách cổ bằng chữ Nôm. (Visual)",
      answer: "Truyện Kiều",
      explanation:
          "1) Truyện Kiều là kiệt tác của Nguyễn Du, viết bằng chữ Nôm. | 2) Nhiều người nhầm với thơ chữ Hán vì ông cũng sáng tác loại này.",
      learningTip: "Vẽ một cuốn sách cổ và ghi 'Truyện Kiều' để nhớ (Visual).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "visual",
      activity: "draw_a_picture",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Thơ chữ Hán",
        ),
        Distractor(type: "wrong", content: "Chinh phụ ngâm"),
        Distractor(type: "wrong", content: "Nam quốc sơn hà"),
      ],
    ),

    // 5. Lịch sử
    QuizQuestion(
      question: "Ai là vị vua đầu tiên của nhà Nguyễn?",
      hints: "Nghe tên một vị vua bắt đầu bằng chữ G. (Auditory)",
      answer: "Gia Long",
      explanation:
          "1) Gia Long là vua đầu tiên của nhà Nguyễn, trị vì từ 1802. | 2) Nhiều người nhầm với Minh Mạng vì nổi tiếng hơn.",
      learningTip: "Lặp lại 'Gia Long' thành tiếng để ghi nhớ (Auditory).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "auditory",
      activity: "listen_to_audio",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Minh Mạng",
        ),
        Distractor(type: "wrong", content: "Thiệu Trị"),
        Distractor(type: "wrong", content: "Tự Đức"),
      ],
    ),

    // 6. Toán học
    QuizQuestion(
      question: "Tổng của 5 và 7 là bao nhiêu?",
      hints: "Thử đếm trên tay từ 5 đến 7. (Kinesthetic)",
      answer: "12",
      explanation:
          "1) 5 + 7 = 12, phép cộng cơ bản. | 2) Nhiều người nhầm với 11 vì đếm sai một đơn vị.",
      learningTip: "Dùng ngón tay đếm từ 5 đến 7 để nhớ (Kinesthetic).",
      cognitiveLevel: "Application",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "kinesthetic",
      activity: "act_out",
      distractors: [
        Distractor(
          type: "semantic",
          content: "11",
        ),
        Distractor(type: "wrong", content: "10"),
        Distractor(type: "wrong", content: "13"),
      ],
    ),

    // 7. Khoa học
    QuizQuestion(
      question: "Hành tinh nào gần Mặt Trời nhất?",
      hints: "Hãy tưởng tượng một vòng tròn gần ánh sáng nhất. (Visual)",
      answer: "Thủy Tinh",
      explanation:
          "1) Thủy Tinh (Mercury) là hành tinh gần Mặt Trời nhất. | 2) Nhiều người nhầm với sao Hỏa vì màu đỏ nổi bật.",
      learningTip: "Vẽ Mặt Trời và một vòng tròn nhỏ gần nhất để nhớ (Visual).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "visual",
      activity: "draw_a_picture",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Sao Hỏa",
        ),
        Distractor(type: "wrong", content: "Trái Đất"),
        Distractor(type: "wrong", content: "Sao Mộc"),
      ],
    ),

    // 8. Lập trình
    QuizQuestion(
      question: "Flutter dùng ngôn ngữ lập trình nào?",
      hints: "Nghe từ 'Dart' và nghĩ về mũi tên. (Auditory)",
      answer: "Dart",
      explanation:
          "1) Flutter dùng Dart, ngôn ngữ do Google phát triển. | 2) Nhiều người nhầm với Java vì cũng của Google.",
      learningTip: "Lặp lại 'Dart như mũi tên phóng nhanh' để nhớ (Auditory).",
      cognitiveLevel: "Understanding",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "auditory",
      activity: "listen_to_audio",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Java",
        ),
        Distractor(type: "wrong", content: "Kotlin"),
        Distractor(type: "wrong", content: "Ruby"),
      ],
    ),

    // 9. Văn học
    QuizQuestion(
      question: "Nhân vật chính trong 'Truyện Kiều' là ai?",
      hints: "Thử diễn cảnh một cô gái bị bán đi. (Kinesthetic)",
      answer: "Thúy Kiều",
      explanation:
          "1) Thúy Kiều là nhân vật chính trong Truyện Kiều. | 2) Nhiều người nhầm với Thúy Vân vì là em gái.",
      learningTip: "Diễn cảnh Thúy Kiều bị bán để nhớ cảm xúc (Kinesthetic).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "kinesthetic",
      activity: "act_out",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Thúy Vân",
        ),
        Distractor(type: "wrong", content: "Kim Trọng"),
        Distractor(type: "wrong", content: "Từ Hải"),
      ],
    ),

    // 10. Lịch sử
    QuizQuestion(
      question: "Trận đánh nào đánh dấu sự khởi đầu của Cách mạng Tháng Tám?",
      hints: "Hãy tưởng tượng một lá cờ đỏ tung bay. (Visual)",
      answer: "Tổng khởi nghĩa ở Hà Nội",
      explanation:
          "1) Tổng khởi nghĩa ở Hà Nội (19/8/1945) đánh dấu Cách mạng Tháng Tám. | 2) Nhiều người nhầm với Điện Biên Phủ vì nổi tiếng.",
      learningTip: "Vẽ lá cờ đỏ và ghi ngày 19/8 để nhớ (Visual).",
      cognitiveLevel: "Understanding",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "visual",
      activity: "draw_a_picture",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Điện Biên Phủ",
        ),
        Distractor(type: "wrong", content: "Bạch Đằng"),
        Distractor(type: "wrong", content: "Chi Lăng"),
      ],
    ),

    // 11. Khoa học
    QuizQuestion(
      question: "Nước ở trạng thái nào khi nhiệt độ là 0°C?",
      hints: "Nghe âm thanh 'kẹt kẹt' của băng tan. (Auditory)",
      answer: "Lỏng và rắn",
      explanation:
          "1) Ở 0°C, nước có thể là lỏng hoặc rắn (băng). | 2) Nhiều người nhầm chỉ là rắn vì liên tưởng băng.",
      learningTip: "Lắng nghe âm thanh băng tan để liên tưởng (Auditory).",
      cognitiveLevel: "Application",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "auditory",
      activity: "listen_to_audio",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Rắn",
        ),
        Distractor(type: "wrong", content: "Khí"),
        Distractor(type: "wrong", content: "Lỏng"),
      ],
    ),

    // 12. Toán học
    QuizQuestion(
      question: "Hình nào có 4 cạnh bằng nhau?",
      hints: "Thử xếp 4 que diêm thành hình để kiểm tra. (Kinesthetic)",
      answer: "Hình vuông",
      explanation:
          "1) Hình vuông có 4 cạnh bằng nhau. | 2) Nhiều người nhầm với hình chữ nhật vì cũng có 4 cạnh.",
      learningTip: "Dùng que diêm xếp hình vuông để nhớ (Kinesthetic).",
      cognitiveLevel: "Understanding",
      questionStyle: "multiple_choice",
      vocabularyLevel: "BEGINNER",
      learningStyle: "kinesthetic",
      activity: "act_out",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Hình chữ nhật",
        ),
        Distractor(type: "wrong", content: "Hình tròn"),
        Distractor(type: "wrong", content: "Hình tam giác"),
      ],
    ),

    // 13. Lập trình
    QuizQuestion(
      question: "Widget nào trong Flutter dùng để hiển thị danh sách cuộn?",
      hints: "Hãy tưởng tượng một danh sách dài cuộn lên xuống. (Visual)",
      answer: "ListView",
      explanation:
          "1) ListView hiển thị danh sách cuộn trong Flutter. | 2) Nhiều người nhầm với Column vì cũng chứa nhiều phần tử.",
      learningTip: "Vẽ một danh sách dài và mũi tên cuộn để nhớ (Visual).",
      cognitiveLevel: "Application",
      questionStyle: "multiple_choice",
      vocabularyLevel: "ADVANCED",
      learningStyle: "visual",
      activity: "draw_a_picture",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Column",
        ),
        Distractor(type: "wrong", content: "Row"),
        Distractor(type: "wrong", content: "Text"),
      ],
    ),

    // 14. Văn học
    QuizQuestion(
      question: "Bài thơ 'Tràng giang' được sáng tác bởi ai?",
      hints: "Nghe câu 'Sóng gợn tràng giang buồn điệp điệp'. (Auditory)",
      answer: "Huy Cận",
      explanation:
          "1) Huy Cận là tác giả của 'Tràng giang'. | 2) Nhiều người nhầm với Xuân Diệu vì cùng thời kỳ.",
      learningTip: "Lặp lại câu thơ thành tiếng để nhớ Huy Cận (Auditory).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "auditory",
      activity: "listen_to_audio",
      distractors: [
        Distractor(
          type: "semantic",
          content: "Xuân Diệu",
        ),
        Distractor(type: "wrong", content: "Lưu Trọng Lư"),
        Distractor(type: "wrong", content: "Hàn Mặc Tử"),
      ],
    ),

    // 15. Lịch sử
    QuizQuestion(
      question: "Năm nào Việt Nam giành độc lập từ thực dân Pháp?",
      hints: "Thử đứng lên và hô 'Cách mạng thành công'. (Kinesthetic)",
      answer: "1945",
      explanation:
          "1) Việt Nam giành độc lập vào năm 1945 (2/9). | 2) Nhiều người nhầm với 1954 vì chiến thắng Điện Biên Phủ.",
      learningTip: "Đứng lên và hô '1945' để ghi nhớ (Kinesthetic).",
      cognitiveLevel: "Knowledge",
      questionStyle: "multiple_choice",
      vocabularyLevel: "INTERMEDIATE",
      learningStyle: "kinesthetic",
      activity: "act_out",
      distractors: [
        Distractor(
          type: "semantic",
          content: "1954",
        ),
        Distractor(type: "wrong", content: "1930"),
        Distractor(type: "wrong", content: "1975"),
      ],
    ),
  ];
}
