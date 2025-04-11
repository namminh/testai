const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { GoogleGenerativeAI } = require("@google/generative-ai");

admin.initializeApp();

// Khởi tạo Gemini API
const genAI = new GoogleGenerativeAI("AIzaSyA6PMaMWK-gwZhpfoEHuLnM4YITgyg11tY"); // Thay bằng API Key thực tế
const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" }); // Sửa thành model hợp lệ

// Hàm phụ trợ
function calculateCorrectAnswerRate(points) {
  return Math.min(points / 100, 1);
}

function getCognitiveLevel(points) {
  if (points < 30) return "basic";
  if (points < 70) return "intermediate";
  return "advanced";
}

exports.sendDailyQuiz = functions.pubsub
  .schedule("every day 09:00")
  .timeZone("Asia/Ho_Chi_Minh")
  .onRun(async (context) => {
    const trends = [
      "Công nghệ",
      "Thể thao",
      "Lịch sử",
      "Giáo dục",
    ];
    const selectedTrend = trends[Math.floor(Math.random() * trends.length)];

    const params = {
      topic: selectedTrend,
      subject: selectedTrend.split(" ")[0],
      point: 50,
      count: 1,
      language: "vi-VN",
      difficulty: "hard",
      learning: "visual,auditory",
    };

    const correctRate = calculateCorrectAnswerRate(params.point);
    const cognitiveLevel = getCognitiveLevel(params.point);
    const date = new Date().toISOString();

      const prompt = `
<Prompt>
  <Role>Dynamic Trend-Based Olympia Quiz Creator</Role>
  <Task>Create a single engaging multiple-choice quiz question based on the trending topic "${params.topic}" from Google Trends Vietnam (${date}). The question must be short (max 100 characters) and reflect daily news updates.</Task>
  <Parameters>
    <Difficulty>${params.difficulty}</Difficulty>
    <Language>${params.language}</Language>
    <CognitiveLevel>${cognitiveLevel}</CognitiveLevel>
    <CulturalRelevance>Vietnam</CulturalRelevance>
    <LengthConstraint>question <= 100 characters</LengthConstraint>
    <UpdateFrequency>daily</UpdateFrequency>
    <Source>Google Trends Vietnam, daily news</Source>
  </Parameters>
  <OutputFormat>
    Return a JSON object with the following structure:
    {
      "question": "string",
      "distractors": ["string", "string", "string", "string"],
      "answer": "string",
      "hint": "string",
      "explanation": "string"
    }
  </OutputFormat>
</Prompt>
    `;

    try {
      const result = await model.generateContent(prompt);
      const rawResponse = result.response.text();
      const jsonMatch = rawResponse.match(/{[\s\S]*}/);
      if (!jsonMatch) throw new Error("No JSON found in response");
      const quizData = JSON.parse(jsonMatch[0]);

      const payload = {
        notification: {
          title: "Câu đố Olympia hàng ngày!",
          body: quizData.question,
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK", // Di chuyển vào data
          question: quizData.question,
          distractors: JSON.stringify(quizData.distractors),
          answer: quizData.answer,
          hint: quizData.hint,
          explanation: quizData.explanation,
        },
        topic: "quiz_users",
      };

      await admin.messaging().send(payload);
      console.log("Gửi thông báo thành công:", quizData.question);
    } catch (error) {
      console.error("Lỗi khi tạo câu hỏi hoặc gửi thông báo:", error.message);
      const fallbackPayload = {
        notification: {
          title: "Câu đố Olympia hàng ngày!",
          body: "Thủ đô Việt Nam là gì?",
        },
        topic: "quiz_users",
      };
      await admin.messaging().send(fallbackPayload);
    }
  });