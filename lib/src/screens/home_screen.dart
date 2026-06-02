import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/screens/add_location_screen.dart';
import 'package:flutter_application/src/screens/add_medicine_screen.dart';
import 'package:flutter_application/src/screens/analytics_screen.dart';
import 'package:flutter_application/src/screens/patient_qr_screen.dart';
import 'package:flutter_application/src/screens/profile_screen.dart';
import 'package:flutter_application/src/screens/settings_screen.dart';
import 'package:flutter_application/src/screens/tracking_screen.dart';
import 'package:flutter_application/src/services/location_monitor_service.dart';
import 'package:flutter_application/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  bool get wantKeepAlive => true;
  int _selectedIndex = 0;
  List<Widget> get _screens => [
        _buildHomeContent(),
        const TrackingScreen(),
        const ProfileScreen(),
        const SettingsScreen(),
      ];
  List<Map<String, dynamic>> _medicines = [];

  String _userName = 'User';
  String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _listenToMedicines();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) LocationMonitorService.startMonitoring(user.uid);
  }

  void _listenToMedicines() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .snapshots()
        .listen((snapshot) {
      final now = DateTime.now();

      final data = snapshot.docs
          .map((doc) {
            final d = doc.data();

            // =========================
            // TIMES
            // =========================

            List<TimeOfDay> times = [];

            if (d['times'] != null) {
              times = (d['times'] as List).map((t) {
                return TimeOfDay(
                  hour: (t['hour'] as num).toInt(),
                  minute: (t['minute'] as num).toInt(),
                );
              }).toList();
            }

            // =========================
            // TODAY STATUS
            // =========================

            final key = _todayKey();

            Map<String, dynamic> takenDates = {};

            if (d['takenDates'] != null) {
              takenDates = Map<String, dynamic>.from(
                d['takenDates'],
              );
            }

            return {
              ...d,
              'id': doc.id,
              'times': times,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      // =========================
      // SORT BY TIME
      // =========================

      data.sort((a, b) {
        final aT = (a['times'] as List?)?.firstOrNull;

        final bT = (b['times'] as List?)?.firstOrNull;

        if (aT == null || bT == null) {
          return 0;
        }

        return ((aT as TimeOfDay).hour * 60 + aT.minute).compareTo(
          ((bT as TimeOfDay).hour * 60 + bT.minute),
        );
      });

      if (mounted) {
        setState(() {
          _medicines = data;
        });
      }
    });
  }

  Future<void> _deleteExpired(String docId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicine_schedule')
        .doc(docId)
        .delete();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();

    final savedName = prefs.getString('name');

    setState(() {
      _userName = (savedName != null && savedName.trim().isNotEmpty)
          ? savedName
          : 'Guest User';
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour == 0
        ? 12
        : t.hour > 12
            ? t.hour - 12
            : t.hour;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: _screens[_selectedIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddMedicineScreen(),
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 6,
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_rounded,
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.analytics_rounded,
            ),
            label: 'Tracking',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_rounded,
            ),
            label: 'Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings_rounded,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeContent() {
    return Column(
      children: [
        _buildHeader(context),
        Expanded(
          child: _medicines.isEmpty ? _buildEmpty() : _buildList(),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.homeGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_greeting,',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formattedDate,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _headerAction(
                    Icons.qr_code_rounded,
                    'Link',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PatientQRScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      _headerAction(
                        Icons.place_outlined,
                        'Location',
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AddLocationScreen())),
                      ),
                      const SizedBox(width: 8),
                      _headerAction(
                        Icons.analytics_outlined,
                        'Analytics',
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AnalyticsScreen())),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.medication_rounded,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _medicines.isEmpty
                          ? 'No medicines scheduled'
                          : '${_medicines.length} medicine${_medicines.length != 1 ? 's' : ''} scheduled today',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_medicines.where((m) => (m['medicineType'] ?? 'regular') == 'regular').length} regular',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
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

  Widget _headerAction(IconData icon, String tooltip, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medication_outlined,
                size: 64,
                color: AppTheme.primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Medicines Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button below to add your\nfirst medicine schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            children: [
              const Text(
                "Today's Medicines",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_medicines.length}',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            itemCount: _medicines.length,
            itemBuilder: (ctx, i) => _buildCard(_medicines[i], i),
          ),
        ),
      ],
    );
  }

  Future<void> _editMedicine(Map<String, dynamic> med) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicineScreen(
          medicineId: med['id'] as String,
          initialData: med,
        ),
      ),
    );
  }

  Future<void> _deleteMedicine(String docId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Medicine',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "$name" from your schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppTheme.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('medicine_schedule')
        .doc(docId)
        .delete();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$name" deleted'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  Widget _buildCard(Map<String, dynamic> med, int index) {
    const palette = [
      // Ocean Teal
      [
        Color(0xFF118AB2),
        Color(0xFF06D6A0),
        Color(0xFFEBFAF7),
        Color(0xFF0A4F66),
        Color(0xFF93E9D2),
        Color(0xFFEBFAF7),
        Color(0xFF0A4F66),
        Color(0xFF118AB2),
      ],

      // Deep Rose
      [
        Color(0xFFD6456B),
        Color(0xFFE76F8A),
        Color(0xFFFFEEF3),
        Color(0xFF8F1D3C),
        Color(0xFFF4B3C5),
        Color(0xFFFFEEF3),
        Color(0xFF8F1D3C),
        Color(0xFFD6456B),
      ],

      // Golden Amber
      [
        Color(0xFFE9C46A),
        Color(0xFFF4A261),
        Color(0xFFFFF7E8),
        Color(0xFF8C5A00),
        Color(0xFFF5D48B),
        Color(0xFFFFF7E8),
        Color(0xFF8C5A00),
        Color(0xFFE9C46A),
      ],
      // Olive Lime
      [
        Color(0xFF6A994E),
        Color(0xFFA7C957),
        Color(0xFFF5FAEE),
        Color(0xFF386641),
        Color(0xFFD4E7B0),
        Color(0xFFF5FAEE),
        Color(0xFF386641),
        Color(0xFF6A994E),
      ],
      // Burnt Orange
      [
        Color(0xFFE76F51),
        Color(0xFFF4A261),
        Color(0xFFFFF1EB),
        Color(0xFF9F3D24),
        Color(0xFFF7B7A3),
        Color(0xFFFFF1EB),
        Color(0xFF9F3D24),
        Color(0xFFE76F51),
      ],
      // Crimson Red
      [
        Color(0xFFC1121F),
        Color(0xFFE5383B),
        Color(0xFFFFF0F1),
        Color(0xFF780000),
        Color(0xFFF29CA3),
        Color(0xFFFFF0F1),
        Color(0xFF780000),
        Color(0xFFC1121F),
      ],
    ];

    final p = palette[index % palette.length];
    final isTemporary = med['medicineType'] != 'regular';
    final times = (med['times'] as List?)?.cast<TimeOfDay>() ?? [];
    final name = med['name'] ?? 'Medicine';
    final dosage = med['dosage'] ?? '';
    final docId = med['id'] as String;

    String medicineImage(String? type) {
      switch ((type ?? '').toLowerCase()) {
        case 'tablet':
          return 'assets/tablet.png';

        case 'capsule':
          return 'assets/capsule.png';

        case 'syrup':
          return 'assets/syrup.png';

        case 'drops':
          return 'assets/drops.png';

        case 'ointment':
          return 'assets/ointment.png';

        case 'inhaler':
          return 'assets/inhaler.png';

        case 'injection':
          return 'assets/injection.png';

        case 'powder':
          return 'assets/powder.png';

        default:
          return 'assets/medicine.png';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: (p[7]).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: Key(docId),
          background: Container(
            color: const Color(0xFF185FA5),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Row(children: [
              Icon(Icons.edit_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Edit',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ]),
          ),
          secondaryBackground: Container(
            color: const Color(0xFFA32D2D),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child:
                const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('Delete',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
              SizedBox(width: 8),
              Icon(Icons.delete_rounded, color: Colors.white, size: 22),
            ]),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              _editMedicine(med);
              return false;
            }
            if (direction == DismissDirection.endToStart) {
              await _deleteMedicine(docId, name);
              return false;
            }
            return false;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Vibrant gradient header ──
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [p[0], p[1]],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Image.asset(
                          medicineImage(med['type']),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (dosage.isNotEmpty)
                            Text(
                              'Dose: $dosage',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isTemporary
                                ? Icons.hourglass_bottom_rounded
                                : Icons.repeat_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isTemporary ? 'Temp' : 'Daily',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Time chips ──
              if (times.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: times.map((t) {
                      final isMorning = t.hour < 12;
                      final isEvening = t.hour >= 18;
                      final timeIcon = isMorning
                          ? Icons.wb_sunny_rounded
                          : isEvening
                              ? Icons.nights_stay_rounded
                              : Icons.wb_twilight_rounded;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: p[2],
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: (p[4]).withValues(alpha: 0.8)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(timeIcon, size: 12, color: p[3]),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(t),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: p[3]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Divider ──
              Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.black.withValues(alpha: 0.06)),

              // ── Action bar: Taken | Skip | QR ──
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: _actionBtn(
                        label: 'Taken',
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF0F6E56),
                        onTap: () => _onTaken(med),
                      ),
                    ),
                    VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: Colors.black.withValues(alpha: 0.06)),
                    Expanded(
                      child: _actionBtn(
                        label: 'Skip',
                        icon: Icons.cancel_outlined,
                        color: const Color(0xFFA32D2D),
                        onTap: () => _onSkip(med),
                      ),
                    ),
                    VerticalDivider(
                        width: 1,
                        thickness: 0.5,
                        color: Colors.black.withValues(alpha: 0.06)),
                    // QR button
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsGeometry.all(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTaken(Map<String, dynamic> med) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = _todayKey();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .doc(med['id'])
        .set({
      'takenDates': {
        key: {
          'status': 'taken',
        }
      },
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${med["name"]} marked as taken'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _onSkip(Map<String, dynamic> med) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final key = _todayKey();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('medicine_schedule')
        .doc(med['id'])
        .set({
      'takenDates': {
        key: {
          'status': 'skipped',
        }
      },
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${med["name"]} marked as skipped'),
        backgroundColor: AppTheme.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
