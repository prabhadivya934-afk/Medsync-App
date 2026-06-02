import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/src/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    this.patientId,
  });
  final String? patientId;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<FlSpot> actualSpots = [];
  List<FlSpot> predictedSpots = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = widget.patientId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .orderBy('time')
          .get();

      final Map<String, List<String>> dailyData = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final date = (data['time'] as Timestamp).toDate();
        final key = '${date.year}-${date.month}-${date.day}';

        dailyData.putIfAbsent(key, () => []);

        dailyData[key]!.add(
          data['status'],
        );
      }

      final List<double> values = [];
      final List<FlSpot> tempActual = [];
      int i = 0;

      dailyData.forEach((_, list) {
        final taken = list.where((v) => v == 'taken').length;
        final skipped = list.where((v) => v == 'skipped').length;

        final missed = list.where((v) => v == 'missed').length;
        final adherence = (taken + skipped + missed) == 0
            ? 0.0
            : (taken / (taken + skipped + missed)) * 100;
        values.add(adherence);
        tempActual.add(FlSpot(i.toDouble(), adherence));
        i++;
      });

      final List<FlSpot> tempPrediction = [];
      if (values.length >= 3) {
        final avg =
            values.sublist(values.length - 3).reduce((a, b) => a + b) / 3;
        final trend = values.last - values[values.length - 2];
        for (int j = 1; j <= 3; j++) {
          tempPrediction.add(FlSpot(
            (values.length - 1 + j).toDouble(),
            (avg + trend * j).clamp(0, 100),
          ));
        }
      }

      if (mounted) {
        setState(() {
          actualSpots = tempActual;
          predictedSpots = tempPrediction;
          isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = actualSpots.isNotEmpty ? actualSpots.last.y : 0.0;
    final predicted =
        predictedSpots.isNotEmpty ? predictedSpots.last.y : current;
    final trend = predicted - current;
    final trendUp = trend >= 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(current, predicted, trend, trendUp),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsRow(current, predicted, trend, trendUp),
                        const SizedBox(height: 20),
                        _buildChartCard(),
                        const SizedBox(height: 20),
                        _buildInsightCard(current, trendUp),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      double current, double predicted, double trend, bool trendUp) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 24),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.analytics_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'ML-powered adherence prediction',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      double current, double predicted, double trend, bool trendUp) {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: 'Current Rate',
            value: '${current.toStringAsFixed(1)}%',
            icon: Icons.today_rounded,
            color: const Color(0xFF7C3AED),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            label: 'Predicted',
            value: '${predicted.toStringAsFixed(1)}%',
            icon: trendUp
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            color: trendUp ? AppTheme.success : AppTheme.warning,
            badge: trendUp
                ? '+${trend.toStringAsFixed(1)}%'
                : '${trend.toStringAsFixed(1)}%',
            badgePositive: trendUp,
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
    bool badgePositive = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgePositive ? AppTheme.success : AppTheme.warning)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color:
                          badgePositive ? AppTheme.success : AppTheme.warning,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Adherence Trend',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              _legendDot(AppTheme.primary, 'Actual'),
              const SizedBox(width: 12),
              _legendDot(AppTheme.quaternary, 'Forecast', dashed: true),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: actualSpots.isEmpty ? _buildEmpty() : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label, {bool dashed = false}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart_outlined,
                size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          const Text('No adherence data yet',
              style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 4),
          const Text(
            'Start tracking medicines to see predictions',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        backgroundColor: Colors.transparent,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF3F4F6), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}%',
                style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                final isActual = idx < actualSpots.length;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    isActual
                        ? 'D${idx + 1}'
                        : 'P${idx - actualSpots.length + 2}',
                    style: TextStyle(
                      color: isActual ? AppTheme.textHint : AppTheme.quaternary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: actualSpots,
            isCurved: true,
            color: AppTheme.primary,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: AppTheme.primary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.18),
                  AppTheme.primary.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          if (predictedSpots.isNotEmpty)
            LineChartBarData(
              spots: [actualSpots.last, ...predictedSpots],
              isCurved: true,
              color: AppTheme.quaternary,
              barWidth: 2.5,
              dashArray: [6, 4],
              dotData: FlDotData(
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 3.5,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: AppTheme.quaternary,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.quaternary.withValues(alpha: 0.1),
                    AppTheme.quaternary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(double current, bool trendUp) {
    final String message;
    final Color color;
    final IconData icon;

    if (actualSpots.isEmpty) {
      message =
          'No data yet. Mark medicines as taken or missed to build your adherence history.';
      color = AppTheme.info;
      icon = Icons.info_outline_rounded;
    } else if (current >= 80) {
      message =
          'Excellent adherence! Keep it up — consistent medication use leads to better health outcomes.';
      color = AppTheme.success;
      icon = Icons.verified_rounded;
    } else if (current >= 50) {
      message =
          'Good progress. Try to mark all doses daily for a more accurate prediction.';
      color = AppTheme.warning;
      icon = Icons.trending_up_rounded;
    } else {
      message =
          'Low adherence detected. Set reminders and use the notification feature to stay on track.';
      color = AppTheme.error;
      icon = Icons.warning_amber_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trendUp ? 'Improving Trend' : 'Needs Attention',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
