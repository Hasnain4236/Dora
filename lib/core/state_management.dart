// State management for Dora AI Assistant integrating local LLM via llama.cpp
library state_management;

import 'dart:async';
import 'package:flutter/material.dart';
import 'agent_orchestrator.dart';
import 'local_llm_manager.dart';

/// Application modes
enum AppMode { conversation, vision }

/// LLM configuration model
class LLMConfig {
  final String modelPath;
  final int port;
  final String modelType; // deepseek, llama, etc.
  final Map<String, dynamic> extra;

  const LLMConfig({
    this.modelPath = '',
    this.port = 8080,
    this.modelType = 'deepseek',
    this.extra = const {},
  });

  LLMConfig copyWith({
    String? modelPath,
    int? port,
    String? modelType,
    Map<String, dynamic>? extra,
  }) => LLMConfig(
    modelPath: modelPath ?? this.modelPath,
    port: port ?? this.port,
    modelType: modelType ?? this.modelType,
    extra: extra ?? this.extra,
  );
}

/// Conversation message view model (proxying orchestrator messages)
class ConversationEntry {
  final String role;
  final String content;
  final DateTime timestamp;
  const ConversationEntry(this.role, this.content, this.timestamp);
}

/// Core app state manager
class DoraStateManager extends ChangeNotifier {
  static DoraStateManager? _instance;
  static DoraStateManager get instance => _instance ??= DoraStateManager._();
  DoraStateManager._();

  // Orchestrator
  final AgentOrchestrator _orchestrator = AgentOrchestrator.instance;

  // Voice state
  bool isListening = false;
  bool isProcessing = false;
  bool isSpeaking = false;
  List<double> audioLevels = [];

  // UI / mode
  bool darkMode = true;
  AppMode currentMode = AppMode.conversation;

  // LLM
  LLMConfig _llmConfig = const LLMConfig();
  LLMConfig get llmConfig => _llmConfig;

  // Wake word (stub implementation)
  String wakeWord = 'dora';
  bool wakeWordEnabled = false;
  bool wakeWordListening = false;
  StreamSubscription<String>? _wakeWordSub;

  // Conversation
  String lastInput = '';
  String lastResponse = '';
  String lastError = '';

  // Initialization
  bool _initialized = false;
  bool get initialized => _initialized;

  /// Initialize state & orchestrator
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      if (_llmConfig.modelPath.isNotEmpty) {
        await _orchestrator.initialize(deepSeekModelPath: _llmConfig.modelPath, llmConfig: _llmConfig.extra);
      } else {
        // Initialize without model - user can set later
        await _orchestrator.initialize(deepSeekModelPath: '');
      }
      _initialized = true;
    } catch (e) {
      lastError = 'Initialization failed: $e';
    } finally {
      notifyListeners();
    }
  }

  /// Process user voice/text input through orchestrator
  Future<void> processVoiceInput(String input) async {
    if (input.trim().isEmpty) return;
    lastInput = input;
    isProcessing = true;
    notifyListeners();

    try {
      final result = await _orchestrator.processUserInput(input);
      if (result.success) {
        lastResponse = result.message;
        lastError = '';
      } else {
        lastResponse = result.message;
        lastError = result.error ?? result.message;
      }
    } catch (e) {
      lastResponse = 'Error: $e';
      lastError = e.toString();
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  /// Update voice state (listening/processing/speaking)
  void updateVoiceState({bool? listening, bool? processing, bool? speaking}) {
    if (listening != null) isListening = listening;
    if (processing != null) isProcessing = processing;
    if (speaking != null) isSpeaking = speaking;
    notifyListeners();
  }

  /// Configure LLM (restarts server if already running)
  Future<void> configureLLM(LLMConfig config) async {
    _llmConfig = config;
    notifyListeners();

    if (!_initialized) return;

    try {
      if (config.modelPath.isNotEmpty) {
        await LocalLLMManager.instance.initializeDeepSeek(
          modelPath: config.modelPath,
          port: config.port,
          config: config.extra,
        );
      }
    } catch (e) {
      lastError = 'LLM config failed: $e';
      notifyListeners();
    }
  }

  /// Configure wake word (stub)
  void configureWakeWord({String? wakeWord, bool? enabled}) {
    if (wakeWord != null && wakeWord.isNotEmpty) this.wakeWord = wakeWord;
    if (enabled != null) wakeWordEnabled = enabled;
    wakeWordListening = wakeWordEnabled; // simulate
    notifyListeners();
  }

  /// Toggle theme
  void toggleDarkMode() {
    darkMode = !darkMode;
    notifyListeners();
  }

  /// Set app mode
  void setAppMode(AppMode mode) {
    if (currentMode == mode) return;
    currentMode = mode;
    notifyListeners();
  }

  /// Clear conversation history
  void clearConversationHistory() {
    _orchestrator.clearHistory();
    lastResponse = '';
    lastInput = '';
    notifyListeners();
  }

  /// Activity status string
  String get activityStatus {
    if (isProcessing) return 'Processing';
    if (isSpeaking) return 'Speaking';
    if (isListening) return 'Listening';
    if (wakeWordListening) return 'Wake word active';
    return 'Idle';
  }

  /// UI status color
  Color get statusColor {
    if (isProcessing) return Colors.orange;
    if (isSpeaking) return Colors.purpleAccent;
    if (isListening) return Colors.green;
    if (wakeWordListening) return Colors.blueAccent;
    return Colors.grey;
  }

  /// Conversation history for UI
  List<ConversationEntry> get conversationHistory => _orchestrator.conversationHistory
      .map((m) => ConversationEntry(m.role, m.content, m.timestamp))
      .toList();

  @override
  void dispose() {
    _wakeWordSub?.cancel();
    _orchestrator.dispose();
    super.dispose();
  }
}
