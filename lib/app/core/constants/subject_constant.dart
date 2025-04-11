import '../../data/models/Subject.dart';
import 'package:flutter/material.dart';

class SubjectConstant {
  static List<Subject> subjects = [
    Subject(
      name: 'Khoa học',
      englishName: 'Science',
      icon: Icons.science,
      topics: [
        Topic(name: 'Vật lý', englishName: 'Physics'),
        Topic(name: 'Hóa học', englishName: 'Chemistry'),
        Topic(name: 'Sinh học', englishName: 'Biology'),
        Topic(name: 'Thiên văn học', englishName: 'Astronomy'),
      ],
    ),
    Subject(
      name: 'Thời sự',
      englishName: 'Current Affairs',
      icon: Icons.newspaper, // Choose an appropriate icon for Current Affairs
      topics: [
        Topic(name: 'Chính trị', englishName: 'Politics'),
        Topic(name: 'Kinh tế', englishName: 'Economy'),
        Topic(name: 'Xã hội', englishName: 'Society'),
        Topic(name: 'Môi trường', englishName: 'Environment'),
        Topic(name: 'Quốc tế', englishName: 'International'),
        Topic(
            name: 'Khoa học - Công nghệ',
            englishName:
                'Science & Technology'), // Combine these for broader coverage
      ],
    ),
    Subject(
        name: 'Ngôn ngữ',
        englishName: 'Language',
        icon: Icons.language,
        topics: [
          Topic(name: 'English', englishName: 'English'),
          Topic(name: 'Tiếng Pháp', englishName: 'French'),
          Topic(name: 'Tiếng Trung', englishName: 'Chinese'),
          Topic(name: 'Tiếng Nhật', englishName: 'Japanese'),
        ]),
    Subject(
      name: 'Lịch sử',
      englishName: 'History',
      icon: Icons.history_edu,
      topics: [
        Topic(name: 'Lịch sử Việt Nam', englishName: 'Vietnamese History'),
        Topic(name: 'Lịch sử thế giới', englishName: 'World History'),
        Topic(name: 'Lịch sử các triều đại', englishName: 'Dynastic History'),
      ],
    ),
    Subject(
      name: 'Địa lý',
      englishName: 'Geography',
      icon: Icons.public,
      topics: [
        Topic(name: 'Địa lý Việt Nam', englishName: 'Vietnamese Geography'),
        Topic(name: 'Địa lý thế giới', englishName: 'World Geography'),
        Topic(name: 'Địa lý tự nhiên', englishName: 'Physical Geography'),
        Topic(
            name: 'Địa lý kinh tế - xã hội',
            englishName: 'Socio-economic Geography'),
      ],
    ),
    Subject(
      name: 'Văn học',
      englishName: 'Literature',
      icon: Icons.book,
      topics: [
        Topic(name: 'Văn học Việt Nam', englishName: 'Vietnamese Literature'),
        Topic(name: 'Văn học nước ngoài', englishName: 'Foreign Literature'),
        Topic(name: 'Tác giả', englishName: 'Authors'),
        Topic(name: 'Tác phẩm', englishName: 'Literary Works'),
      ],
    ),
    Subject(
        name: 'Lớp 1', // Tên môn học (Tiếng Việt)
        englishName:
            'Grade 1', // Tên môn học (Tiếng Anh) - Sửa lại cho đúng cấp độ
        icon: Icons.child_care, // Biểu tượng phù hợp với trẻ em
        topics: [
          Topic(
              name: 'Toán',
              englishName:
                  'Mathematics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tiếng Việt',
              englishName:
                  'Vietnamese'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Sửa lại cho đúng tên môn
          Topic(
              name: 'English',
              englishName:
                  'English'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tự nhiên và Xã hội',
              englishName:
                  'Nature and Society'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Tên chuẩn của môn học lớp 1
          Topic(
              name: 'Đạo Đức',
              englishName:
                  'Ethics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Đạo Đức
          Topic(
              name: 'Âm Nhạc',
              englishName:
                  'Music'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Âm Nhạc
          Topic(
              name: 'Mỹ Thuật',
              englishName:
                  'Art'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Mỹ Thuật
          Topic(
              name: 'Thể Dục',
              englishName:
                  'Physical Education'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Thể Dục
          Topic(
              name: 'Hoạt Động Trải Nghiệm',
              englishName:
                  'Experiential Activities'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học mới trong chương trình GDPT 2018
        ]),
    Subject(
        name: 'Lớp 2', // Tên môn học (Tiếng Việt)
        englishName:
            'Grade 2', // Tên môn học (Tiếng Anh) - Sửa lại cho đúng cấp độ
        icon: Icons.child_care, // Biểu tượng phù hợp với trẻ em
        topics: [
          Topic(
              name: 'Toán',
              englishName:
                  'Mathematics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tiếng Việt',
              englishName:
                  'Vietnamese'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Sửa lại cho đúng tên môn
          Topic(
              name: 'English',
              englishName:
                  'English'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tự nhiên và Xã hội',
              englishName:
                  'Nature and Society'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Tên chuẩn của môn học lớp 1
          Topic(
              name: 'Đạo Đức',
              englishName:
                  'Ethics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Đạo Đức
          Topic(
              name: 'Âm Nhạc',
              englishName:
                  'Music'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Âm Nhạc
          Topic(
              name: 'Mỹ Thuật',
              englishName:
                  'Art'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Mỹ Thuật
          Topic(
              name: 'Thể Dục',
              englishName:
                  'Physical Education'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Thể Dục
          Topic(
              name: 'Hoạt Động Trải Nghiệm',
              englishName:
                  'Experiential Activities'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học mới trong chương trình GDPT 2018
        ]),
    Subject(
        name: 'Lớp 3', // Tên môn học (Tiếng Việt)
        englishName:
            'Grade 3', // Tên môn học (Tiếng Anh) - Sửa lại cho đúng cấp độ
        icon: Icons.child_care, // Biểu tượng phù hợp với trẻ em
        topics: [
          Topic(
              name: 'Toán',
              englishName:
                  'Mathematics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tiếng Việt',
              englishName:
                  'Vietnamese'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Sửa lại cho đúng tên môn
          Topic(
              name: 'English',
              englishName:
                  'English'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tự nhiên và Xã hội',
              englishName:
                  'Nature and Society'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Tên chuẩn của môn học lớp 1
          Topic(
              name: 'Đạo Đức',
              englishName:
                  'Ethics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Đạo Đức
          Topic(
              name: 'Âm Nhạc',
              englishName:
                  'Music'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Âm Nhạc
          Topic(
              name: 'Mỹ Thuật',
              englishName:
                  'Art'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Mỹ Thuật
          Topic(
              name: 'Thể Dục',
              englishName:
                  'Physical Education'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Thể Dục
          Topic(
              name: 'Hoạt Động Trải Nghiệm',
              englishName:
                  'Experiential Activities'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học mới trong chương trình GDPT 2018
        ]),
    Subject(
        name: 'Lớp 4', // Tên môn học (Tiếng Việt)
        englishName:
            'Grade 4', // Tên môn học (Tiếng Anh) - Sửa lại cho đúng cấp độ
        icon: Icons.child_care, // Biểu tượng phù hợp với trẻ em
        topics: [
          Topic(
              name: 'Toán',
              englishName:
                  'Mathematics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tiếng Việt',
              englishName:
                  'Vietnamese'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Sửa lại cho đúng tên môn
          Topic(
              name: 'English',
              englishName:
                  'English'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tự nhiên và Xã hội',
              englishName:
                  'Nature and Society'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Tên chuẩn của môn học lớp 1
          Topic(
              name: 'Đạo Đức',
              englishName:
                  'Ethics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Đạo Đức
          Topic(
              name: 'Âm Nhạc',
              englishName:
                  'Music'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Âm Nhạc
          Topic(
              name: 'Mỹ Thuật',
              englishName:
                  'Art'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Mỹ Thuật
          Topic(
              name: 'Thể Dục',
              englishName:
                  'Physical Education'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Thể Dục
          Topic(
              name: 'Hoạt Động Trải Nghiệm',
              englishName:
                  'Experiential Activities'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học mới trong chương trình GDPT 2018
        ]),
    Subject(
        name: 'Lớp 5', // Tên môn học (Tiếng Việt)
        englishName:
            'Grade 5', // Tên môn học (Tiếng Anh) - Sửa lại cho đúng cấp độ
        icon: Icons.child_care, // Biểu tượng phù hợp với trẻ em
        topics: [
          Topic(
              name: 'Toán',
              englishName:
                  'Mathematics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tiếng Việt',
              englishName:
                  'Vietnamese'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Sửa lại cho đúng tên môn
          Topic(
              name: 'English',
              englishName:
                  'English'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Ngắn gọn hơn
          Topic(
              name: 'Tự nhiên và Xã hội',
              englishName:
                  'Nature and Society'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Tên chuẩn của môn học lớp 1
          Topic(
              name: 'Đạo Đức',
              englishName:
                  'Ethics'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Đạo Đức
          Topic(
              name: 'Âm Nhạc',
              englishName:
                  'Music'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Âm Nhạc
          Topic(
              name: 'Mỹ Thuật',
              englishName:
                  'Art'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Mỹ Thuật
          Topic(
              name: 'Thể Dục',
              englishName:
                  'Physical Education'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học Thể Dục
          Topic(
              name: 'Hoạt Động Trải Nghiệm',
              englishName:
                  'Experiential Activities'), // Tên chủ đề (Tiếng Việt), Tên chủ đề (Tiếng Anh) - Môn học mới trong chương trình GDPT 2018
        ]),
    Subject(
        name: 'Lớp 6',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics Class '),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature Class '),
          Topic(name: 'Tiếng Anh ', englishName: 'English Class '),
          Topic(
              name: 'Khoa Học Tự Nhiên ',
              englishName: 'Natural Science Class '),
          Topic(
              name: 'Lịch Sử và Địa Lý ',
              englishName: 'History and Geography Class '),
        ]),
    Subject(
        name: 'Lớp 7',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics Class '),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature Class '),
          Topic(name: 'Tiếng Anh ', englishName: 'English Class '),
          Topic(
              name: 'Khoa Học Tự Nhiên ',
              englishName: 'Natural Science Class '),
          Topic(
              name: 'Lịch Sử và Địa Lý ',
              englishName: 'History and Geography Class '),
        ]),
    Subject(
        name: 'Lớp 8',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics '),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature '),
          Topic(name: 'Tiếng Anh ', englishName: 'English '),
          Topic(name: 'Vật Lý ', englishName: 'Physics '),
          Topic(name: 'Hóa Học ', englishName: 'Chemistry '),
          Topic(name: 'Sinh Học ', englishName: 'Biology '),
          Topic(name: 'Lịch Sử ', englishName: 'History '),
          Topic(name: 'Địa Lý ', englishName: 'Geography '),
        ]),
    Subject(
        name: 'Lớp 9',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics '),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature '),
          Topic(name: 'Tiếng Anh ', englishName: 'English '),
          Topic(name: 'Vật Lý ', englishName: 'Physics '),
          Topic(name: 'Hóa Học ', englishName: 'Chemistry '),
          Topic(name: 'Sinh Học ', englishName: 'Biology '),
          Topic(name: 'Lịch Sử ', englishName: 'History '),
          Topic(name: 'Địa Lý ', englishName: 'Geography '),
        ]),
    Subject(
        name: 'Lớp 10',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics'),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature'),
          Topic(name: 'Tiếng Anh ', englishName: 'English'),
          Topic(name: 'Vật Lý ', englishName: 'Physics'),
          Topic(name: 'Hóa Học ', englishName: 'Chemistry'),
          Topic(name: 'Sinh Học ', englishName: 'Biology'),
          Topic(name: 'Lịch Sử ', englishName: 'History'),
          Topic(name: 'Địa Lý ', englishName: 'Geography'),
          Topic(name: 'Giáo Dục Công Dân ', englishName: 'Civic Education'),
        ]),
    Subject(
        name: 'Lớp 11',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán ', englishName: 'Mathematics'),
          Topic(name: 'Ngữ Văn ', englishName: 'Literature'),
          Topic(name: 'Tiếng Anh ', englishName: 'English'),
          Topic(name: 'Vật Lý ', englishName: 'Physics'),
          Topic(name: 'Hóa Học ', englishName: 'Chemistry'),
          Topic(name: 'Sinh Học ', englishName: 'Biology'),
          Topic(name: 'Lịch Sử ', englishName: 'History'),
          Topic(name: 'Địa Lý ', englishName: 'Geography'),
          Topic(name: 'Giáo Dục Công Dân ', englishName: 'Civic Education'),
        ]),
    Subject(
        name: 'Lớp 12',
        englishName: 'High Education',
        icon: Icons
            .school, // Hoặc bạn có thể chọn Icons.face, Icons.escalator_warning
        topics: [
          Topic(name: 'Toán', englishName: 'Mathematics'),
          Topic(name: 'Ngữ Văn', englishName: 'Literature'),
          Topic(name: 'English', englishName: 'English'),
          Topic(name: 'Vật Lý', englishName: 'Physics'),
          Topic(name: 'Hóa Học ', englishName: 'Chemistry'),
          Topic(name: 'Sinh Học ', englishName: 'Biology'),
          Topic(name: 'Lịch Sử ', englishName: 'History'),
          Topic(name: 'Địa Lý ', englishName: 'Geography'),
          Topic(name: 'Giáo Dục Công Dân', englishName: 'Civic Education'),
        ]),
    Subject(
      name: 'Thi cuối kỳ',
      englishName: 'Final Exam',
      icon: Icons.school,
      topics: [
        Topic(name: 'Toán', englishName: 'Mathematics'),
        Topic(name: 'Ngữ Văn', englishName: 'Literature'),
        Topic(name: 'English', englishName: 'English'),
        Topic(name: 'Vật Lý', englishName: 'Physics'),
        Topic(name: 'Hóa Học', englishName: 'Chemistry'),
        Topic(name: 'Sinh Học', englishName: 'Biology'),
        Topic(name: 'Lịch Sử', englishName: 'History'),
        Topic(name: 'Địa Lý', englishName: 'Geography'),
        Topic(name: 'Giáo Dục Công Dân', englishName: 'Civic Education'),
      ],
    ),
    Subject(
      name: 'Nghệ thuật',
      englishName: 'Art',
      icon: Icons.palette,
      topics: [
        Topic(name: 'Âm nhạc', englishName: 'Music'),
        Topic(name: 'Hội họa', englishName: 'Painting'),
        Topic(name: 'Điện ảnh', englishName: 'Cinema'),
        Topic(name: 'Kiến trúc', englishName: 'Architecture'),
      ],
    ),
    Subject(
      name: 'Thể thao',
      englishName: 'Sports',
      icon: Icons.sports_soccer,
      topics: [
        Topic(name: 'Bóng đá', englishName: 'Soccer'),
        Topic(name: 'Bóng rổ', englishName: 'Basketball'),
        Topic(name: 'Quần vợt', englishName: 'Tennis'),
        Topic(name: 'Thế vận hội', englishName: 'Olympic Games'),
      ],
    ),
    Subject(
        name: 'Sức khỏe',
        englishName: 'Health',
        icon: Icons
            .local_hospital, // Chọn icon phù hợp, ví dụ: Icons.local_hospital, Icons.medical_services
        topics: [
          Topic(name: 'Dinh dưỡng', englishName: 'Nutrition'),
          Topic(name: 'Bệnh lý', englishName: 'Diseases'),
          Topic(name: 'Phòng bệnh', englishName: 'Prevention'),
          Topic(name: 'Y học cổ truyền', englishName: 'Traditional Medicine')
        ]),
    Subject(
        name: 'Du lịch',
        englishName: 'Travel',
        icon: Icons
            .explore, // Chọn icon phù hợp, ví dụ: Icons.explore, Icons.airplane_ticket
        topics: [
          Topic(name: 'Địa điểm', englishName: 'Destinations'),
          Topic(name: 'Khám phá', englishName: 'Discovery'),
          Topic(name: 'Kinh nghiệm du lịch', englishName: 'Travel Tips'),
          Topic(name: 'Ẩm thực địa phương', englishName: 'Local Cuisine')
        ]),
    Subject(
        name: 'Pháp luật',
        englishName: 'Law',
        icon: Icons.gavel, // Chọn icon phù hợp, ví dụ: Icons.gavel
        topics: [
          Topic(name: 'Tin tức pháp luật', englishName: 'Legal News'),
          Topic(name: 'Văn bản pháp luật', englishName: 'Legal Documents'),
          Topic(name: 'Tư vấn pháp luật', englishName: 'Legal Advice'),
          Topic(name: 'An ninh trật tự', englishName: 'Security and Order')
        ]),
    Subject(
        name: 'Kinh tế',
        englishName: 'Economy',
        icon:
            Icons.attach_money, // Chọn icon phù hợp, ví dụ: Icons.attach_money
        topics: [
          Topic(name: 'Thị trường', englishName: 'Market'),
          Topic(name: 'Tài chính', englishName: 'Finance'),
          Topic(name: 'Doanh nghiệp', englishName: 'Business'),
          Topic(name: 'Khởi nghiệp', englishName: 'Startups')
        ]),
    Subject(
      name: 'Văn hóa - Xã hội',
      englishName: 'Culture - Society',
      icon: Icons.people,
      topics: [
        Topic(
            name: 'Phong tục tập quán', englishName: 'Customs and Traditions'),
        Topic(name: 'Lễ hội', englishName: 'Festivals'),
        Topic(name: 'Ẩm thực', englishName: 'Cuisine'),
        Topic(name: 'Tin tức thời sự', englishName: 'Current Events'),
      ],
    ),
    Subject(
      name: 'Toán học',
      englishName: 'Mathematics',
      icon: Icons.calculate,
      topics: [
        Topic(name: 'Số học', englishName: 'Arithmetic'),
        Topic(name: 'Đại số', englishName: 'Algebra'),
        Topic(name: 'Hình học', englishName: 'Geometry'),
        Topic(
            name: 'Xác suất thống kê',
            englishName: 'Probability and Statistics'),
      ],
    ),
    Subject(
        name: 'Tin học',
        englishName: 'Computer Science',
        icon: Icons.computer,
        topics: [
          Topic(name: 'Lập trình', englishName: 'Programming'),
          Topic(name: 'Mạng máy tính', englishName: 'Computer Networking'),
          Topic(name: 'Hệ điều hành', englishName: 'Operating Systems'),
          Topic(name: 'Kỹ thuật phần mềm', englishName: 'Software Engineering'),
        ]),
    Subject(
      name: 'Giải trí',
      englishName: 'Entertainment',
      icon: Icons.movie,
      topics: [
        Topic(name: 'Phim ảnh', englishName: 'Movies'),
        Topic(name: 'Âm nhạc', englishName: 'Music'),
        Topic(name: 'Người nổi tiếng', englishName: 'Celebrities'),
      ],
    ),
  ];
}
