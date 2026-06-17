// Update ChatMessage class to include imagePath
class ChatMessage {
  final String text;
  final bool isSentByMe;
  final String senderName;
  final DateTime timestamp;
  final String? imagePath;

  ChatMessage({
    required this.text,
    required this.isSentByMe,
    required this.senderName,
    required this.timestamp,
    this.imagePath,
  });
}