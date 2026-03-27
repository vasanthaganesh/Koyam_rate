import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vegetable_price.dart';
import '../providers/price_alert_provider.dart';
import '../theme/app_theme.dart';

class PriceAlertSheet extends ConsumerStatefulWidget {
  final VegetablePrice item;

  const PriceAlertSheet({super.key, required this.item});

  @override
  ConsumerState<PriceAlertSheet> createState() => _PriceAlertSheetState();
}

class _PriceAlertSheetState extends ConsumerState<PriceAlertSheet> {
  final TextEditingController _minCtrl = TextEditingController();
  final TextEditingController _maxCtrl = TextEditingController();
  bool _notifyActive = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill if there's an existing alert
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alert = ref.read(priceAlertProvider.notifier).getAlertFor(widget.item.id);
      if (alert != null) {
        if (alert.minPrice != null) _minCtrl.text = alert.minPrice.toString();
        if (alert.maxPrice != null) _maxCtrl.text = alert.maxPrice.toString();
        setState(() => _notifyActive = alert.notifyActive);
      }
    });
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _saveAlert() async {
    final minPrice = double.tryParse(_minCtrl.text);
    final maxPrice = double.tryParse(_maxCtrl.text);

    if (minPrice == null && maxPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least one target price.')),
      );
      return;
    }

    try {
      await ref.read(priceAlertProvider.notifier).saveAlert(
            item: widget.item,
            minPrice: minPrice,
            maxPrice: maxPrice,
            notifyActive: _notifyActive,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.item.itemEng} price alert saved!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save alert: \$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A), // Dark Grey/Black theme header
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Set Price Alert for ${widget.item.itemTamil} / ${widget.item.itemEng}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Current Range Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F5FE), // Light blue from design
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      "Today's Range ${widget.item.priceRange}",
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Input Fields
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          label: 'LOWER TARGET PRICE',
                          controller: _minCtrl,
                          hint: 'e.g., 120',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInputField(
                          label: 'UPPER TARGET PRICE',
                          controller: _maxCtrl,
                          hint: 'e.g., 250',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Toggle Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notify me if price crosses limits',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'You will receive push notification when price goes below lower or above upper target (checked daily from CMDA).',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: _notifyActive,
                        onChanged: (val) => setState(() => _notifyActive = val),
                        activeTrackColor: AppColors.primaryLight,
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Save Action
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _saveAlert,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFB300), // Amber/Orange
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Save Alert >>', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer text
                  Center(
                    child: Text(
                      'Alerts are saved in the cloud and checked daily.',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE0E0E0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Text('₹', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black54)),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
