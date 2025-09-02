/// Dora AI Agent Manager - Fixed implementation
library agent_manager;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_core.dart';
import 'system_actions.dart';

/// Main AI Agent class for Dora
class DoraAIAgent {
  // Core configuration
  String? _openAIKey;
  String? _baseUrl;
  String? _model;

  // Action registry
  final Map<String, AgentAction> _actions = {};
  final Set<AgentCapability> _enabledCapabilities = {};

  // State
  bool _isInitialized = false;

  /// Initialize the agent with default actions
  DoraAIAgent() {
    _initializeDefaultActions();
  }

  void _initializeDefaultActions() {
    registerAction(OpenAppAction());
    registerAction(MakeCallAction());
    registerAction(SendSMSAction());
    registerAction(OpenSettingsAction());
    registerAction(WebSearchAction());
    registerAction(TimeInfoAction());

    // Enable all capabilities by default
    enableCapability(AgentCapability.systemControl);
    enableCapability(AgentCapability.communication);
    enableCapability(AgentCapability.information);
    enableCapability(AgentCapability.media);
    enableCapability(AgentCapability.automation);
    enableCapability(AgentCapability.learning);

    _isInitialized = true;
  }

  /// Register a new action
  void registerAction(AgentAction action) {
    _actions[action.name] = action;
  }

  /// Enable a capability
  void enableCapability(AgentCapability capability) {
    _enabledCapabilities.add(capability);
  }

  /// Configure OpenAI API
  void setOpenAIKey(String apiKey) {
    _openAIKey = apiKey;
  }

  /// Configure custom LLM provider
  void configureOpenSourceLLM({
    required String baseUrl,
    required String model,
    String? apiKey,
    bool stream = false,
  }) {
    _baseUrl = baseUrl;
    _model = model;
    _openAIKey = apiKey;
    // Removed unused _streamingEnabled
  }

  /// Configure Hugging Face model
  void configureHuggingFace({
    required String model,
    String? token,
  }) {
    _baseUrl = 'https://api-inference.huggingface.co/models';
    _model = model;
    _openAIKey = token;
  }

  /// Configure OpenAI audio model
  void configureOpenAIAudioModel({
    required String model,
    required String voice,
    required String apiKey,
  }) {
    _baseUrl = 'https://api.openai.com/v1';
    _model = model;
    _openAIKey = apiKey;
  }

  /// Process user input and return appropriate response
  Future<ActionResult> processUserInput(String input) async {
    if (!_isInitialized) {
      return ActionResult.error('Agent not initialized');
    }

    try {
      // First, try to match with registered actions
      for (final action in _actions.values) {
        if (action.canExecute(input)) {
          // Check if required capabilities are enabled
          if (action.requiredCapabilities.every(_enabledCapabilities.contains)) {
            final parameters = await _extractParameters(input, action);
            return await action.execute(parameters);
          } else {
            return ActionResult.error('Required capabilities not enabled for this action');
          }
        }
      }

      // If no action matches, use LLM for conversation
      return await _handleConversation(input);
    } catch (e) {
      return ActionResult.error('Failed to process input: $e');
    }
  }

  /// Extract parameters for action execution
  Future<Map<String, dynamic>> _extractParameters(String input, AgentAction action) async {
    // Basic parameter extraction - this could be enhanced with NLP
    final parameters = <String, dynamic>{};

    switch (action.name) {
      case 'open_app':
        parameters['app_name'] = _extractAppName(input);
        break;
      case 'make_call':
        final contact = _extractContactName(input);
        final number = _extractPhoneNumber(input);
        if (contact != null) parameters['contact_name'] = contact;
        if (number != null) parameters['phone_number'] = number;
        break;
      case 'send_sms':
        parameters['phone_number'] = _extractPhoneNumber(input);
        parameters['message'] = _extractMessage(input);
        break;
      case 'open_settings':
        parameters['settings_type'] = _extractSettingsType(input);
        break;
      case 'web_search':
        parameters['query'] = _extractSearchQuery(input);
        break;
      case 'time_info':
        parameters['info_type'] = _extractTimeInfoType(input);
        break;
    }

    return parameters;
  }

