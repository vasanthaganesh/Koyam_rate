import '../models/vegetable_price.dart';

/// Provides dummy CMDA vegetable price data for the POC.
/// Replace with Supabase fetch in production.
class DummyData {
  DummyData._();

  static final DateTime _today = DateTime.now();
  static String get _todayStr =>
      '${_today.year}-${_today.month.toString().padLeft(2, '0')}-${_today.day.toString().padLeft(2, '0')}';

  static final List<VegetablePrice> prices = [
    VegetablePrice(
      id: '1', date: _todayStr,
      itemTamil: 'தக்காளி', itemEng: 'Tomato',
      minPrice: 17, maxPrice: 28,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAKEoDBKhOzCttPt7unsF-tYuiMMrhoiYsNFcEn4iAXjYFqcgclCDQ94fpxYuz7pVhrzANOdrqL1NMHIaGtBQldX7alZ0fEKYhU87DTzQoL48nvKcGs7OA_SyMsDGdR3vLLvJKbVzPmX9XaF2LiwE8us0u25eIEfd2jMQjpcDm8gRw3gQHdJKNntZJjptgJDxExD9QjbXrAv2qhB4kO4J5s-_cYAGuA1Vis4kp4OZxOIYDjfOgnU2GKDIjXS-1TqB76eC7RxXUdTOE',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '2', date: _todayStr,
      itemTamil: 'வெங்காயம்', itemEng: 'Onion',
      minPrice: 35, maxPrice: 55,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB6P4DjHuxaL1nOPFr070gbq5DBJFl2F09LyZ_UVO-SAt3_d8gqRcgbaumcVMw7QP-9vjPP9LO_WMU0isnvF6zYb49715P-aQa1KhXF5eD2k71pLj9MEAkcFcfdhYoghOujX8MZT9vC9GAn_0aado4YqEUWexAsdVWCMPULXGV748PiKnnt1B9k4HO7Z5pF8jXqEDeCBMTp7rOmqHmknLxo9sZmxX7JkTr0HO7xTynknFESGRZ6hjU_5fdv_mtDgO_SqV8Shm9uNyo',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '3', date: _todayStr,
      itemTamil: 'பச்சை மிளகாய்', itemEng: 'Green Chilli',
      minPrice: 50, maxPrice: 70,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuChcoPOHf_f4KliQMCuDcGB2aE7ktds-C-mFZ07AzX455-XSL7gWyM7K5wSy5xKUHJEXDQBGBfxvCJ7bOmkAeJc3bxWoa8JnUXHrAJescrWG6ibONIEJSc8CZLEFyenYi--j4oW30mjhS7-1XbzRkhqYJsNdgP7xQutS0PbRYg7zh-0S7B--60poFqUx5XcQYdv3QzR4_evo88BDT7l45oGiGmXXYs81Y2C9Fhy2fyJfa5KcyMzPfUEpGpT2q1AMcryVBFyyQrAoLo',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '4', date: _todayStr,
      itemTamil: 'கத்தரிக்காய்', itemEng: 'Brinjal',
      minPrice: 20, maxPrice: 36,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBHG90wQzLFQwJn-i3P58O4LQYnTbiK6AP0Cfz4JGsjXXrdwSIMndRQjNCimDPjQDjjUKge8ftRpxPdKvU1_1WXQHgj1dANkKEyJQ6dGF6aE6tDwi3MX79S0qxHNLmWd4mmXn4XVHKhJOoXVk6WBzwZiRnEQRO17Nnh_ZxV-xF2y7PMca55esl7lWZfrn3cGbFkjjjJulxVq4loasj0fKQNnZqKhZFcw15c4FmaxNP51iObk1RAZhkX9gqLxvcLRnHTqxOrZZTU1RM',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '5', date: _todayStr,
      itemTamil: 'இஞ்சி', itemEng: 'Ginger',
      minPrice: 150, maxPrice: 200,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCXFy64As24hVzesnXDz63Bl0YzwLLOUrsjsGmL6V_dhG3nC1I2bkMVZVP_Xb6LappF97MLrGgvcOgAKWMbXkPAH8pwbcjJ_fph-K3DWZsfZrxigqvPBdWaCPbwVGVN6sWb9v0ZbjwwgAZ8lTw8aXCnudA5rKzdDY0vRAuEXGxx_rLph8MArpswhlLF1jU9Ku4PMfjbAhA0O0B8wW_4-21YjdRh-8utb2FdFQtOpoKJRINmJtdi5VcaWfkURh2q1CgRLxn4YZ_VV3M',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '6', date: _todayStr,
      itemTamil: 'கேரட்', itemEng: 'Carrot',
      minPrice: 45, maxPrice: 65,
      category: 'vegetables',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDTBcVw-cSAPoLB6dbjEgI6cvFuv4SNR1_ui7iWkR6929tn8Mnt9OwIpXjCGQb4Eso-Ebb6CyCHApuT8HBnjxCdgwPMHE9K7swH0nDzjyFrgT2cvBBt6Pb2NwBoXtf9l2316yPZAQFjWtYPP8ZIIQS5RHQB51Bok1gDYx418ZXKruEt8CeGKFnh5uG_18NHCV2w13aSsf-zunRO9l3S8PW_z4gWMQayjIpTM1MmSBYBip0MCDraFj4uy5t5y07XcWha1pknucMLn-Q',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '7', date: _todayStr,
      itemTamil: 'உருளைக்கிழங்கு', itemEng: 'Potato',
      minPrice: 25, maxPrice: 35,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '8', date: _todayStr,
      itemTamil: 'பீன்ஸ்', itemEng: 'Beans',
      minPrice: 40, maxPrice: 60,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '9', date: _todayStr,
      itemTamil: 'முருங்கைக்காய்', itemEng: 'Drumstick',
      minPrice: 55, maxPrice: 80,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '10', date: _todayStr,
      itemTamil: 'பூண்டு', itemEng: 'Garlic',
      minPrice: 200, maxPrice: 280,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '11', date: _todayStr,
      itemTamil: 'வாழைக்காய்', itemEng: 'Raw Banana',
      minPrice: 30, maxPrice: 45,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '12', date: _todayStr,
      itemTamil: 'பாகல்', itemEng: 'Bitter Gourd',
      minPrice: 40, maxPrice: 55,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '13', date: _todayStr,
      itemTamil: 'வெள்ளரிக்காய்', itemEng: 'Cucumber',
      minPrice: 20, maxPrice: 30,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '14', date: _todayStr,
      itemTamil: 'முட்டைகோஸ்', itemEng: 'Cabbage',
      minPrice: 15, maxPrice: 25,
      category: 'vegetables',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '15', date: _todayStr,
      itemTamil: 'காலிஃப்ளவர்', itemEng: 'Cauliflower',
      minPrice: 25, maxPrice: 40,
      category: 'vegetables',
      updatedAt: _today,
    ),
    // ── Fruits ──
    VegetablePrice(
      id: '16', date: _todayStr,
      itemTamil: 'ஆப்பிள்', itemEng: 'Apple',
      minPrice: 120, maxPrice: 180,
      category: 'fruits',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '17', date: _todayStr,
      itemTamil: 'வாழைப்பழம்', itemEng: 'Banana',
      minPrice: 40, maxPrice: 60,
      category: 'fruits',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '18', date: _todayStr,
      itemTamil: 'திராட்சை', itemEng: 'Grapes',
      minPrice: 60, maxPrice: 100,
      category: 'fruits',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '19', date: _todayStr,
      itemTamil: 'மாம்பழம்', itemEng: 'Mango',
      minPrice: 80, maxPrice: 150,
      category: 'fruits',
      updatedAt: _today,
    ),
    VegetablePrice(
      id: '20', date: _todayStr,
      itemTamil: 'கொய்யா', itemEng: 'Guava',
      minPrice: 40, maxPrice: 60,
      category: 'fruits',
      updatedAt: _today,
    ),
  ];

  /// Simulated 7-day trend data for detail screen charts
  static List<double> getTrend(String itemId) {
    // Deterministic pseudo-random trend per item
    final seed = int.tryParse(itemId) ?? 1;
    final base = prices.firstWhere((p) => p.id == itemId,
        orElse: () => prices.first);
    final avg = base.avgPrice;
    return List.generate(7, (i) {
      final variation = ((seed * 7 + i * 13) % 20 - 10).toDouble();
      return (avg + variation).clamp(0, 999);
    });
  }

  /// Bargain tips
  static String getBargainTip(String category) {
    switch (category) {
      case 'fruits':
        return 'Retail markup is usually 40-50%. Buy in bulk for savings!';
      case 'organic':
        return 'Organic items can be 2x wholesale. Compare before buying.';
      default:
        return 'Retail price is usually 25-40% higher. Shop early morning for the best rates!';
    }
  }
}
