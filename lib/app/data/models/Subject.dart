import 'package:flutter/material.dart';

class Subject {
  final String name;
  final String englishName;

  final IconData icon;
  final List<Topic> topics;

  Subject({
    required this.name,
    required this.englishName,
    required this.icon,
    required this.topics,
  });
}

class Topic {
  final String name;
  final String englishName;

  Topic({required this.name, required this.englishName});
}
