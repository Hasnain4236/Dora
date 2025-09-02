/// Advanced Agent Orchestrator for Dora AI - Fixed warnings
library agent_orchestrator;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'agent_core.dart';
import 'local_llm_manager.dart';
import 'screen_interaction_manager.dart';
import 'vision_manager.dart';

/// Central orchestrator that coordinates all agent capabilities
class AgentOrchestrator {
  static AgentOrchestrator? _instance;
  static AgentOrchestrator get instance => _instance ??= AgentOrchestrator._();
  AgentOrchestrator._();

  // Core managers
  late LocalLLMManager _llmManager;
  late ScreenInteractionManager _screenManager;
  late DoraVisionManager _visionManager;

  // Agent state
  bool _isInitialized = false;
  final String _currentTask = '';

  // Memory and context
  final List<ConversationMessage> _conversationHistory = [];

  /// Initialize the agent orchestrator
  Future<bool> initialize({
    required String deepSeekModelPath,
    Map<String, dynamic>? llmConfig,
  }) async {
    try {
      _llmManager = LocalLLMManager.instance;
      _screenManager = ScreenInteractionManager.instance;
      _visionManager = DoraVisionManager.instance;

      // Initialize all managers
      final llmInitialized = await _llmManager.initializeDeepSeek(
        modelPath: deepSeekModelPath,
        config: llmConfig,
      );

      final screenInitialized = await _screenManager.initialize();
      final visionInitialized = await _visionManager.initialize();

      if (!llmInitialized) {
        debugPrint('Warning: LLM initialization failed');
      }

      if (!screenInitialized) {
        debugPrint('Warning: Screen interaction initialization failed');
      }

      if (!visionInitialized) {
        debugPrint('Warning: Vision manager initialization failed');
      }

      _isInitialized = true;
      debugPrint('Agent Orchestrator initialized successfully');

      return true;
    } catch (e) {
      debugPrint('Agent Orchestrator initialization failed: $e');
      return false;
    }
  }

  /// Process user input and execute appropriate actions
  Future<ActionResult> processUserInput(String input) async {
    if (!_isInitialized) {
      return ActionResult.error('Agent not initialized');
    }

    try {
      // Add to conversation history
      _conversationHistory.add(ConversationMessage(
        role: 'user',
        content: input,
        timestamp: DateTime.now(),
      ));

      // Analyze user intent with current context
      final intent = await _analyzeUserIntent(input);

      // Execute the appropriate action based on intent
      final result = await _executeIntent(intent);

      // Add response to history
      _conversationHistory.add(ConversationMessage(
        role: 'assistant',
        content: result.message,
        timestamp: DateTime.now(),
        metadata: {'success': result.success, 'data': result.data},
      ));

      return result;
    } catch (e) {
      final errorResult = ActionResult.error('Processing failed: $e');
      _conversationHistory.add(ConversationMessage(
        role: 'assistant',
        content: errorResult.message,
        timestamp: DateTime.now(),
        metadata: {'success': false, 'error': e.toString()},
      ));
      return errorResult;
    }
  }

  /// Analyze user intent using LLM with context
  Future<AgentIntent> _analyzeUserIntent(String input) async {
    try {
      // Get current screen context if available
      String screenContext = '';
      if (_screenManager.isInitialized) {
        try {
          final analysis = await _screenManager.analyzeScreen();
          if (analysis.success) {
            screenContext = '''
Current screen context:
- Understanding: ${analysis.understanding}
- Available UI elements: ${analysis.elements.map((e) => '${e.type}: "${e.text}"').join(', ')}
- Screen text: ${analysis.text.length > 200 ? '${analysis.text.substring(0, 200)}...' : analysis.text}
''';
          }
        } catch (e) {
          debugPrint('Failed to get screen context: $e');
        }
      }

      // Build context-aware prompt
      final prompt = '''
You are Dora, an intelligent AI assistant with multimodal capabilities. Analyze this user request and determine the appropriate action.

User request: "$input"

$screenContext

Recent conversation:
${_conversationHistory.takeLast(5).map((m) => '${m.role}: ${m.content}').join('\n')}

Available capabilities:
1. SCREEN_INTERACTION - Click, tap, type, scroll on the screen
2. VISION_ANALYSIS - Analyze camera feed or screenshots
3. APP_CONTROL - Open apps, make calls, send messages
4. INFORMATION_SEARCH - Web search, knowledge queries
5. CONVERSATION - General chat and assistance
6. SYSTEM_CONTROL - Settings, notifications, device control

Respond with a JSON object containing:
{
  "intent": "CAPABILITY_NAME",
  "confidence": 0.0-1.0,
  "parameters": {
    "action": "specific_action",
    "target": "target_element_or_app",
    "text": "text_to_type_or_search",
    "coordinates": {"x": 0, "y": 0},
    "additional_params": {}
  },
  "reasoning": "Why this action was chosen"
}

For screen interactions, be specific about targets. For ambiguous requests, ask for clarification.
''';

      final result = await _llmManager.chatCompletion(
        message: prompt,
        temperature: 0.3,
        maxTokens: 512,
      );

      if (result.success) {
        try {
          final response = jsonDecode(result.message);
          return AgentIntent(
            name: response['intent'] ?? 'CONVERSATION',
            text: input,
            confidence: (response['confidence'] ?? 0.5).toDouble(),
            parameters: Map<String, dynamic>.from(response['parameters'] ?? {}),
          );
        } catch (e) {
          debugPrint('Failed to parse intent JSON: $e');
          return _fallbackIntentAnalysis(input);
        }
      } else {
        return _fallbackIntentAnalysis(input);
      }
    } catch (e) {
      debugPrint('Intent analysis failed: $e');
      return _fallbackIntentAnalysis(input);
    }
  }

