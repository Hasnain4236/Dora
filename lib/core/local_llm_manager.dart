/// Local LLM Manager for integrating local models (DeepSeek, etc.)
/// Supports GGUF files and provides OpenAI-compatible interface
library local_llm_manager;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'agent_core.dart';

/// Local LLM provider that manages local model execution
class LocalLLMManager {
  static LocalLLMManager? _instance;
  static LocalLLMManager get instance => _instance ??= LocalLLMManager._();
  LocalLLMManager._();

  // Local server state
  Process? _serverProcess;
  bool _isServerRunning = false;
  String _serverUrl = 'http://localhost:8080';
  int _serverPort = 8080;

  // Model configuration
  String? _modelPath;
  Map<String, dynamic> _modelConfig = {};

  // Streaming state
  final StreamController<String> _responseController = StreamController.broadcast();
  Stream<String> get responseStream => _responseController.stream;

  /// Initialize local LLM with DeepSeek model
  Future<bool> initializeDeepSeek({
    required String modelPath,
    int port = 8080,
    Map<String, dynamic>? config,
  }) async {
    try {
      _modelPath = modelPath;
      _serverPort = port;
      _serverUrl = 'http://localhost:$port';
      _modelConfig = config ?? _getDefaultDeepSeekConfig();

      // Check if model file exists
      if (!await File(modelPath).exists()) {
        debugPrint('Model file not found: $modelPath');
        return false;
      }

      // Start local server
      return await _startLocalServer();
    } catch (e) {
      debugPrint('Failed to initialize DeepSeek: $e');
      return false;
    }
  }

  /// Start local model server using llama.cpp or similar
  Future<bool> _startLocalServer() async {
    try {
      if (_isServerRunning) {
        await stopServer();
      }

      // Use llama.cpp server for GGUF files
      final executable = await _findLlamaCppServer();
      if (executable == null) {
        debugPrint('llama.cpp server not found. Please install it.');
        return false;
      }

      final args = [
        '--model', _modelPath!,
        '--port', _serverPort.toString(),
        '--host', '127.0.0.1',
        '--ctx-size', _modelConfig['context_length']?.toString() ?? '4096',
        '--threads', _modelConfig['threads']?.toString() ?? '4',
        '--n-gpu-layers', _modelConfig['gpu_layers']?.toString() ?? '0',
        '--chat-template', 'chatml', // DeepSeek uses ChatML format
        '--log-format', 'json',
      ];

      _serverProcess = await Process.start(executable, args);

      // Wait for server to start
      await Future.delayed(const Duration(seconds: 3));

      // Check if server is responsive
      final isReady = await _checkServerHealth();
      if (isReady) {
        _isServerRunning = true;
        debugPrint('Local LLM server started on $_serverUrl');
        return true;
      } else {
        await stopServer();
        return false;
      }
    } catch (e) {
      debugPrint('Failed to start local server: $e');
      return false;
    }
  }

  /// Find llama.cpp server executable
  Future<String?> _findLlamaCppServer() async {
    final possiblePaths = [
      'llama-server.exe', // Windows
      'llama-server', // Linux/Mac
      './llama-server.exe',
      './llama-server',
      'C:\\llama.cpp\\llama-server.exe',
      '/usr/local/bin/llama-server',
      '/opt/homebrew/bin/llama-server',
    ];

    for (final path in possiblePaths) {
      try {
        final result = await Process.run('where', [path]);
        if (result.exitCode == 0) {
          return path;
        }
      } catch (_) {
        // Try direct file check
        if (await File(path).exists()) {
          return path;
        }
      }
    }
    return null;
  }

  /// Check if local server is healthy
  Future<bool> _checkServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }

  /// Send chat completion request to local model
  Future<ActionResult> chatCompletion({
    required String message,
    List<Map<String, String>>? history,
    bool stream = false,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    if (!_isServerRunning) {
      return ActionResult.error('Local LLM server not running');
    }

    try {
      final messages = [
        if (history != null) ...history,
        {'role': 'user', 'content': message},
      ];

      final requestBody = {
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': stream,
        'stop': ['<|im_end|>', '</s>'], // DeepSeek stop tokens
      };

      if (stream) {
        return await _streamChatCompletion(requestBody);
      } else {
        return await _regularChatCompletion(requestBody);
      }
    } catch (e) {
      return ActionResult.error('Chat completion failed: $e');
    }
  }

  /// Regular (non-streaming) chat completion
  Future<ActionResult> _regularChatCompletion(Map<String, dynamic> requestBody) async {
    try {
      final response = await http.post(
        Uri.parse('$_serverUrl/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return ActionResult.success(content);
      } else {
        return ActionResult.error('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      return ActionResult.error('Request failed: $e');
    }
  }

  /// Streaming chat completion
  Future<ActionResult> _streamChatCompletion(Map<String, dynamic> requestBody) async {
    try {
      final request = http.Request('POST', Uri.parse('$_serverUrl/v1/chat/completions'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Accept'] = 'text/event-stream';
      request.body = jsonEncode(requestBody);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        String fullResponse = '';

        await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data.trim() == '[DONE]') break;

              try {
                final json = jsonDecode(data);
                final delta = json['choices'][0]['delta']['content'];
                if (delta != null) {
                  fullResponse += delta;
                  _responseController.add(delta);
                }
              } catch (_) {
                // Skip malformed chunks
              }
            }
          }
        }

        return ActionResult.success(fullResponse);
      } else {
        return ActionResult.error('Stream failed: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      return ActionResult.error('Streaming failed: $e');
    }
  }

  /// Stop the local server
  Future<void> stopServer() async {
    if (_serverProcess != null) {
      _serverProcess!.kill();
      _serverProcess = null;
    }
    _isServerRunning = false;
    debugPrint('Local LLM server stopped');
  }

  /// Get default configuration for DeepSeek model
  Map<String, dynamic> _getDefaultDeepSeekConfig() {
    return {
      'context_length': 4096,
      'threads': Platform.numberOfProcessors,
      'gpu_layers': 0, // Set to > 0 if you have GPU support
      'temperature': 0.7,
      'top_p': 0.9,
      'repeat_penalty': 1.1,
    };
  }

  /// Check if server is running
  bool get isRunning => _isServerRunning;

  /// Get server URL
  String get serverUrl => _serverUrl;

  /// Dispose resources
  void dispose() {
    stopServer();
    _responseController.close();
  }
}
