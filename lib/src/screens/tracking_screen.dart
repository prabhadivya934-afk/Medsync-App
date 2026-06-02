import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/theme/app_theme.dart';

import '../services/alert_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({
    super.key,
    this.patientId,
  });
  final String? patientId;

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _nameController = TextEditingController();
  final _stockController = TextEditingController();
  final _dosageController = TextEditingController();
  final _thresholdController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _stockController.dispose();
    _dosageController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  String _todayKey() {
    final d = DateTime.now();

    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String getCurrentDose() {
    final now = DateTime.now();

    final minutes = now.hour * 60 + now.minute;

    // MORNING
    if (minutes >= 450 && minutes < 720) {
      return 'morning';
    }

    // AFTERNOON
    if (minutes >= 810 && minutes < 1020) {
      return 'afternoon';
    }

    // NIGHT
    return 'night';
  }

  String getCurrentDoseStatus(
    Map<String, dynamic> data,
  ) {
    final today = DateTime.now().toIso8601String().split('T').first;

    final currentDose = getCurrentDose();

    final takenDates = data['takenDates'] ?? {};

    final todayData = takenDates[today] ?? {};

    return todayData[currentDose] ?? 'pending';
  }

  Map<String, int> calculateDoseStats(
    List<QueryDocumentSnapshot> docs,
  ) {
    int taken = 0;
    int skipped = 0;
    int missed = 0;
    int total = 0;
    int pending = 0;

    final today = DateTime.now().toIso8601String().split('T').first;

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      total++;

      final doses = List<String>.from(
        data['doses'] ?? ['morning'],
      );

      final takenDates = data['takenDates'] ?? {};

      final todayData = takenDates[today] ?? {};

      for (var dose in doses) {
        total++;
        final status = todayData[dose] ?? 'pending';

        if (status == 'taken') {
          taken++;
        } else if (status == 'skipped') {
          skipped++;
        } else if (status == 'missed') {
          missed++;
        } else if (status == 'pending') {
          pending++;
        }
      }
    }

    return {
      'taken': taken,
      'skipped': skipped,
      'missed': missed,
      'pending': pending,
      'total': total,
    };
  }

  Future<void> _markTaken(
    String docId,
    String name,
    int? stock,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final key = _todayKey();

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId ?? user.uid)
        .collection('medicine_schedule')
        .doc(docId);

    await ref.set({
      'takenDates': {
        key: {
          getCurrentDose(): 'taken',
        }
      },
      if (stock != null && stock > 0) 'stock': stock - 1,
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId ?? user.uid)
        .collection('history')
        .add({
      'name': name,
      'status': 'taken',
      'time': Timestamp.now(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          stock == null
              ? '$name marked as taken'
              : stock > 0
                  ? '$name marked as taken. Stock: ${stock - 1} left'
                  : '$name marked as taken. Stock is empty',
        ),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  Future<void> _markSkipped(
    String docId,
    String name,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final key = _todayKey();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId ?? user.uid)
        .collection('medicine_schedule')
        .doc(docId)
        .set({
      'takenDates': {
        key: {
          getCurrentDose(): 'skipped',
        }
      },
    }, SetOptions(merge: true));

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId ?? user.uid)
        .collection('history')
        .add({
      'name': name,
      'status': 'skipped',
      'time': Timestamp.now(),
    });

    await AlertService.sendMedicineAlert(
      patientId: widget.patientId ?? user.uid,
      medicineName: name,
      type: 'skipped',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name marked as skipped'),
        backgroundColor: AppTheme.warning,
      ),
    );
  }

  Future<void> _delete(String docId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.patientId ?? user.uid)
        .collection('medicine_schedule')
        .doc(docId)
        .delete();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Medicine deleted'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _showStockForm({
    String? docId,
    Map<String, dynamic>? existing,
  }) {
    if (existing != null) {
      _nameController.text = existing['name'] ?? '';
      _stockController.text = (existing['stock'] ?? 0).toString();
      _dosageController.text = existing['dosage'] ?? '';
      _thresholdController.text =
          (existing['lowStockThreshold'] ?? 5).toString();
    } else {
      _nameController.clear();
      _stockController.clear();
      _dosageController.clear();
      _thresholdController.text = '5';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                docId != null ? 'Edit Medicine Stock' : 'Add Medicine Stock',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),
              _formField(
                controller: _nameController,
                label: 'Medicine Name',
                icon: Icons.medication_rounded,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 12),
              _formField(
                controller: _dosageController,
                label: 'Dosage (e.g. 500mg)',
                icon: Icons.monitor_weight_rounded,
                color: AppTheme.secondary,
              ),
              const SizedBox(height: 12),
              _formField(
                controller: _stockController,
                label: 'Stock Count',
                icon: Icons.inventory_2_rounded,
                color: AppTheme.tertiary,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              _formField(
                controller: _thresholdController,
                label: 'Low Stock Threshold',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.warning,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;

                    if (user == null) return;

                    final stockData = {
                      'name': _nameController.text.trim(),
                      'dosage': _dosageController.text.trim(),
                      'stock': int.tryParse(_stockController.text.trim()) ?? 0,
                      'lowStockThreshold':
                          int.tryParse(_thresholdController.text.trim()) ?? 5,
                      'updatedAt': Timestamp.now(),
                    };

                    final col = FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.patientId ?? user.uid)
                        .collection('medicine_schedule');

                    if (docId != null) {
                      await col.doc(docId).set(
                            stockData,
                            SetOptions(merge: true),
                          );
                    } else {
                      await col.add({
                        ...stockData,
                        'takenDates': {},
                        'createdAt': Timestamp.now(),
                        'medicineType': 'regular',
                      });
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    docId != null ? 'Update Stock' : 'Save Stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = widget.patientId ?? user?.uid;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('medicine_schedule')
            .where(
              'medicineType',
              isEqualTo: 'regular',
            )
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final meds = snapshot.data!.docs;
          for (final med in meds) {
            final data = med.data() as Map<String, dynamic>;

            final doses = List<String>.from(
              data['doses'] ?? ['morning'],
            );

            for (final dose in doses) {
              DateTime reminderTime;

              if (dose == 'morning') {
                reminderTime = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  8,
                  0,
                );
              } else if (dose == 'afternoon') {
                reminderTime = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  14,
                  0,
                );
              } else {
                reminderTime = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                  20,
                  0,
                );
              }

              AlertService.checkMissedDose(
                patientId: widget.patientId ?? user.uid,
                medicineId: med.id,
                medicineName: data['name'] ?? "Medicine",
                dose: dose,
                reminderTime: reminderTime,
              );
            }
          }
          final stats = calculateDoseStats(meds);

          final taken = stats['taken']!;

          final skipped = stats['skipped']!;

          final missed = stats['missed']!;

          final total = stats['total']!;
          final pending = stats['pending']!;

          final percent = total == 0 ? 0.0 : taken / total;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                  child: _buildHeader(
                percent,
                taken,
                skipped,
                missed,
                pending,
                total,
              )),
              meds.isEmpty
                  ? const SliverToBoxAdapter(
                      child: _EmptyState(),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          final doc = meds[i];

                          final raw = doc.data();

                          if (raw == null) {
                            return const SizedBox.shrink();
                          }

                          final data = Map<String, dynamic>.from(
                            raw as Map,
                          );
                          return _medicineCard(
                            doc.id,
                            data,
                            i,
                          );
                        },
                        childCount: meds.length,
                      ),
                    ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 30),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    double percent,
    int taken,
    int skipped,
    int missed,
    int pending,
    int total,
  ) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.homeGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Medicine Tracking",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Track your medicine adherence",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: SizedBox(
                  height: 220,
                  width: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sectionsSpace: 5,
                          centerSpaceRadius: 72,
                          sections: [
                            if (taken > 0)
                              PieChartSectionData(
                                value: taken.toDouble(),
                                color: const Color(0xFF34D399),
                                radius: 22,
                                title: '',
                              ),
                            if (skipped > 0)
                              PieChartSectionData(
                                value: skipped.toDouble(),
                                color: const Color(0xFFFBBF24),
                                radius: 22,
                                title: '',
                              ),
                            if (missed > 0)
                              PieChartSectionData(
                                value: missed.toDouble(),
                                color: const Color(0xFFF87171),
                                radius: 22,
                                title: '',
                              ),
                            if (pending > 0)
                              PieChartSectionData(
                                value: pending.toDouble(),
                                color: const Color(
                                  0xFF60A5FA,
                                ),
                                radius: 22,
                                title: '',
                              ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${(percent * 100).toInt()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Adherence",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      "Total",
                      total.toString(),
                      const Color(0xFF60A5FA),
                      Icons.medication_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      "Taken",
                      taken.toString(),
                      const Color(0xFF34D399),
                      Icons.check_circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      "Skipped",
                      skipped.toString(),
                      const Color(0xFFFBBF24),
                      Icons.skip_next_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      "Missed",
                      missed.toString(),
                      const Color(0xFFF87171),
                      Icons.warning_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      "Pending",
                      pending.toString(),
                      const Color(
                        0xFF60A5FA,
                      ),
                      Icons.access_time_rounded,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(
    Color color,
    String label,
    int value,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: $value',
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _medicineCard(
    String docId,
    Map<String, dynamic> data,
    int index,
  ) {
    final name = data['name'] ?? 'No Name';

    final dosage = data['dosage'] ?? '';

    final stock = data['stock'];

    final takenMap = Map<String, dynamic>.from(
      data['takenDates'] ?? {},
    );

    final status = getCurrentDoseStatus(data);

    final taken = status == 'taken';

    final skipped = status == 'skipped';

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppTheme.homeGradient,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dosage.isEmpty ? "No dosage" : dosage,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text("Edit"),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text("Delete"),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _showStockForm(
                      docId: docId,
                      existing: data,
                    );
                  }

                  if (value == 'delete') {
                    _delete(docId);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Available Stock",
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${stock ?? 0}",
                        style: TextStyle(
                          color: (stock ?? 0) <= 3
                              ? AppTheme.error
                              : AppTheme.success,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (stock ?? 0) <= 3
                        ? AppTheme.error.withValues(alpha: 0.12)
                        : AppTheme.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    (stock ?? 0) <= 3 ? "LOW STOCK" : "IN STOCK",
                    style: TextStyle(
                      color:
                          (stock ?? 0) <= 3 ? AppTheme.error : AppTheme.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!taken && !skipped)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markTaken(
                      docId,
                      name,
                      stock,
                    ),
                    icon: const Icon(
                      Icons.check_rounded,
                    ),
                    label: const Text(
                      "Taken",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markSkipped(
                      docId,
                      name,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                    ),
                    label: const Text(
                      "Skip",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: taken
                    ? AppTheme.success.withValues(alpha: 0.12)
                    : AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                taken ? "✓ Marked as Taken" : "⚠ Marked as Skipped",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: taken ? AppTheme.success : AppTheme.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              gradient: AppTheme.homeGradient,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Regular Medicines',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add regular medicines to track\nstock and adherence',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
