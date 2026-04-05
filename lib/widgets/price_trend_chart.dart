import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/price_service.dart';

/// Displays a 7-day price trend chart with min + max price lines.
class PriceTrendChart extends StatelessWidget {
  final List<PricePoint> history;
  const PriceTrendChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Not enough data yet — check back tomorrow',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ),
      );
    }

    // Compute Y-axis bounds with 10% padding
    double dataMinY = double.infinity;
    double dataMaxY = double.negativeInfinity;
    for (final p in history) {
      if (p.minPrice < dataMinY) dataMinY = p.minPrice;
      if (p.maxPrice > dataMaxY) dataMaxY = p.maxPrice;
    }
    final yRange = dataMaxY - dataMinY;
    final padding = yRange > 0 ? yRange * 0.1 : 5.0;
    final double minY = (dataMinY - padding).floorToDouble().clamp(0.0, double.infinity).toDouble();
    final double maxY = (dataMaxY + padding).ceilToDouble();

    // Build spots
    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];
    for (var i = 0; i < history.length; i++) {
      minSpots.add(FlSpot(i.toDouble(), history[i].minPrice));
      maxSpots.add(FlSpot(i.toDouble(), history[i].maxPrice));
    }

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: minY,
          maxY: maxY,
          minX: 0,
          maxX: (history.length - 1).toDouble(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _computeYInterval(minY, maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= history.length) return const SizedBox.shrink();
                  // Show only first, last, and mid if <= 5 points; else first+last only
                  if (history.length > 5) {
                    if (i != 0 && i != history.length - 1) return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _dayAbbr(history[i].date),
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 46,
                interval: _computeYInterval(minY, maxY),
                getTitlesWidget: (value, meta) {
                  return Text(
                    '₹${value.toInt()}',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final i = spot.x.toInt();
                  if (i < 0 || i >= history.length) return null;
                  final p = history[i];
                  final isMin = spot.barIndex == 0;
                  return LineTooltipItem(
                    isMin
                        ? 'Min: ₹${p.minPrice.toInt()}  Max: ₹${p.maxPrice.toInt()}'
                        : '',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            // Min price line — dashed blue
            LineChartBarData(
              spots: minSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: const Color(0xFF42A5F5),
              barWidth: 2.5,
              dashArray: [6, 4],
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: const Color(0xFF42A5F5),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(show: false),
            ),
            // Max price line — solid amber
            LineChartBarData(
              spots: maxSpots,
              isCurved: true,
              curveSmoothness: 0.25,
              color: const Color(0xFFFFA726),
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                  radius: 3.5,
                  color: const Color(0xFFFFA726),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFFFFA726).withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  /// Returns a 3-letter day abbreviation.
  String _dayAbbr(DateTime dt) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dt.weekday - 1];
  }

  /// Computes a clean Y-axis interval.
  double _computeYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 10) return 2.0;
    if (range <= 30) return 5.0;
    if (range <= 100) return 10.0;
    if (range <= 300) return 25.0;
    return 50.0;
  }
}
