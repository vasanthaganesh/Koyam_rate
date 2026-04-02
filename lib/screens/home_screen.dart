import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vegetable_price.dart';
import '../services/price_service.dart';
import '../providers/favorites_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/matte_frosted_glass_card.dart';
import '../providers/language_provider.dart';
import 'detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final PriceService _service = PriceService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<VegetablePrice> _prices = [];
  List<VegetablePrice> _filtered = [];
  String _selectedCategory = 'all';
  bool _isLoading = true;
  String? _error;
  
  bool _isOfflineCached = false;
  String? _cacheTimestamp;
  DateTime? _dataDate;

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All'},
    {'key': 'vegetables', 'label': 'Vegetables'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _isOfflineCached = false;
      _cacheTimestamp = null;
      _dataDate = null;
    });

    try {
      final (prices, dataDate) = await _service.fetchPrices();
      if (mounted) {
        setState(() {
          _prices = prices;
          _filtered = prices;
          _dataDate = dataDate;
          _isLoading = false;
        });
      }
    } catch (e) {
      final cached = await _service.loadCachedPrices();
      if (mounted) {
        if (cached != null) {
          setState(() {
            _prices = cached.$1;
            _filtered = cached.$1;
            _cacheTimestamp = cached.$2;
            _dataDate = cached.$3;
            _isOfflineCached = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = e.toString();
            _isLoading = false;
          });
        }
      }
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim();
    setState(() {
      _filtered = _prices.where((p) {
        final matchCategory =
            _selectedCategory == 'all' || p.category == _selectedCategory;
        final matchSearch = q.isEmpty ||
            p.itemEng.toLowerCase().contains(q.toLowerCase()) ||
            p.itemTamil.contains(q);
        return matchCategory && matchSearch;
      }).toList();
    });
  }

  void _selectCategory(String key) {
    setState(() {
      _selectedCategory = key;
    });
    _onSearch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTamil = ref.watch(languageProvider);
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(isTamil),
            _buildCategoryTabs(isTamil),
            _buildUpdateBanner(isTamil),
            Expanded(child: _buildBody(isTamil)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isTamil) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(isTamil ? 'விலைப்பட்டியல் பதிவிறங்குகிறது...' : 'Loading market rates...', style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Could not load prices',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildGrid(isTamil);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icon.png',
              width: 40,
              height: 40,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'KoyamRate',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isTamil) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: isTamil ? 'காய்கறிகளைத் தேடுக...' : 'Search vegetables...',
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(bool isTamil) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['key'];
          
          String getLabel() {
            if (!isTamil) return cat['label']!;
            if (cat['key'] == 'all') return 'அனைத்தும்';
            if (cat['key'] == 'vegetables') return 'காய்கறிகள்';
            return cat['label']!;
          }

          return GestureDetector(
            onTap: () => _selectCategory(cat['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Center(
                child: Text(
                  getLabel(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Formats a DateTime as "dd MMM yyyy"
  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatCacheTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoString;
    }
  }

  String _formatLastUpdated(bool isTamil) {
    if (_prices.isEmpty) return isTamil ? 'புதுப்பிக்கப்படுகிறது...' : 'Syncing...';
    final marketDate = _prices.first.date;
    if (marketDate.isEmpty) return isTamil ? 'நேரலை' : 'Live Sync';
    
    try {
      final dateObj = DateTime.parse(marketDate);
      final now = DateTime.now();
      if (dateObj.year == now.year && dateObj.month == now.month && dateObj.day == now.day) {
        return isTamil ? 'இன்று புதுப்பிக்கப்பட்டது' : 'Updated Today';
      }
      return isTamil ? '$marketDate அன்று புதுப்பிக்கப்பட்டது' : 'Updated on $marketDate';
    } catch (_) {
      return isTamil ? '$marketDate அன்று புதுப்பிக்கப்பட்டது' : 'Updated on $marketDate';
    }
  }

  Widget _buildUpdateBanner(bool isTamil) {
    final now = DateTime.now();
    final isToday = _dataDate != null && 
        _dataDate!.year == now.year && 
        _dataDate!.month == now.month && 
        _dataDate!.day == now.day;

    return Column(
      children: [
        if (_isOfflineCached && _cacheTimestamp != null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            width: double.infinity,
            color: Colors.amber.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.offline_bolt, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Text(
                  isTamil 
                    ? 'ஆஃப்லைன்: கடைசியாக புதுப்பிக்கப்பட்டது ${_formatCacheTime(_cacheTimestamp!)}'
                    : 'Cached — last updated ${_formatCacheTime(_cacheTimestamp!)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.amber.shade900),
                ),
              ],
            ),
          ),
        if (_dataDate != null && !isToday)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 16, color: Colors.blue.shade800),
                const SizedBox(width: 8),
                Text(
                  isTamil 
                    ? 'பழைய விலைப்பட்டியல்: ${_formatDate(_dataDate!)}'
                    : 'Prices from ${_formatDate(_dataDate!)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blue.shade900),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: isTamil ? 'தினசரி சந்தை விலை  ' : 'Daily Market Rates  ',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      TextSpan(
                        text: isTamil ? '${_prices.length} பொருட்கள்' : '${_prices.length} items',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                _formatLastUpdated(isTamil),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(bool isTamil) {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(isTamil ? 'பொருட்கள் இல்லை' : 'No items found', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadData,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.72,
        ),
        itemCount: _filtered.length,
        itemBuilder: (context, i) => _buildVegCard(_filtered[i], isTamil),
      ),
    );
  }

  String _getImagePath(String itemEng) {
    // Robust sanitization: preserve case for Android asset matching
    final fileName = itemEng
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'assets/images/vegetables/$fileName.png';
  }

  Widget _buildVegCard(VegetablePrice item, bool isTamil) {
    // Watch relevant part of state only
    final isFav = ref.watch(favoritesProvider.select(
      (data) => data.value?.contains(item.id) ?? false
    ));
    final imagePath = _getImagePath(item.itemEng);

    return MatteFrostedGlassCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(item: item)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      cacheWidth: 300, // Optimize memory for thumbnails
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.greenLight,
                          child: Center(
                            child: Icon(Icons.local_florist, size: 40, color: AppColors.green.withValues(alpha: 0.5)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      if (Supabase.instance.client.auth.currentUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please log in to add favorites'), backgroundColor: AppColors.primary),
                        );
                        return;
                      }
                      ref.read(favoritesProvider.notifier).toggleFavorite(item.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x15000000), blurRadius: 4)],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isFav ? AppColors.primary : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTamil ? item.itemTamil : item.itemEng,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            isTamil ? item.itemEng : item.itemTamil,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '\u20b9${item.minPrice.toInt()}-${item.maxPrice.toInt()}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                ),
                TextSpan(
                  text: '/kg',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w400, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
