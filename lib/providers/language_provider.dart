import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/price_service.dart';

// Provides the global language state (true if Tamil, false if English)
final languageProvider = NotifierProvider<LanguageNotifier, bool>(LanguageNotifier.new);

class LanguageNotifier extends Notifier<bool> {
  final PriceService _service = PriceService();

  @override
  bool build() {
    _init();
    return false; // Default to English before loading from preferences
  }

  Future<void> _init() async {
    final isTamil = await _service.isTamil();
    state = isTamil;
  }

  Future<void> setLanguage(bool isTamil) async {
    await _service.setLanguage(isTamil);
    state = isTamil;
  }
}
