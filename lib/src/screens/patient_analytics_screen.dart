import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/theme/app_theme.dart';

class PatientAnalyticsScreen extends StatefulWidget {
  final String patientId;

  const PatientAnalyticsScreen({
    super.key,
    required this.patientId,
  });

  @override
  State<PatientAnalyticsScreen> createState() => _PatientAnalyticsScreenState();
}

class _PatientAnalyticsScreenState extends State<PatientAnalyticsScreen> {
  String selectedFilter = "Daily";

  Map<String, int> calculateStats(
    List<QueryDocumentSnapshot> docs,
  ) {
    int taken = 0;
    int skipped = 0;
    int missed = 0;
    int total = 0;

    final now = DateTime.now();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final doses = List<String>.from(
        data['doses'] ?? [],
      );

      final takenDates = Map<String, dynamic>.from(
        data['takenDates'] ?? {},
      );

      for (var entry in takenDates.entries) {
        final date = DateTime.parse(entry.key);

        bool include = false;

        // DAILY
        if (selectedFilter == "Daily") {
          include = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }

        // WEEKLY
        else if (selectedFilter == "Weekly") {
          include = now.difference(date).inDays <= 7;
        }

        // MONTHLY
        else {
          include = date.year == now.year && date.month == now.month;
        }

        if (!include) continue;

        final dayData = Map<String, dynamic>.from(
          entry.value,
        );

        for (var dose in doses) {
          total++;

          final status = dayData[dose] ?? 'pending';

          if (status == 'taken') {
            taken++;
          } else if (status == 'skipped') {
            skipped++;
          } else {
            missed++;
          }
        }
      }
    }

    return {
      "taken": taken,
      "skipped": skipped,
      "missed": missed,
      "total": total,
    };
  }

  Widget filterChip(String title) {
    final selected = selectedFilter == title;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedFilter = title;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(
                  alpha: 0.12,
                ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? AppTheme.primary : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.patientId)
            .snapshots(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;

          final patientName = userData['name'] ?? "Patient";

          final patientEmail = userData['email'] ?? "";

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(widget.patientId)
                .collection(
                  'medicine_schedule',
                )
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final meds = snapshot.data!.docs;

              final stats = calculateStats(
                meds,
              );

              final taken = stats['taken']!;

              final skipped = stats['skipped']!;

              final missed = stats['missed']!;

              final total = stats['total']!;

              final adherence = total == 0 ? 0.0 : (taken / total) * 100;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(
                      patientName,
                      patientEmail,
                      adherence,
                    ),
                  ),

                  // FILTERS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          filterChip(
                            "Daily",
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          filterChip(
                            "Weekly",
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          filterChip(
                            "Monthly",
                          ),
                        ],
                      ),
                    ),
                  ),

                  // CHART CARD
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            30,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 20,
                              offset: const Offset(
                                0,
                                8,
                              ),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.analytics_rounded,
                                  color: AppTheme.primary,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  "Adherence Report",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 30,
                            ),
                            SizedBox(
                              height: 230,
                              child: PieChart(
                                PieChartData(
                                  centerSpaceRadius: 52,
                                  sectionsSpace: 4,
                                  sections: [
                                    PieChartSectionData(
                                      value: taken.toDouble(),
                                      color: AppTheme.success,
                                      title: "Taken",
                                      radius: 72,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: skipped.toDouble(),
                                      color: AppTheme.warning,
                                      title: "Skipped",
                                      radius: 72,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    PieChartSectionData(
                                      value: missed.toDouble(),
                                      color: Colors.red,
                                      title: "Missed",
                                      radius: 72,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(
                              height: 22,
                            ),
                            Text(
                              "${adherence.toStringAsFixed(1)}%",
                              style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Text(
                              "$selectedFilter Adherence",
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 20),
                  ),

                  // STATS GRID
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.1,
                        children: [
                          statCard(
                            title: "Taken",
                            value: taken.toString(),
                            icon: Icons.check_circle_rounded,
                            color: AppTheme.success,
                          ),
                          statCard(
                            title: "Skipped",
                            value: skipped.toString(),
                            icon: Icons.skip_next_rounded,
                            color: AppTheme.warning,
                          ),
                          statCard(
                            title: "Missed",
                            value: missed.toString(),
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                          statCard(
                            title: "Total",
                            value: total.toString(),
                            icon: Icons.analytics_rounded,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),

                  // LOW STOCK ALERTS
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            28,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: 0.04,
                              ),
                              blurRadius: 18,
                              offset: const Offset(
                                0,
                                8,
                              ),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red,
                                ),
                                SizedBox(
                                  width: 10,
                                ),
                                Text(
                                  "Low Stock Alerts",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            ...meds.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;

                              final stock = data['stock'] ?? 0;

                              final threshold = data['lowStockThreshold'] ?? 3;

                              final isLow = stock <= threshold;

                              if (!isLow) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                margin: const EdgeInsets.only(
                                  bottom: 14,
                                ),
                                padding: const EdgeInsets.all(
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    20,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(
                                        12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          14,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.medication_rounded,
                                        color: Colors.red,
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 14,
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['name'] ?? "Medicine",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 4,
                                          ),
                                          Text(
                                            "$stock tablets left",
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 30),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    String name,
    String email,
    double adherence,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFDB2777),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            22,
            20,
            22,
            34,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: 0.18,
                        ),
                        borderRadius: BorderRadius.circular(
                          14,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      borderRadius: BorderRadius.circular(
                        16,
                      ),
                    ),
                    child: const Icon(
                      Icons.analytics_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 28,
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                email,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              const SizedBox(
                height: 22,
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: 0.14,
                  ),
                  borderRadius: BorderRadius.circular(
                    24,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Current Adherence",
                            style: TextStyle(
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            "${adherence.toStringAsFixed(1)}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          26,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: 0.10,
            ),
            blurRadius: 18,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(
            height: 16,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
