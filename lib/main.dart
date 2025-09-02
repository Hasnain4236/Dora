/// Dora AI - Advanced Voice Assistant with Local LLM Integration - FINAL FIX
/// Optimized for performance with hot reload support and background processing
library main;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

// Core imports - FIXED all imports
import 'core/state_management.dart';
import 'core/animated_ui.dart';
import 'command_processor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const DoraApp());
}

class DoraApp extends StatelessWidget {
  const DoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => DoraStateManager.instance,
      child: Consumer<DoraStateManager>(
        builder: (context, stateManager, child) {
          return MaterialApp(
            title: 'Dora AI Assistant',
            debugShowCheckedModeBanner: false,
            theme: stateManager.darkMode ? _darkTheme : _lightTheme,
            home: const DoraMainScreen(),
            builder: (context, child) {
              return RepaintBoundary(child: child!);
            },
          );
        },
      ),
    );
  }

  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.purple,
    scaffoldBackgroundColor: const Color(0xFF0A0A0A),
    cardColor: const Color(0xFF1A1A1A),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(color: Colors.white70),
    ),
  );

  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
  );
}

class DoraMainScreen extends StatefulWidget {
  const DoraMainScreen({super.key});

  @override
  State<DoraMainScreen> createState() => _DoraMainScreenState();
}