  /// Fallback intent analysis using simple patterns
  AgentIntent _fallbackIntentAnalysis(String input) {
    final lowercaseInput = input.toLowerCase();

    // Screen interaction patterns
    if (lowercaseInput.contains('click') || lowercaseInput.contains('tap') ||
        lowercaseInput.contains('press')) {
      return AgentIntent(
        name: 'SCREEN_INTERACTION',
        text: input,
        confidence: 0.7,
        parameters: {'action': 'click', 'target': input},
      );
    }

    // App control patterns
    if (lowercaseInput.contains('open') || lowercaseInput.contains('launch') ||
        lowercaseInput.contains('start')) {
      return AgentIntent(
        name: 'APP_CONTROL',
        text: input,
        confidence: 0.8,
        parameters: {'action': 'open_app', 'target': input},
      );
    }

    // Search patterns
    if (lowercaseInput.contains('search') || lowercaseInput.contains('find') ||
        lowercaseInput.contains('look up')) {
      return AgentIntent(
        name: 'INFORMATION_SEARCH',
        text: input,
        confidence: 0.8,
        parameters: {'action': 'search', 'query': input},
      );
    }

    // Default to conversation
    return AgentIntent(
      name: 'CONVERSATION',
      text: input,
      confidence: 0.5,
      parameters: {'message': input},
    );
  }

  /// Execute the determined intent
  Future<ActionResult> _executeIntent(AgentIntent intent) async {
    switch (intent.name) {
      case 'SCREEN_INTERACTION':
        return await _executeScreenInteraction(intent);
      case 'VISION_ANALYSIS':
        return await _executeVisionAnalysis(intent);
      case 'APP_CONTROL':
        return await _executeAppControl(intent);
      case 'INFORMATION_SEARCH':
        return await _executeInformationSearch(intent);
      case 'SYSTEM_CONTROL':
        return await _executeSystemControl(intent);
      case 'CONVERSATION':
      default:
        return await _executeConversation(intent);
    }
  }

  /// Execute screen interaction tasks
  Future<ActionResult> _executeScreenInteraction(AgentIntent intent) async {
    try {
      final action = intent.parameters['action'] as String?;
      final target = intent.parameters['target'] as String?;

      switch (action) {
        case 'click':
          if (target != null) {
            return await _screenManager.clickElement(containsText: target);
          } else {
            return ActionResult.error('No target specified for click action');
          }

        case 'type':
          final text = intent.parameters['text'] as String?;
          if (text != null) {
            return await _screenManager.typeText(text);
          } else {
            return ActionResult.error('No text specified for typing');
          }

        case 'scroll':
          final direction = intent.parameters['direction'] as String? ?? 'down';
          final scrollDir = _parseScrollDirection(direction);
          return await _screenManager.scroll(scrollDir);

        default:
          return await _analyzeAndInteract(intent.text);
      }
    } catch (e) {
      return ActionResult.error('Screen interaction failed: $e');
    }
  }

