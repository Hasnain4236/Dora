/// Generic LLM (Large Language Model) provider abstraction so we can plug in
/// any OpenAI-compatible or local open-source model server (Ollama, LM Studio,
/// llama.cpp server, vLLM, etc.)
library llm_provider;

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'agent_core.dart';

/// Simple chat message representation
class ChatMessage {
  final String role; // system | user | assistant
  final String content;
  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

/// Response from an LLM chat call
class ChatResponse {
  final String content;
  final Map<String, dynamic>? raw;
  final List<int>? audioBytes; // optional synthesized audio
  const ChatResponse({required this.content, this.raw, this.audioBytes});
}

/// Streaming token callback signature
typedef TokenStreamCallback = void Function(String token);

/// Concrete LLM Provider implementation
class LLMProvider {
  final String baseUrl;
  final String model;
  final String? apiKey;
  final bool supportsStreaming;

  LLMProvider({
    required this.baseUrl,
    required this.model,
    this.apiKey,
    this.supportsStreaming = false,
  });

  /// Send a chat conversation and get a full response.
  Future<ChatResponse> sendChat({
    required List<ChatMessage> messages,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };

      if (apiKey != null) {
        headers['Authorization'] = 'Bearer $apiKey';
      }

      final body = {
        'model': model,
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': temperature,
        if (maxTokens != null) 'max_tokens': maxTokens,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return ChatResponse(content: content, raw: data);
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Chat request failed: $e');
    }
  }

  /// Optional streaming version
  Future<ChatResponse> sendChatStream({
    required List<ChatMessage> messages,
    required TokenStreamCallback onToken,
    double temperature = 0.7,
    int? maxTokens,
  }) async {
    if (!supportsStreaming) {
      // Fallback to regular chat
      final response = await sendChat(
        messages: messages,
        temperature: temperature,
        maxTokens: maxTokens,
      );
      onToken(response.content);
      return response;
    }

    // Implement streaming logic here if needed
    final response = await sendChat(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
    onToken(response.content);
    return response;
  }

  /// Simple chat method for single message
  Future<ActionResult> chat(String message) async {
    try {
      final messages = [ChatMessage(role: 'user', content: message)];
      final response = await sendChat(messages: messages);
      return ActionResult.success(response.content);
    } catch (e) {
      return ActionResult.error('Chat failed: $e');
    }
  }

  /// Stream chat method for single message
  Future<ActionResult> streamChat(String message, Function(String) onPartial) async {
    try {
      final messages = [ChatMessage(role: 'user', content: message)];
      final response = await sendChatStream(
        messages: messages,
        onToken: onPartial,
      );
      return ActionResult.success(response.content);
    } catch (e) {
      return ActionResult.error('Stream chat failed: $e');
    }
  }

  void dispose() {
    // Clean up any resources if needed
  }
}