class _DoraMainScreenState extends State<DoraMainScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // Voice components
  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  // State management
  late DoraStateManager _stateManager;

  // Animation controllers
  late AnimationController _orbController;
  late AnimationController _backgroundController;

  // Voice state
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  String _currentText = '';
  String _responseText = '';
  List<double> _audioLevels = [];

  // Hot reload optimization
  static bool _isInitialized = false;
  Timer? _initializationTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _stateManager = context.read<DoraStateManager>();

    // Initialize controllers
    _orbController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Optimized initialization
    if (!_isInitialized) {
      _initializeComponents();
      _isInitialized = true;
    } else {
      _quickReconnect();
    }
  }

  /// Initialize components
  void _initializeComponents() async {
    try {
      _speech = stt.SpeechToText();
      _tts = FlutterTts();

      await _configureTTS();
      await _stateManager.initialize();
      _setupStateListeners();

    } catch (e) {
      debugPrint('Initialization error: $e');
      _showError('Initialization failed: $e');
    }
  }

  /// Quick reconnect for hot reload
  void _quickReconnect() async {
    try {
      _setupStateListeners();

      if (mounted) {
        setState(() {
          _currentText = _stateManager.lastInput;
          _responseText = _stateManager.lastResponse;
        });
      }
    } catch (e) {
      debugPrint('Quick reconnect error: $e');
    }
  }

  /// Configure TTS
  Future<void> _configureTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = true);
        _stateManager.updateVoiceState(speaking: true);
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isSpeaking = false);
        _stateManager.updateVoiceState(speaking: false);
      }
    });
  }

  /// Set up state listeners
  void _setupStateListeners() {
    _stateManager.addListener(_onStateChanged);
  }

  /// Handle state changes
  void _onStateChanged() {
    if (!mounted) return;

    setState(() {
      _isListening = _stateManager.isListening;
      _isProcessing = _stateManager.isProcessing;
      _isSpeaking = _stateManager.isSpeaking;
      _currentText = _stateManager.lastInput;
      _responseText = _stateManager.lastResponse;
      _audioLevels = _stateManager.audioLevels;
    });
  }

  /// Start listening
  Future<void> _startListening() async {
    if (_isListening || _isProcessing) return;

    try {
      final permission = await Permission.microphone.request();
      if (permission != PermissionStatus.granted) {
        _showError('Microphone permission required');
        return;
      }

      final available = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: false,
      );

      if (!available) {
        _showError('Speech recognition not available');
        return;
      }

      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
        localeId: 'en_US',
      );

      setState(() {
        _isListening = true;
        _currentText = 'Listening...';
      });

      _stateManager.updateVoiceState(listening: true);
      _orbController.forward();

    } catch (e) {
      debugPrint('Start listening error: $e');
      _showError('Failed to start listening: $e');
    }
  }

  /// Stop listening
  Future<void> _stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      setState(() => _isListening = false);
      _stateManager.updateVoiceState(listening: false);
      _orbController.reverse();
    } catch (e) {
      debugPrint('Stop listening error: $e');
    }
  }

  /// Handle speech results
  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!mounted) return;

    setState(() {
      _currentText = result.recognizedWords;
    });

    // Process the final result when speech recognition is complete
    if (result.finalResult) {
      _processUserInput(result.recognizedWords);
    }
  }

  /// Handle speech status
  void _onSpeechStatus(String status) {
    debugPrint('Speech status: $status');

    if (status == 'done' || status == 'notListening') {
      if (mounted && _isListening) {
        setState(() => _isListening = false);
        _stateManager.updateVoiceState(listening: false);
        _orbController.reverse();
      }
    }
  }

  /// Handle speech errors
  void _onSpeechError(dynamic error) {
    debugPrint('Speech error: $error');

    if (mounted) {
      setState(() {
        _isListening = false;
        _currentText = 'Speech error occurred';
      });

      _stateManager.updateVoiceState(listening: false);
      _orbController.reverse();

      final errorString = error.toString().toLowerCase();
      if (errorString.contains('no_match') || errorString.contains('timeout')) {
        _scheduleAutoRetry();
      }
    }
  }

  /// Schedule retry
  void _scheduleAutoRetry() {
    Timer(const Duration(seconds: 2), () {
      if (mounted && !_isListening && !_isProcessing) {
        _startListening();
      }
    });
  }

  /// Process user input
  Future<void> _processUserInput(String input) async {
    if (input.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
      _currentText = input;
      _responseText = 'Processing...';
    });

    _stateManager.updateVoiceState(processing: true);

    try {
      final builtinResponse = processBuiltinCommand(input);
      if (builtinResponse != null) {
        await _handleResponse(builtinResponse);
        return;
      }

      await _stateManager.processVoiceInput(input);
      final response = _stateManager.lastResponse;
      await _handleResponse(response);

    } catch (e) {
      debugPrint('Processing error: $e');
      await _handleResponse('Sorry, I encountered an error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
        _stateManager.updateVoiceState(processing: false);
      }
    }
  }

  /// Handle response
  Future<void> _handleResponse(String response) async {
    if (!mounted) return;

    setState(() => _responseText = response);

    try {
      await _tts.speak(response);

      Timer(const Duration(seconds: 1), () {
        if (mounted && !_isListening && !_isProcessing && !_isSpeaking) {
          _startListening();
        }
      });

    } catch (e) {
      debugPrint('TTS error: $e');
    }
  }

  /// Show error
  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Handle lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        if (_isListening) _stopListening();
        break;
      case AppLifecycleState.resumed:
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildMainContent()),
              _buildControls(),
              _buildConversationHistory(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingButtons(),
    );
  }

  /// Build header
  Widget _buildHeader() {
    return Consumer<DoraStateManager>(
      builder: (context, state, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dora AI',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        state.activityStatus,
                        style: TextStyle(
                          color: state.statusColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (state.wakeWordListening)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mic, size: 16, color: Colors.green),
                              const SizedBox(width: 4),
                              Text(
                                state.wakeWord.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () => _showSettingsDialog(),
                      ),
                    ],
                  ),
                ],
              ),

              if (state.lastError.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.lastError,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build main content
  Widget _buildMainContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DoraAnimatedOrb(
            isListening: _isListening,
            isProcessing: _isProcessing,
            isSpeaking: _isSpeaking,
            responseText: _responseText,
            audioLevels: _audioLevels,
            onTap: _isListening ? _stopListening : _startListening,
          ),

          const SizedBox(height: 32),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(minHeight: 80),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.3),
              ),
            ),
            child: Center(
              child: Text(
                _currentText.isEmpty ? 'Tap the orb to start speaking' : _currentText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_responseText.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                _responseText,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontSize: 15,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// Build controls
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          DoraFloatingButton(
            icon: _isListening ? Icons.mic_off : Icons.mic,
            isActive: _isListening,
            onPressed: _isListening ? _stopListening : _startListening,
          ),

          DoraFloatingButton(
            icon: Icons.stop,
            isActive: false,
            onPressed: () async {
              await _stopListening();
              await _tts.stop();
              setState(() {
                _currentText = '';
                _responseText = '';
                _isProcessing = false;
                _isSpeaking = false;
              });
            },
          ),

          DoraFloatingButton(
            icon: Icons.touch_app,
            isActive: false,
            onPressed: () => _showScreenInteractionDialog(),
          ),
        ],
      ),
    );
  }

  /// Build conversation history
  Widget _buildConversationHistory() {
    return Consumer<DoraStateManager>(
      builder: (context, state, child) {
        if (state.conversationHistory.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          height: 150,
          margin: const EdgeInsets.only(top: 8),
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: state.conversationHistory.length,
            itemBuilder: (context, index) {
              final message = state.conversationHistory.reversed.toList()[index];
              final isUser = message.role == 'user';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: DoraGlassCard(
                  title: isUser ? 'You' : 'Dora',
                  content: message.content,
                  accentColor: isUser ? Colors.blue : Colors.purple,
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Build floating buttons
  Widget _buildFloatingButtons() {
    return Consumer<DoraStateManager>(
      builder: (context, state, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "vision",
              mini: true,
              onPressed: () => _toggleVisionMode(),
              child: const Icon(Icons.visibility),
            ),
            const SizedBox(height: 8),
            FloatingActionButton(
              heroTag: "clear",
              mini: true,
              onPressed: () => state.clearConversationHistory(),
              child: const Icon(Icons.clear_all),
            ),
          ],
        );
      },
    );
  }

  /// Show settings dialog
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const DoraSettingsDialog(),
    );
  }

  /// Show screen interaction dialog
  void _showScreenInteractionDialog() {
    showDialog(
      context: context,
      builder: (context) => const ScreenInteractionDialog(),
    );
  }

  /// Toggle vision mode
  void _toggleVisionMode() {
    _stateManager.setAppMode(
      _stateManager.currentMode == AppMode.vision
        ? AppMode.conversation
        : AppMode.vision
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stateManager.removeListener(_onStateChanged);
    _initializationTimer?.cancel();
    _orbController.dispose();
    _backgroundController.dispose();

    if (mounted) {
      _speech.stop();
      _tts.stop();
    }

    super.dispose();
  }
}

/// Settings dialog
class DoraSettingsDialog extends StatefulWidget {
  const DoraSettingsDialog({super.key});

  @override
  State<DoraSettingsDialog> createState() => _DoraSettingsDialogState();
}

class _DoraSettingsDialogState extends State<DoraSettingsDialog> {
  late TextEditingController _modelPathController;
  late TextEditingController _wakeWordController;

  @override
  void initState() {
    super.initState();
    final state = context.read<DoraStateManager>();
    _modelPathController = TextEditingController(text: state.llmConfig.modelPath);
    _wakeWordController = TextEditingController(text: state.wakeWord);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DoraStateManager>(
      builder: (context, state, child) {
        return AlertDialog(
          title: const Text('Dora Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _modelPathController,
                  decoration: const InputDecoration(
                    labelText: 'DeepSeek Model Path',
                    hintText: 'C:\\Users\\...\\deepseek-model.gguf',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _wakeWordController,
                  decoration: const InputDecoration(
                    labelText: 'Wake Word',
                    hintText: 'dora',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                SwitchListTile(
                  title: const Text('Enable Wake Word'),
                  subtitle: Text('Listen for "${state.wakeWord}" in background'),
                  value: state.wakeWordEnabled,
                  onChanged: (value) {
                    state.configureWakeWord(enabled: value);
                  },
                ),

                SwitchListTile(
                  title: const Text('Dark Mode'),
                  value: state.darkMode,
                  onChanged: (value) {
                    state.toggleDarkMode();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _saveSettings(state);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _saveSettings(DoraStateManager state) {
    final newConfig = state.llmConfig.copyWith(
      modelPath: _modelPathController.text.trim(),
    );
    state.configureLLM(newConfig);

    state.configureWakeWord(
      wakeWord: _wakeWordController.text.trim(),
    );
  }

  @override
  void dispose() {
    _modelPathController.dispose();
    _wakeWordController.dispose();
    super.dispose();
  }
}

/// Screen interaction dialog
class ScreenInteractionDialog extends StatelessWidget {
  const ScreenInteractionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Screen Interaction'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Screen interaction capabilities:'),
          SizedBox(height: 16),
          ListTile(
            leading: Icon(Icons.touch_app),
            title: Text('Click Detection'),
            subtitle: Text('AI can click on UI elements'),
          ),
          ListTile(
            leading: Icon(Icons.keyboard),
            title: Text('Text Input'),
            subtitle: Text('AI can type text in fields'),
          ),
          ListTile(
            leading: Icon(Icons.screenshot),
            title: Text('Screen Analysis'),
            subtitle: Text('AI can see and understand screen content'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Screen interaction test initiated'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Text('Test'),
        ),
      ],
    );
  }
}
