import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingProvider with ChangeNotifier {
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  static const String _geminiApiKey = 'geminiApiKey';
  static const String _geminiModelKey = 'geminiModel';

  static const List<String> _settingKeysToSheet = [
    _geminiApiKey,
    _geminiModelKey,
  ];
  static const List<String> _availableModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
  ];

  List<String> get availableModels => _availableModels;

  bool _initialized = false;
  void reset() {
    _initialized = false;
    notifyListeners();
  }

  Set<String> get sheetKeys => Set.unmodifiable(_settingKeysToSheet);

  String _geminiAPIKey = '';
  String _geminiModel = '';

  String get geminiAPIKey => _geminiAPIKey;
  String get geminiModel => _geminiModel;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _geminiAPIKey = (await storage.read(key: 'gemini-api-key')) ?? '';
    _geminiModel = (await storage.read(key: 'gemini-model')) ?? '';
    if (availableModels.contains(_geminiModel) == false) {
      _geminiModel = availableModels.first;
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> geminiSetting(String apiKey, String model) async {
    _geminiAPIKey = apiKey;
    _geminiModel = model;
    await storage.write(key: 'gemini-api-key', value: _geminiAPIKey);
    await storage.write(key: 'gemini-model', value: _geminiModel);
    notifyListeners();
  }
}