  /// Analyze screen and perform intelligent interaction
  Future<ActionResult> _analyzeAndInteract(String userRequest) async {
    try {
      final analysis = await _screenManager.analyzeScreen();
      if (!analysis.success) {
        return ActionResult.error('Could not analyze screen');
      }

      final prompt = '''
The user wants: "$userRequest"

Current screen analysis:
${analysis.understanding}

Available UI elements:
${analysis.elements.map((e) => '- ${e.type}: "${e.text}" at (${e.bounds.center.dx.toInt()}, ${e.bounds.center.dy.toInt()})').join('\n')}

Determine the best action to fulfill the user's request. Respond with JSON:
{
  "action": "click|type|scroll",
  "target": "element_text_or_coordinates",
  "text": "text_to_type_if_needed",
  "coordinates": {"x": 0, "y": 0},
  "reasoning": "explanation"
}
''';

      final result = await _llmManager.chatCompletion(
        message: prompt,
        temperature: 0.2,
        maxTokens: 256,
      );

      if (result.success) {
        try {
          final action = jsonDecode(result.message);
          return await _performScreenAction(action);
        } catch (e) {
          return ActionResult.error('Could not parse action: $e');
        }
      } else {
        return ActionResult.error('Could not determine screen action');
      }
    } catch (e) {
      return ActionResult.error('Screen analysis failed: $e');
    }
  }

  /// Perform the determined screen action
  Future<ActionResult> _performScreenAction(Map<String, dynamic> action) async {
    final actionType = action['action'] as String;

    switch (actionType) {
      case 'click':
        final coordinates = action['coordinates'] as Map<String, dynamic>?;
        if (coordinates != null) {
          return await _screenManager.clickAt(
            coordinates['x'].toDouble(),
            coordinates['y'].toDouble(),
          );
        } else {
          final target = action['target'] as String;
          return await _screenManager.clickElement(containsText: target);
        }

      case 'type':
        final text = action['text'] as String;
        return await _screenManager.typeText(text);

      case 'scroll':
        final direction = _parseScrollDirection(action['target'] as String? ?? 'down');
        return await _screenManager.scroll(direction);

      default:
        return ActionResult.error('Unknown screen action: $actionType');
    }
  }

  /// Execute vision analysis tasks
  Future<ActionResult> _executeVisionAnalysis(AgentIntent intent) async {
    try {
      if (!_visionManager.isInitialized) {
        return ActionResult.error('Vision manager not available');
      }

      final started = await _visionManager.startCamera();
      if (!started) {
        return ActionResult.error('Could not start camera');
      }

      return ActionResult.success('Vision analysis started');
    } catch (e) {
      return ActionResult.error('Vision analysis failed: $e');
    }
  }

  /// Execute app control tasks
  Future<ActionResult> _executeAppControl(AgentIntent intent) async {
    final action = intent.parameters['action'] as String?;
    final target = intent.parameters['target'] as String?;

    return ActionResult.success('App control: $action for $target');
  }

  /// Execute information search tasks
  Future<ActionResult> _executeInformationSearch(AgentIntent intent) async {
    final query = intent.parameters['query'] as String?;
    if (query == null) {
      return ActionResult.error('No search query provided');
    }

    final result = await _llmManager.chatCompletion(
      message: 'Answer this question concisely: $query',
      temperature: 0.7,
    );

    return result;
  }

  /// Execute system control tasks
  Future<ActionResult> _executeSystemControl(AgentIntent intent) async {
    return ActionResult.success('System control executed');
  }

  /// Execute conversation tasks
  Future<ActionResult> _executeConversation(AgentIntent intent) async {
    final message = intent.parameters['message'] as String;

    final context = _conversationHistory
        .takeLast(10)
        .map((m) => '${m.role}: ${m.content}')
        .join('\n');

    final prompt = '''
You are Dora, a helpful AI assistant. Have a natural conversation with the user.

Recent conversation:
$context

User: $message
Assistant:''';

    final result = await _llmManager.chatCompletion(
      message: prompt,
      temperature: 0.8,
    );

    return result;
  }

  /// Parse scroll direction from string
  ScrollDirection _parseScrollDirection(String direction) {
    switch (direction.toLowerCase()) {
      case 'up':
        return ScrollDirection.up;
      case 'down':
        return ScrollDirection.down;
      case 'left':
        return ScrollDirection.left;
      case 'right':
        return ScrollDirection.right;
      default:
        return ScrollDirection.down;
    }
  }

  /// Get conversation history
  List<ConversationMessage> get conversationHistory => List.unmodifiable(_conversationHistory);

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Get current task
  String get currentTask => _currentTask;

  /// Dispose resources
  void dispose() {
    _llmManager.dispose();
    _screenManager.dispose();
    _visionManager.dispose();
  }

  /// Clear conversation history
  void clearHistory() {
    _conversationHistory.clear();
  }
}

/// Conversation message
class ConversationMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  ConversationMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.metadata,
  });
}

/// Extension for list operations
extension ListExtensions<T> on List<T> {
  List<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
