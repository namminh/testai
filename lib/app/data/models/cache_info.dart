class CacheInfo {
  final List<Map<String, dynamic>> data;
  final DateTime timestamp;

  CacheInfo({required this.data}) : timestamp = DateTime.now();

  bool isExpired() {
    return DateTime.now().difference(timestamp) > const Duration(days: 1);
  }
}
