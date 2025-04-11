class AnalysisSummary {
  final String analysisSummary;
  final String newPrompt;

  AnalysisSummary({
    required this.analysisSummary,
    required this.newPrompt,
  });

  factory AnalysisSummary.fromJson(Map<String, dynamic> json) {
    return AnalysisSummary(
      analysisSummary: json['analysis_summary'],
      newPrompt: json['new_prompt'],
    );
  }

  Map<String, dynamic> toJson() => {
        'analysis_summary': analysisSummary,
        'new_prompt': newPrompt,
      };

  @override
  String toString() {
    return 'AnalysisSummary(analysisSummary: $analysisSummary, newPrompt: $newPrompt)';
  }
}