  /// Handle conversational input using LLM
  Future<ActionResult> _handleConversation(String input) async {
    if (_openAIKey == null) {
      return ActionResult.success(_getBuiltinResponse(input));
    }

    try {
      final response = await _callLLM(input);
      return ActionResult.success(response);
    } catch (e) {
      return ActionResult.success(_getBuiltinResponse(input));
    }
  }

  /// Call LLM API for conversation
  Future<String> _callLLM(String input) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_openAIKey',
    };

    final body = {
      'model': _model ?? 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': 'You are Dora, a helpful AI assistant.'},
        {'role': 'user', 'content': input},
      ],
      'max_tokens': 150,
      'temperature': 0.7,
    };

    final url = _baseUrl ?? 'https://api.openai.com/v1';
    final response = await http.post(
      Uri.parse('$url/chat/completions'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('LLM API call failed: ${response.statusCode}');
    }
  }

  /// Get built-in response for basic queries
  String _getBuiltinResponse(String input) {
    final lowercaseInput = input.toLowerCase();

    if (lowercaseInput.contains('hello') || lowercaseInput.contains('hi')) {
      return 'Hello! How can I help you today?';
    } else if (lowercaseInput.contains('how are you')) {
      return 'I\'m doing well, thank you! Ready to assist you.';
    } else if (lowercaseInput.contains('thank you') || lowercaseInput.contains('thanks')) {
      return 'You\'re welcome! Happy to help.';
    } else {
      return 'I heard you say: "$input". How can I help you with that?';
    }
  }

  // Parameter extraction methods
  String _extractAppName(String input) {
    final words = input.toLowerCase().split(' ');
    final openIndex = words.contains('open') ? words.indexOf('open') :
        words.contains('launch') ? words.indexOf('launch') :
        words.contains('start') ? words.indexOf('start') : -1;

    if (openIndex != -1 && openIndex + 1 < words.length) {
      return words[openIndex + 1];
    }
    return '';
  }

  String? _extractContactName(String input) {
    final words = input.toLowerCase().split(' ');
    final callIndex = words.indexOf('call');

    if (callIndex != -1 && callIndex + 1 < words.length) {
      return words[callIndex + 1];
    }
    return null;
  }

  String? _extractPhoneNumber(String input) {
    final phoneRegex = RegExp(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b');
    final match = phoneRegex.firstMatch(input);
    return match?.group(0);
  }

  String? _extractMessage(String input) {
    final words = input.split(' ');
    final messageIndex = words.indexWhere((w) =>
    w.toLowerCase().contains('message') ||
        w.toLowerCase().contains('text') ||
        w.toLowerCase().contains('say'));

    if (messageIndex != -1 && messageIndex + 1 < words.length) {
      return words.sublist(messageIndex + 1).join(' ');
    }
    return null;
  }

  String _extractSettingsType(String input) {
    final lowercaseInput = input.toLowerCase();
    if (lowercaseInput.contains('wifi') || lowercaseInput.contains('wireless')) {
      return 'wifi';
    } else if (lowercaseInput.contains('bluetooth')) {
      return 'bluetooth';
    } else if (lowercaseInput.contains('location')) {
      return 'location';
    } else if (lowercaseInput.contains('sound') || lowercaseInput.contains('audio')) {
      return 'sound';
    }
    return 'general';
  }

  String _extractSearchQuery(String input) {
    final words = input.split(' ');
    final searchIndex = words.indexWhere((w) =>
    w.toLowerCase().contains('search') ||
        w.toLowerCase().contains('find') ||
        w.toLowerCase().contains('look'));

    if (searchIndex != -1) {
      // Remove the search command and common words
      final queryWords = words.sublist(searchIndex + 1)
          .where((w) => !['for', 'up'].contains(w.toLowerCase()))
          .toList();
      return queryWords.join(' ');
    }
    return input;
  }

  String _extractTimeInfoType(String input) {
    final lowercaseInput = input.toLowerCase();
    if (lowercaseInput.contains('time')) {
      return 'time';
    } else if (lowercaseInput.contains('date')) {
      return 'date';
    }
    return 'both';
  }

  /// Dispose resources
  void dispose() {
    _actions.clear();
    _enabledCapabilities.clear();
  }
}
