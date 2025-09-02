/// Advanced Screen Interaction Manager for AI Agent
/// Provides screen capture, UI element interaction, and intelligent decision making
library screen_interaction_manager;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'agent_core.dart';
import 'local_llm_manager.dart';

/// Screen interaction capabilities for the AI agent
class ScreenInteractionManager {
  static ScreenInteractionManager? _instance;
  static ScreenInteractionManager get instance => _instance ??= ScreenInteractionManager._();
  ScreenInteractionManager._();

  // State management
  bool _isInitialized = false;
  List<UIElement> _detectedElements = [];
  Uint8List? _lastScreenshot;

  // Interaction history
  final List<ScreenInteraction> _interactionHistory = [];

  /// Initialize the screen interaction manager
  Future<bool> initialize() async {
    try {
      _isInitialized = true;
      debugPrint('Screen Interaction Manager initialized');
      return true;
    } catch (e) {
      debugPrint('Failed to initialize Screen Interaction Manager: $e');
      return false;
    }
  }

  /// Capture current screen and analyze it
  Future<ScreenAnalysis> analyzeScreen() async {
    if (!_isInitialized) {
      throw Exception('ScreenInteractionManager not initialized');
    }

    try {
      // Capture screenshot
      final screenshot = await _captureScreen();
      if (screenshot == null) {
        return ScreenAnalysis.error('Failed to capture screen');
      }

      _lastScreenshot = screenshot;

      // Analyze UI elements (simplified without ML Kit)
      final elements = await _detectUIElements(screenshot);
      final text = await _extractText(screenshot);

      // Use LLM to understand the screen content
      final understanding = await _generateScreenUnderstanding(elements, text);

      _detectedElements = elements;

      return ScreenAnalysis(
        success: true,
        elements: elements,
        text: text,
        understanding: understanding,
        screenshot: screenshot,
      );
    } catch (e) {
      return ScreenAnalysis.error('Screen analysis failed: $e');
    }
  }

  /// Capture screenshot of current screen
  Future<Uint8List?> _captureScreen() async {
    try {
      // Use platform-specific screenshot capture
      const platform = MethodChannel('dora/screen_capture');
      final result = await platform.invokeMethod('captureScreen');
      return result as Uint8List?;
    } catch (e) {
      debugPrint('Screenshot capture failed: $e');
      return null;
    }
  }

  /// Detect UI elements that can be interacted with (simplified)
  Future<List<UIElement>> _detectUIElements(Uint8List screenshot) async {
    final elements = <UIElement>[];

    try {
      // For now, create mock elements - in a real implementation this would
      // use computer vision or accessibility services
      elements.add(UIElement(
        id: '1',
        type: UIElementType.button,
        text: 'Mock Button',
        bounds: const Rect.fromLTWH(100, 100, 200, 50),
        confidence: 0.8,
      ));

      return elements;
    } catch (e) {
      debugPrint('UI element detection failed: $e');
      return elements;
    }
  }

  /// Extract all text from screen (simplified)
  Future<String> _extractText(Uint8List screenshot) async {
    try {
      // For now, return mock text - in a real implementation this would
      // use OCR or accessibility services
      return 'Mock extracted text from screen';
    } catch (e) {
      debugPrint('Text extraction failed: $e');
      return '';
    }
  }

  /// Generate AI understanding of the screen content
  Future<String> _generateScreenUnderstanding(
    List<UIElement> elements,
    String text,
  ) async {
    try {
      final prompt = '''
Analyze this mobile app screen:

UI Elements found:
${elements.map((e) => '- ${e.type}: "${e.text}" at ${e.bounds}').join('\n')}

Text content:
$text

Provide a concise understanding of:
1. What app/screen this appears to be
2. What actions are available
3. Key interactive elements
4. Current state/context

Keep response under 200 words.
''';

      final result = await LocalLLMManager.instance.chatCompletion(
        message: prompt,
        temperature: 0.3,
      );

      return result.success ? result.message : 'Could not analyze screen content';
    } catch (e) {
      return 'Screen analysis unavailable';
    }
  }

  /// Perform click action on screen coordinates
  Future<ActionResult> clickAt(double x, double y) async {
    try {
      const platform = MethodChannel('dora/screen_interaction');
      await platform.invokeMethod('clickAt', {'x': x, 'y': y});

      // Record interaction
      _interactionHistory.add(ScreenInteraction(
        type: InteractionType.tap,
        x: x,
        y: y,
        timestamp: DateTime.now(),
      ));

      return ActionResult.success('Clicked at ($x, $y)');
    } catch (e) {
      return ActionResult.error('Click failed: $e');
    }
  }

  /// Click on a UI element by its properties
  Future<ActionResult> clickElement({
    String? text,
    UIElementType? type,
    String? containsText,
  }) async {
    try {
      final element = _findElement(text: text, type: type, containsText: containsText);
      if (element == null) {
        return ActionResult.error('Element not found');
      }

      final center = element.bounds.center;
      return await clickAt(center.dx, center.dy);
    } catch (e) {
      return ActionResult.error('Element click failed: $e');
    }
  }

