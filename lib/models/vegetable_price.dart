/// Vegetable price data model matching the Supabase "prices" table schema.
class VegetablePrice {
  final String id;
  final String date;
  final String itemTamil;
  final String itemEng;
  final double minPrice;
  final double maxPrice;
  final String? category; // vegetables, fruits, organic, grains
  final String? imageUrl;
  final DateTime updatedAt;

  const VegetablePrice({
    required this.id,
    required this.date,
    required this.itemTamil,
    required this.itemEng,
    required this.minPrice,
    required this.maxPrice,
    this.category,
    this.imageUrl,
    required this.updatedAt,
  });

  /// Average price for display
  double get avgPrice => (minPrice + maxPrice) / 2;

  /// Price range string
  String get priceRange => '₹${minPrice.toInt()}-${maxPrice.toInt()}/kg';

  factory VegetablePrice.fromJson(Map<String, dynamic> json) {
    return VegetablePrice(
      id: json['id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      itemTamil: json['item_tamil']?.toString() ?? '',
      itemEng: json['item_eng']?.toString() ?? '',
      minPrice: (json['min_price'] as num?)?.toDouble() ?? 0,
      maxPrice: (json['max_price'] as num?)?.toDouble() ?? 0,
      category: json['category']?.toString(),
      imageUrl: json['image_url']?.toString(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'item_tamil': itemTamil,
      'item_eng': itemEng,
      'min_price': minPrice,
      'max_price': maxPrice,
      'category': category,
      'image_url': imageUrl,
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
