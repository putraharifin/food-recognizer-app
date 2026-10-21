String formatPercent(double confidence) {
  final value = (confidence.clamp(0.0, 1.0)) * 100;
  return '${value.toStringAsFixed(2)}%';
}

String formatGram(double value) {
  final isWhole = value == value.truncateToDouble();
  return '${value.toStringAsFixed(isWhole ? 0 : 1)} g';
}

String toTitleCase(String text) {
  return text
      .trim()
      .split(RegExp(r'\s+'))
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
