class BleScanSnapshot {
  const BleScanSnapshot({
    required this.status,
    required this.savedCount,
    required this.filePath,
    required this.message,
  });

  final String status;
  final int savedCount;
  final String filePath;
  final String message;
}
