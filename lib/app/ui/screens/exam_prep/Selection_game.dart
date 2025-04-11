import 'package:flutter/material.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/exam_prep_view_model.dart';
import '../home/home_widget/app_bar.dart';
import '../../../data/models/Subject.dart';
import '../../../core/constants/subject_constant.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

enum Difficulty { Easy, Medium, Hard }

enum Language { Vietnamese, English }

class SubjectSelectionScreen extends StatefulWidget {
  @override
  _SubjectSelectionScreenState createState() => _SubjectSelectionScreenState();
}

class _SubjectSelectionScreenState extends State<SubjectSelectionScreen>
    with SingleTickerProviderStateMixin {
  ExamPrepViewModel model = ExamPrepViewModel();
  Set<String> selectedSubjects = {};
  Set<String> selectedTopics = {};
  Language selectedLanguage = Language.Vietnamese;
  Difficulty selectedDifficulty = Difficulty.Hard;
  late List<Subject> filteredSubjects = [];
  late AnimationController _animationController;
  late ConfettiController _confettiController;
  int adventurePoints = 0; // Điểm phiêu lưu
  int xp = 0; // Thay adventurePoints bằng XP
  int level = 1; // Cấp độ người chơi
  Map<String, bool> badges = {'Explorer': false, 'Master': false}; // Huy hiệu
  List<String> under10Subjects = [
    'Lớp 1',
    'Lớp 2',
    'Lớp 3',
    'Lớp 4',
    'Lớp 5'
  ];
  List<String> highsubjects = [
    'Lớp 6',
    'Lớp 7',
    'Lớp 8',
    'Lớp 9',
    'Lớp 10',
    'Lớp 11',
    'Lớp 12'
  ];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _loadProgress();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      xp = prefs.getInt('userXp') ?? 0;
    });
  }

  void _updateLevelAndBadges() {
    int newLevel = (xp ~/ 50) + 1;
    List<String> unlockedBadges = [];

    setState(() {
      if (newLevel > level) {
        level = newLevel;
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đạt cấp $level!')),
        );
      }

      if (xp >= 100 && !badges['Explorer']!) {
        badges['Explorer'] = true;
        unlockedBadges.add('Explorer');
      }
      if (selectedSubjects.length >= 5 && !badges['Master']!) {
        badges['Master'] = true;
        unlockedBadges.add('Master');
      }

      if (unlockedBadges.isNotEmpty) {
        _confettiController.play();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Mở khóa huy hiệu: ${unlockedBadges.join(', ')}!')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BaseView<ExamPrepViewModel>(
      onModelReady: (model) {
        this.model = model;
        String? age = model?.age;
        filteredSubjects = filterSubjects(age, SubjectConstant.subjects);
      },
      builder: (context, _, __) => Scaffold(
        appBar: HomeAppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Level $level - $xp XP',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/adventure_map.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: (xp % 50) / 50, // Thanh tiến trình
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation(Colors.amber),
                  ),
                  _SelectedTopics(selectedTopics: selectedTopics),
                  Expanded(
                    child: filteredSubjects.isEmpty
                        ? const Center(
                            child: Text('Chưa có vùng đất nào!',
                                style: TextStyle(color: Colors.white)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: filteredSubjects.length,
                            itemBuilder: (_, index) => _SubjectCard(
                              subject: filteredSubjects[index],
                              isSelected: selectedSubjects
                                  .contains(filteredSubjects[index].name),
                              onTap: () =>
                                  _toggleSubject(filteredSubjects[index]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Lottie.asset('assets/lottie/aiNemo.json',
                  width: 80, height: 80, fit: BoxFit.cover),
            ),
            Positioned(
              top: 0,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                colors: const [Colors.green, Colors.yellow, Colors.blue],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Subject> filterSubjects(String? age, List<Subject> allSubjects) {
    if (age == '10') {
      return allSubjects
          .where((subject) => under10Subjects.contains(subject.name))
          .toList();
    } else if (age == '17') {
      return allSubjects
          .where((subject) => highsubjects.contains(subject.name))
          .toList();
    } else {
      return allSubjects
          .where((subject) =>
              !highsubjects.contains(subject.name) &&
              !under10Subjects.contains(subject.name))
          .toList();
    }
  }

  void _toggleSubject(Subject subject) {
    setState(() {
      if (selectedSubjects.contains(subject.name)) {
        selectedSubjects.remove(subject.name);
        selectedTopics
            .removeWhere((topic) => subject.topics.any((t) => t.name == topic));
        xp -= 5; // Rủi ro
      } else {
        selectedSubjects.add(subject.name);
        selectedTopics.add(subject.topics.first.name);
        xp += _random.nextInt(10) + 10; // 10-20 XP ngẫu nhiên
        _confettiController.play();
        if (selectedDifficulty == Difficulty.Hard &&
            _random.nextDouble() < 0.3) {
          _openTreasureChest(); // 30% cơ hội nhận rương
        }
      }
      _updateLevelAndBadges();
    });
    _showTopicSelection(subject);
  }

  void _openTreasureChest() {
    final bonus = _random.nextInt(30) + 10; // 10-40 XP
    setState(() {
      xp += bonus;
      _confettiController.play();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nhận rương kho báu: +$bonus XP!')),
      );
      _updateLevelAndBadges();
    });
  }

  void _showTopicSelection(Subject subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScaleTransition(
        scale:
            Tween<double>(begin: 0.9, end: 1.0).animate(_animationController),
        child: _TopicSelectionBottomSheet(
          subject: subject,
          selectedTopics: selectedTopics,
          selectedDifficulty: selectedDifficulty,
          selectedLanguage: selectedLanguage,
          onConfirm: (topics, difficulty, language) {
            setState(() {
              selectedTopics.clear();
              selectedTopics.addAll(topics);
              selectedDifficulty = difficulty;
              selectedLanguage = language;
              model.subjectController.text = selectedSubjects.join(', ');
              model.topicController.text = selectedTopics.join(', ');
              model.level.text = difficulty.toString().split('.').last;
              model.ngonNgu.text =
                  language == Language.Vietnamese ? "Vietnamese" : "English";
              model.soCau.text = "15";
              xp += 20;
              _confettiController.play();
              _updateLevelAndBadges(); // Kiểm tra huy hiệu QuickLearner
            });
          },
        ),
      ),
    );
    _animationController.forward(from: 0);
  }
}

class _SelectedTopics extends StatelessWidget {
  final Set<String> selectedTopics;

  const _SelectedTopics({required this.selectedTopics});

  @override
  Widget build(BuildContext context) {
    if (selectedTopics.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.black87, Colors.grey[900]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.map, color: Colors.amber, size: 28),
            const SizedBox(width: 8),
            Wrap(
              spacing: 8,
              children: selectedTopics
                  .map((topic) => AnimatedScale(
                        scale: 1.0, // Có thể thêm animation khi nhấn
                        duration: const Duration(milliseconds: 200),
                        child: Chip(
                          avatar: const Icon(Icons.explore,
                              color: Colors.white, size: 18),
                          label: Text(
                            topic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily:
                                  'FantasyFont', // Thay bằng font game nếu có
                            ),
                          ),
                          backgroundColor: Colors.blue[700],
                          elevation: 4,
                          shadowColor: Colors.blueAccent.withOpacity(0.5),
                          deleteIcon: const Icon(Icons.close,
                              size: 18, color: Colors.white),
                          onDeleted: () => context
                              .findAncestorStateOfType<
                                  _SubjectSelectionScreenState>()
                              ?.setState(() => selectedTopics.remove(topic)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final bool isSelected;
  final VoidCallback onTap;

  const _SubjectCard({
    required this.subject,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: isSelected
                  ? [Colors.amber[900]!, Colors.amber[600]!]
                  : [Colors.blue[900]!, Colors.blue[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? Colors.amber.withOpacity(0.6)
                    : Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Viền Rune
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.amber
                        : Colors.grey.withOpacity(0.5),
                    width: 3,
                  ),
                  image: const DecorationImage(
                    image: AssetImage('assets/images/rune_border.png'),
                    fit: BoxFit.cover,
                    opacity: 0.4,
                  ),
                ),
              ),
              // Nội dung
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.1 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(subject.icon, size: 48, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subject.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 6),
                          Shadow(
                              color: isSelected ? Colors.amber : Colors.blue,
                              blurRadius: 4),
                        ],
                        fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.yellow[800]!, Colors.yellow[600]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withOpacity(0.5),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Text(
                        '+15 XP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Dấu chọn
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.amber, Colors.transparent],
                      ),
                    ),
                    child:
                        const Icon(Icons.star, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopicSelectionBottomSheet extends StatefulWidget {
  final Subject subject;
  final Set<String> selectedTopics;
  final Difficulty selectedDifficulty;
  final Language selectedLanguage;
  final void Function(Set<String>, Difficulty, Language) onConfirm;

  const _TopicSelectionBottomSheet({
    required this.subject,
    required this.selectedTopics,
    required this.selectedDifficulty,
    required this.selectedLanguage,
    required this.onConfirm,
  });

  @override
  _TopicSelectionBottomSheetState createState() =>
      _TopicSelectionBottomSheetState();
}

class _TopicSelectionBottomSheetState
    extends State<_TopicSelectionBottomSheet> {
  late Set<String> tempTopics;
  late Difficulty tempDifficulty;
  late Language tempLanguage;

  @override
  void initState() {
    super.initState();
    tempTopics = Set.from(widget.selectedTopics);
    tempDifficulty = widget.selectedDifficulty;
    tempLanguage = widget.selectedLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final filteredTopics = widget.subject.topics;
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.purple[900]!, Colors.blue[800]!],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber, Colors.yellowAccent],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              indicatorColor: Colors.amber,
              labelColor: Colors.amber,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'FantasyFont', // Thay bằng font game nếu có
              ),
              tabs: const [
                Tab(text: 'Nhiệm vụ', icon: Icon(Icons.explore)),
                Tab(text: 'Thử thách', icon: Icon(Icons.bar_chart)),
                Tab(text: 'Ngôn ngữ', icon: Icon(Icons.language)),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTopics.length,
                    itemBuilder: (_, index) {
                      final topic = filteredTopics[index];
                      final isSelected = tempTopics.contains(topic.name);
                      return _TopicItem(
                        title: tempLanguage == Language.Vietnamese
                            ? topic.name
                            : topic.englishName,
                        subtitle: '+10 XP',
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              tempTopics.remove(topic.name);
                            } else if (tempTopics.length < 2) {
                              tempTopics.add(topic.name);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Tối đa 2 nhiệm vụ!'),
                                  backgroundColor: Colors.redAccent,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          });
                        },
                      );
                    },
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: Difficulty.values.length,
                    itemBuilder: (_, index) {
                      final difficulty = Difficulty.values[index];
                      return _TopicItem(
                        title: difficulty.toString().split('.').last,
                        subtitle: '',
                        isSelected: tempDifficulty == difficulty,
                        icon: _getDifficultyIcon(difficulty),
                        onTap: () =>
                            setState(() => tempDifficulty = difficulty),
                      );
                    },
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _TopicItem(
                        title: 'Tiếng Việt',
                        subtitle: 'Vietnamese',
                        isSelected: tempLanguage == Language.Vietnamese,
                        icon:
                            const Text('🇻🇳', style: TextStyle(fontSize: 24)),
                        onTap: () =>
                            setState(() => tempLanguage = Language.Vietnamese),
                      ),
                      _TopicItem(
                        title: 'English',
                        subtitle: 'Tiếng Anh',
                        isSelected: tempLanguage == Language.English,
                        icon:
                            const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                        onTap: () =>
                            setState(() => tempLanguage = Language.English),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  widget.onConfirm(tempTopics, tempDifficulty, tempLanguage);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[600],
                  foregroundColor: Colors.blue[900],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                  shadowColor: Colors.amber.withOpacity(0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.explore, color: Colors.white, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Chinh phục!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _getDifficultyIcon(Difficulty difficulty) {
    return switch (difficulty) {
      Difficulty.Easy =>
        const Icon(Icons.star_border, color: Colors.greenAccent, size: 24),
      Difficulty.Medium =>
        const Icon(Icons.star_half, color: Colors.yellowAccent, size: 24),
      Difficulty.Hard =>
        const Icon(Icons.star, color: Colors.redAccent, size: 24),
    };
  }
}

// Class Item trong BottomSheet
class _TopicItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final Widget? icon;
  final VoidCallback onTap;

  const _TopicItem({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [Colors.amber[700]!, Colors.amber[400]!]
              : [
                  Colors.blue[900]!.withOpacity(0.5),
                  Colors.blue[800]!.withOpacity(0.5)
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isSelected ? Colors.amber : Colors.blue[700]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Colors.amber.withOpacity(0.5)
                : Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (icon != null) ...[
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: icon,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      shadows: [
                        Shadow(
                            color: isSelected ? Colors.amber : Colors.blue,
                            blurRadius: 4),
                      ],
                      fontFamily: 'FantasyFont', // Thay bằng font game nếu có
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.check_circle,
                    color: Colors.amber, size: 28),
              ),
          ],
        ),
      ),
    );
  }
}
