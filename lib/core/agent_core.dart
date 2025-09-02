/// Agent Core - Fixed implementation with proper error handling
library agent_core;

import 'dart:async';

/// Core result class for agent operations
class ActionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final String? error;

  ActionResult._({
    required this.success,
    required this.message,
    this.data,
    this.error,
  });

  factory ActionResult.success(String message, [Map<String, dynamic>? data]) {
    return ActionResult._(
      success: true,
      message: message,
      data: data,
    );
  }

  factory ActionResult.error(String error) {
    return ActionResult._(
      success: false,
      message: error,
      error: error,
    );
  }

  @override
  String toString() => success ? 'Success: $message' : 'Error: $error';
}

/// Agent capabilities enum
enum AgentCapability {
  systemControl,
  communication,
  information,
  media,
  automation,
  learning,
  vision,
  screenInteraction,
}

/// Agent intent representation
class AgentIntent {
  final String name;
  final String text;
  final double confidence;
  final Map<String, dynamic> parameters;

  AgentIntent({
    required this.name,
    required this.text,
    required this.confidence,
    required this.parameters,
  });

  @override
  String toString() => 'Intent($name, confidence: $confidence)';
}

/// Base class for agent actions
abstract class AgentAction {
  String get name;
  Set<AgentCapability> get requiredCapabilities;

  bool canExecute(String userInput);
  Future<ActionResult> execute(Map<String, dynamic> parameters);
}

/// Agent configuration
class AgentConfig {
  final bool enableDebugLogs;
  final int maxRetries;
  final Duration timeout;
  final Map<String, dynamic> customSettings;

  const AgentConfig({
    this.enableDebugLogs = false,
    this.maxRetries = 3,
    this.timeout = const Duration(seconds: 30),
    this.customSettings = const {},
  });
}