  /// Type text at current cursor position
  Future<ActionResult> typeText(String text) async {
    try {
      const platform = MethodChannel('dora/screen_interaction');
      await platform.invokeMethod('typeText', {'text': text});

      _interactionHistory.add(ScreenInteraction(
        type: InteractionType.type,
        text: text,
        timestamp: DateTime.now(),
      ));

      return ActionResult.success('Typed: $text');
    } catch (e) {
      return ActionResult.error('Typing failed: $e');
    }
  }

  /// Perform swipe gesture
  Future<ActionResult> swipe({
    required double startX,
    required double startY,
    required double endX,
    required double endY,
    int durationMs = 300,
  }) async {
    try {
      const platform = MethodChannel('dora/screen_interaction');
      await platform.invokeMethod('swipe', {
        'startX': startX,
        'startY': startY,
        'endX': endX,
        'endY': endY,
        'duration': durationMs,
      });

      _interactionHistory.add(ScreenInteraction(
        type: InteractionType.swipe,
        x: startX,
        y: startY,
        x2: endX,
        y2: endY,
        timestamp: DateTime.now(),
      ));

      return ActionResult.success('Swiped from ($startX, $startY) to ($endX, $endY)');
    } catch (e) {
      return ActionResult.error('Swipe failed: $e');
    }
  }

  /// Scroll in a direction
  Future<ActionResult> scroll(ScrollDirection direction, {double distance = 300}) async {
    try {
      // Get screen dimensions
      const platform = MethodChannel('dora/screen_interaction');
      final screenInfo = await platform.invokeMethod('getScreenInfo');
      final screenWidth = screenInfo['width'] as double;
      final screenHeight = screenInfo['height'] as double;

      double startX, startY, endX, endY;

      switch (direction) {
        case ScrollDirection.up:
          startX = screenWidth / 2;
          startY = screenHeight * 0.7;
          endX = screenWidth / 2;
          endY = screenHeight * 0.3;
          break;
        case ScrollDirection.down:
          startX = screenWidth / 2;
          startY = screenHeight * 0.3;
          endX = screenWidth / 2;
          endY = screenHeight * 0.7;
          break;
        case ScrollDirection.left:
          startX = screenWidth * 0.7;
          startY = screenHeight / 2;
          endX = screenWidth * 0.3;
          endY = screenHeight / 2;
          break;
        case ScrollDirection.right:
          startX = screenWidth * 0.3;
          startY = screenHeight / 2;
          endX = screenWidth * 0.7;
          endY = screenHeight / 2;
          break;
      }

      return await swipe(
        startX: startX,
        startY: startY,
        endX: endX,
        endY: endY,
      );
    } catch (e) {
      return ActionResult.error('Scroll failed: $e');
    }
  }

  /// Find UI element by criteria
  UIElement? _findElement({
    String? text,
    UIElementType? type,
    String? containsText,
  }) {
    for (final element in _detectedElements) {
      if (text != null && element.text.toLowerCase() == text.toLowerCase()) {
        return element;
      }
      if (type != null && element.type == type) {
        return element;
      }
      if (containsText != null &&
          element.text.toLowerCase().contains(containsText.toLowerCase())) {
        return element;
      }
    }
    return null;
  }

  /// Get interaction history
  List<ScreenInteraction> get interactionHistory => List.unmodifiable(_interactionHistory);

  /// Get last screenshot
  Uint8List? get lastScreenshot => _lastScreenshot;

  /// Get detected elements
  List<UIElement> get detectedElements => List.unmodifiable(_detectedElements);

  /// Check if initialized
  bool get isInitialized => _isInitialized;

  /// Dispose resources
  void dispose() {
    // Cleanup code here
  }
}

/// UI Element representation
class UIElement {
  final String id;
  final UIElementType type;
  final String text;
  final Rect bounds;
  final double confidence;

  UIElement({
    required this.id,
    required this.type,
    required this.text,
    required this.bounds,
    required this.confidence,
  });
}

/// Types of UI elements
enum UIElementType {
  button,
  textField,
  text,
  image,
  link,
  icon,
  container,
}

/// Screen interaction types
enum InteractionType {
  tap,
  swipe,
  type,
  scroll,
}

/// Scroll directions
enum ScrollDirection {
  up,
  down,
  left,
  right,
}

/// Screen interaction record
class ScreenInteraction {
  final InteractionType type;
  final double? x;
  final double? y;
  final double? x2;
  final double? y2;
  final String? text;
  final DateTime timestamp;

  ScreenInteraction({
    required this.type,
    this.x,
    this.y,
    this.x2,
    this.y2,
    this.text,
    required this.timestamp,
  });
}

/// Screen analysis result
class ScreenAnalysis {
  final bool success;
  final String? error;
  final List<UIElement> elements;
  final String text;
  final String understanding;
  final Uint8List? screenshot;

  ScreenAnalysis({
    required this.success,
    this.error,
    this.elements = const [],
    this.text = '',
    this.understanding = '',
    this.screenshot,
  });

  ScreenAnalysis.error(String errorMessage)
      : success = false,
        error = errorMessage,
        elements = const [],
        text = '',
        understanding = '',
        screenshot = null;
}
