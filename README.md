# Dora - AI Agent System

A comprehensive AI agent for Android that functions like Siri, capable of performing system actions, making calls, opening apps, and engaging in intelligent conversations.

## 🤖 Agent Architecture

Dora is built using a modular AI agent framework based on OpenAI's agent building principles:

### Core Components

1. **Agent Core** (`lib/core/agent_core.dart`)
   - Intent recognition and processing
   - Action execution framework
   - Capability management system

2. **Agent Manager** (`lib/core/agent_manager.dart`)
   - AI-powered conversation handling
   - Enhanced intent recognition with pattern matching
   - Optional OpenAI API integration

3. **System Actions** (`lib/core/system_actions.dart`)
   - App launching and control
   - Phone calls and messaging
   - System settings management
   - Web search capabilities

## 🎯 Capabilities

### System Control
- **Open Apps**: "Open Camera", "Launch Gallery", "Start Maps"
- **System Settings**: "Open WiFi settings", "Bluetooth settings"
- **App Management**: Smart app detection and launching

### Communication
- **Phone Calls**: "Call John", "Phone 555-1234"
- **Messaging**: "Send message", "Open messages"
- **Contact Integration**: Smart contact lookup

### Information & Search
- **Web Search**: "Search for weather", "Look up restaurants"
- **General Questions**: AI-powered conversation
- **Time & Date**: Built-in quick responses

### Conversation
- **Natural Language**: Intelligent chat responses
- **Context Awareness**: Maintains conversation context
- **Adaptive Learning**: Improves with usage

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.3.3+)
- Android Studio
- Android device or emulator
- Microphone permissions

### Installation

1. **Clone and Setup**
   ```bash
   git clone <your-repo>
   cd dora
   flutter pub get
   ```

2. **Android Permissions**
   The app includes necessary permissions for:
   - Microphone access
   - Phone calls
   - SMS sending
   - Contact access
   - App launching

3. **Run the App**
   ```bash
   flutter run
   ```

### Optional: AI Enhancement

To enable advanced AI conversations, add your OpenAI API key:

```dart
// In your main.dart initialization
_agent.setOpenAIKey('your-api-key-here');
```

## 📱 Usage Examples

### Voice Commands

**System Control:**
- "Open Camera"
- "Launch Google Maps"
- "Open WiFi settings"
- "Start Calculator"

**Communication:**
- "Call Mom"
- "Phone 555-123-4567"
- "Open messages"

**Information:**
- "Search for pizza near me"
- "What's the weather like?"
- "Look up Flutter documentation"

**Conversation:**
- "Hello Dora"
- "What can you do?"
- "Tell me a joke"

## 🏗️ Architecture Deep Dive

### Agent Framework

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Input    │───▶│  Intent Engine  │───▶│  Action System  │
│  (Voice/Text)   │    │  (AI-Enhanced)  │    │  (Capabilities) │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌─────────────────┐
                       │  AI Conversation│
                       │   (OpenAI API)  │
                       └─────────────────┘
```

### Intent Recognition Flow

1. **Voice Input** → Speech-to-Text
2. **Text Analysis** → Pattern matching + AI context
3. **Intent Classification** → System action vs. conversation
4. **Action Execution** → Platform-specific implementations
5. **Response Generation** → Text-to-Speech output

### Capability System

Each action requires specific capabilities:
- `systemControl`: App launching, settings
- `communication`: Calls, messages
- `information`: Web search, data lookup
- `media`: Audio/video control
- `automation`: Scheduling, reminders
- `learning`: User preference adaptation

## 🔧 Customization

### Adding New Actions

1. Create a new action class extending `AgentAction`:

```dart
class CustomAction extends AgentAction {
  @override
  String get name => 'custom_action';
  
  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.systemControl};
  
  @override
  bool canExecute(String userInput) {
    return userInput.toLowerCase().contains('custom');
  }
  
  @override
  Future<AgentResult> execute(Map<String, dynamic> parameters) async {
    // Your custom logic here
    return AgentResult.success('Action completed!');
  }
}
```

2. Register the action in `DoraAIAgent`:

```dart
void _initializeAgent() {
  registerAction(CustomAction());
  // ... other actions
}
```

### Enhancing AI Capabilities

- Integrate with different AI providers (Anthropic, Google, etc.)
- Add memory and context persistence
- Implement user preference learning
- Add multi-language support

## 🛡️ Permissions & Security

### Required Android Permissions
- `RECORD_AUDIO`: Voice input
- `CALL_PHONE`: Making calls
- `SEND_SMS`: Text messaging
- `READ_CONTACTS`: Contact lookup
- `QUERY_ALL_PACKAGES`: App detection
- `INTERNET`: Web search and AI API

### Privacy Considerations
- Voice data processed locally when possible
- Optional cloud AI (OpenAI) with user consent
- No persistent storage of voice data
- Contact access only for call/message features

## 🔍 Troubleshooting

### Common Issues

1. **Speech Recognition Errors**
   - Enable microphone permissions
   - Try on-device mode in settings
   - Check internet connectivity

2. **App Launch Failures**
   - Verify app installation
   - Check system permissions
   - Try alternative app names

3. **Call/Message Issues**
   - Grant phone permissions
   - Verify contact access
   - Test with direct numbers

### Debug Mode
Enable verbose logging in settings for detailed troubleshooting information.

## 🚧 Development Roadmap

- [ ] Multi-language support
- [ ] Custom voice training
- [ ] Smart home integration
- [ ] Calendar and reminder system
- [ ] Location-based actions
- [ ] Plugin architecture for third-party extensions

## 📄 License

This project is open source. Feel free to contribute and enhance Dora's capabilities!

---

**Dora** - Your intelligent AI companion for Android devices.
