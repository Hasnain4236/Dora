/// Command processor for built-in quick responses
library command_processor;

/// Process built-in commands for fast responses without LLM overhead
String? processBuiltinCommand(String input) {
  final lowercaseInput = input.toLowerCase().trim();

  // Time and date
  if (lowercaseInput.contains('time') || lowercaseInput.contains('what time')) {
    final now = DateTime.now();
    return 'The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  if (lowercaseInput.contains('date') || lowercaseInput.contains('what date')) {
    final now = DateTime.now();
    return 'Today is ${_formatDate(now)}';
  }

  // Greetings
  if (lowercaseInput.contains('hello') || lowercaseInput.contains('hi ')) {
    return 'Hello! How can I help you today?';
  }

  if (lowercaseInput.contains('good morning')) {
    return 'Good morning! Ready to assist you.';
  }

  if (lowercaseInput.contains('good evening') || lowercaseInput.contains('good night')) {
    return 'Good evening! What can I do for you?';
  }

  // System status
  if (lowercaseInput.contains('how are you') || lowercaseInput.contains('status')) {
    return 'I\'m running well and ready to help!';
  }

  // Quick actions
  if (lowercaseInput.contains('thank you') || lowercaseInput.contains('thanks')) {
    return 'You\'re welcome! Happy to help.';
  }

  return null; // No builtin command matched
}

String _formatDate(DateTime date) {
  final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  final months = ['January', 'February', 'March', 'April', 'May', 'June',
                  'July', 'August', 'September', 'October', 'November', 'December'];

  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
}
