/// System Actions - Fixed to use ActionResult instead of AgentResult
library system_actions;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_apps/device_apps.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'agent_core.dart';

/// Action to open an app by name
class OpenAppAction extends AgentAction {
  @override
  String get name => 'open_app';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.systemControl};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('open') || input.contains('launch') || input.contains('start');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      final appName = parameters['app_name'] as String? ?? '';
      if (appName.isEmpty) {
        return ActionResult.error('No app name specified');
      }

      // Try to find and launch the app
      final apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: false,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      final targetApp = apps.cast<ApplicationWithIcon?>().firstWhere(
        (app) => app?.appName.toLowerCase().contains(appName.toLowerCase()) == true,
        orElse: () => null,
      );

      if (targetApp != null) {
        final launched = await DeviceApps.openApp(targetApp.packageName);
        if (launched) {
          return ActionResult.success('Opened ${targetApp.appName}');
        } else {
          return ActionResult.error('Failed to open ${targetApp.appName}');
        }
      } else {
        return ActionResult.error('App "$appName" not found');
      }
    } catch (e) {
      return ActionResult.error('Failed to open app: $e');
    }
  }
}

/// Action to make a phone call
class MakeCallAction extends AgentAction {
  @override
  String get name => 'make_call';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.communication};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('call') || input.contains('phone') || input.contains('dial');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      // Check permissions
      final permission = await Permission.phone.request();
      if (permission != PermissionStatus.granted) {
        return ActionResult.error('Phone permission required');
      }

      final contactName = parameters['contact_name'] as String?;
      final phoneNumber = parameters['phone_number'] as String?;

      String? numberToCall;

      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        numberToCall = phoneNumber;
      } else if (contactName != null && contactName.isNotEmpty) {
        // Look up contact
        final contactPermission = await Permission.contacts.request();
        if (contactPermission == PermissionStatus.granted) {
          final contacts = await FastContacts.getAllContacts();
          Contact? found;
          for (final c in contacts) {
            if (c.displayName.toLowerCase().contains(contactName.toLowerCase())) {
              found = c;
              break;
            }
          }
          if (found != null && found.phones.isNotEmpty) {
            numberToCall = found.phones.first.number;
          } else {
            return ActionResult.error('Contact "$contactName" not found');
          }
        } else {
          return ActionResult.error('Contacts permission required');
        }
      }

      if (numberToCall != null) {
        final uri = Uri(scheme: 'tel', path: numberToCall);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return ActionResult.success('Calling $numberToCall');
        } else {
          return ActionResult.error('Unable to make call');
        }
      } else {
        return ActionResult.error('No phone number specified');
      }
    } catch (e) {
      return ActionResult.error('Failed to make call: $e');
    }
  }
}

/// Action to send SMS
class SendSMSAction extends AgentAction {
  @override
  String get name => 'send_sms';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.communication};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('text') || input.contains('sms') || input.contains('message');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      final phoneNumber = parameters['phone_number'] as String?;
      final message = parameters['message'] as String?;

      if (phoneNumber != null && message != null) {
        final uri = Uri(
          scheme: 'sms',
          path: phoneNumber,
          queryParameters: {'body': message},
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return ActionResult.success('SMS sent to $phoneNumber');
        } else {
          return ActionResult.error('Unable to send SMS');
        }
      } else {
        return ActionResult.error('Phone number and message required');
      }
    } catch (e) {
      return ActionResult.error('Failed to send SMS: $e');
    }
  }
}

/// Action to open system settings
class OpenSettingsAction extends AgentAction {
  @override
  String get name => 'open_settings';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.systemControl};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('settings') || input.contains('config');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      final settingsType = parameters['settings_type'] as String? ?? 'general';

      // Open the appropriate Android settings using the platform channel
      const platform = MethodChannel('dora/system_actions');

      switch (settingsType.toLowerCase()) {
        case 'wifi':
        case 'wireless':
          await platform.invokeMethod('openSettings', {'type': 'wifi'});
          break;
        case 'bluetooth':
          await platform.invokeMethod('openSettings', {'type': 'bluetooth'});
          break;
        case 'location':
          await platform.invokeMethod('openSettings', {'type': 'location'});
          break;
        case 'sound':
        case 'audio':
          await platform.invokeMethod('openSettings', {'type': 'sound'});
          break;
        default:
          await platform.invokeMethod('openSettings', {'type': 'general'});
      }

      return ActionResult.success('Opened $settingsType settings');
    } catch (e) {
      return ActionResult.error('Failed to open settings: $e');
    }
  }
}

/// Action to perform web search
class WebSearchAction extends AgentAction {
  @override
  String get name => 'web_search';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.information};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('search') || input.contains('look up') || input.contains('find');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      final query = parameters['query'] as String?;
      if (query == null || query.isEmpty) {
        return ActionResult.error('No search query specified');
      }

      final encodedQuery = Uri.encodeComponent(query);
      final searchUri = Uri.parse('https://www.google.com/search?q=$encodedQuery');

      if (await canLaunchUrl(searchUri)) {
        await launchUrl(searchUri, mode: LaunchMode.externalApplication);
        return ActionResult.success('Searching for: $query');
      } else {
        return ActionResult.error('Unable to perform web search');
      }
    } catch (e) {
      return ActionResult.error('Failed to search: $e');
    }
  }
}

/// Action to get time and date information
class TimeInfoAction extends AgentAction {
  @override
  String get name => 'time_info';

  @override
  Set<AgentCapability> get requiredCapabilities => {AgentCapability.information};

  @override
  bool canExecute(String userInput) {
    final input = userInput.toLowerCase();
    return input.contains('time') || input.contains('date') || input.contains('clock');
  }

  @override
  Future<ActionResult> execute(Map<String, dynamic> parameters) async {
    try {
      final now = DateTime.now();
      final timeStr = '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
      final dateStr = '${now.day}/${now.month}/${now.year}';

      final infoType = parameters['info_type'] as String? ?? 'both';

      switch (infoType.toLowerCase()) {
        case 'time':
          return ActionResult.success('Current time: $timeStr');
        case 'date':
          return ActionResult.success('Current date: $dateStr');
        default:
          return ActionResult.success('Current time: $timeStr, Date: $dateStr');
      }
    } catch (e) {
      return ActionResult.error('Failed to get time info: $e');
    }
  }
}
