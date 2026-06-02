import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/src/screens/analytics_screen.dart';
import 'package:flutter_application/src/screens/settings_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

class CaretakerDashboard extends StatefulWidget {
  const CaretakerDashboard({super.key});

  @override
  State<CaretakerDashboard> createState() => _CaretakerDashboardState();
}

class _CaretakerDashboardState extends State<CaretakerDashboard> {
  final String caretakerId = FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot> getPatients() {
    return FirebaseFirestore.instance
        .collection("users")
        .doc(caretakerId)
        .collection("linked_patients")
        .snapshots();
  }

  Stream<QuerySnapshot> _linkedPatientsStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('linked_patients')
        .snapshots();
  }

  Stream<QuerySnapshot> getAlerts() {
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('status', isEqualTo: 'unread')
        .snapshots();
  }

  Future<void> linkPatient(
    String patientId,
  ) async {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final currentUid = currentUser.uid;

    // =====================
    // GET CURRENT USER ROLE
    // =====================

    final currentUserDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUid)
        .get();

    final role = currentUserDoc.data()?['role'];

    // =====================
    // VERIFY PATIENT EXISTS
    // =====================

    final patientDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(patientId)
        .get();

    if (!patientDoc.exists) {
      throw Exception(
        "Patient not found",
      );
    }

    // =====================
    // LINK CARETAKER
    // =====================

    if (role == 'caretaker') {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUid)
          .collection("linked_patients")
          .doc(patientId)
          .set({
        "linkedAt": Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .collection("linked_caretakers")
          .doc(currentUid)
          .set({
        "uid": currentUid,
        "email": currentUser.email,
        "role": "caretaker",
        "linkedAt": Timestamp.now(),
      });
    }

    // =====================
    // LINK GUARDIAN
    // =====================

    else if (role == 'guardian') {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(currentUid)
          .collection("linked_patients")
          .doc(patientId)
          .set({
        "linkedAt": Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .collection("linked_guardians")
          .doc(currentUid)
          .set({
        "uid": currentUid,
        "email": currentUser.email,
        "role": "guardian",
        "linkedAt": Timestamp.now(),
      });
    }
  }

  Future<void> linkPatientByEmail(
    String email,
  ) async {
    try {
      final result = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'email',
            isEqualTo: email.trim(),
          )
          .where(
            'role',
            isEqualTo: 'patient',
          )
          .get();

      if (result.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "No patient found",
            ),
            backgroundColor: Colors.red,
          ),
        );

        return;
      }

      final patientId = result.docs.first.id;

      await FirebaseFirestore.instance
          .collection("users")
          .doc(caretakerId)
          .collection("linked_patients")
          .doc(patientId)
          .set({
        "linkedAt": Timestamp.now(),
      });

      await FirebaseFirestore.instance
          .collection("users")
          .doc(patientId)
          .collection("linked_caretakers")
          .doc(caretakerId)
          .set({
        "uid": caretakerId,
        "email": FirebaseAuth.instance.currentUser?.email,
        "role": "caretaker",
        "linkedAt": Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Patient linked successfully",
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint(
        "Email link error: $e",
      );
    }
  }

  void openLinkOptions() {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Link Patient",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // QR Button
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  openScanner();
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00A86B),
                        Color(0xFF43C58C),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Scan Patient QR",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: "Enter patient email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: const Color(0xFFF4F6FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    linkPatientByEmail(controller.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A86B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Link with Email",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void openMedicineStores(String medicineName) {
    final encoded = Uri.encodeComponent(medicineName);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  "Buy Medicine",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _storeTile(
                title: "Tata 1mg",
                subtitle: "Order from Tata 1mg",
                icon: Icons.local_pharmacy,
                color: Colors.green,
                onTap: () async {
                  final url = 'https://www.1mg.com/search/all?name=$encoded';

                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _storeTile(
                title: "Apollo Pharmacy",
                subtitle: "Search in Apollo",
                icon: Icons.medical_services,
                color: Colors.orange,
                onTap: () async {
                  final url =
                      'https://www.apollopharmacy.in/search-medicines/$encoded';

                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _storeTile(
                title: "PharmEasy",
                subtitle: "Buy from PharmEasy",
                icon: Icons.shopping_bag,
                color: Colors.purple,
                onTap: () async {
                  final url = 'https://pharmeasy.in/search/all?name=$encoded';

                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              _storeTile(
                title: "NetMeds",
                subtitle: "Search on NetMeds",
                icon: Icons.health_and_safety,
                color: Colors.red,
                onTap: () async {
                  final url =
                      'https://www.netmeds.com/catalogsearch/result?q=$encoded';

                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _storeTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QRScannerScreen(onScan: linkPatient)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F8F67),
                    Color(0xFF1EB980),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(34),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Good Day,",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  "Caretaker",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: openLinkOptions,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(
                                Icons.settings,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.people_alt_rounded, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Manage linked patients and medicine schedules easily.",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
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
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _statCard(
                      "Patients",
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      "Alerts",
                      Icons.warning_rounded,
                      Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── Alerts Section ──
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: getAlerts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }

                final alerts = snapshot.data!.docs;

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade700,
                        Colors.red.shade500,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              "Active Alerts",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${alerts.length}",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                          color: Colors.white24, height: 1, thickness: 1),
                      ...alerts.map((doc) => ListTile(
                            leading: const Icon(Icons.warning_rounded,
                                color: Colors.white70),
                            title: Text(
                              doc['message'] ?? "Alert",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                            dense: true,
                          )),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Patients Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Text(
                    "Linked Patients",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1A1F36),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),

          // ── Patients List ──
          StreamBuilder<QuerySnapshot>(
            stream: getPatients(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
                  ),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: _EmptyPatientsState(),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final patient = snapshot.data!.docs[index];
                    return _patientCard(patient);
                  },
                  childCount: snapshot.data!.docs.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _patientCard(
    QueryDocumentSnapshot patient,
  ) {
    final patientId = patient.id;

    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance.collection("users").doc(patientId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        final name = data['name'] ?? "Patient";

        final email = data['email'] ?? "No email";

        final initial = name[0].toUpperCase();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticsScreen(
                  patientId: patientId,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.05,
                  ),
                  blurRadius: 12,
                  offset: const Offset(
                    0,
                    4,
                  ),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  child: Text(initial),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                      ),
                      Text(
                        email,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _statCard(
  String title,
  IconData icon,
  Color color,
) {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _EmptyPatientsState extends StatelessWidget {
  const _EmptyPatientsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.people_outline, size: 64, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text(
            "No Patients Linked",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1F36),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan a patient's QR code to link\nthem to your account.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── QR Scanner Screen ──
class QRScannerScreen extends StatefulWidget {
  final Function(String) onScan;

  const QRScannerScreen({super.key, required this.onScan});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  bool scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan Patient QR"),
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (scanned) return;
              final value = capture.barcodes.first.rawValue;
              if (value != null) {
                scanned = true;
                widget.onScan(value);
                Navigator.pop(context);
              }
            },
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 2.5),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Align the patient's QR code within the frame",
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
