import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/services/patient_link_service.dart';
import 'package:flutter_application/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _illnessController = TextEditingController();
  final _caretakerNameController = TextEditingController();
  final _caretakerEmailController = TextEditingController();
  final _guardianNameController = TextEditingController();
  final _guardianEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _illnessController.dispose();
    _caretakerNameController.dispose();
    _caretakerEmailController.dispose();
    _guardianNameController.dispose();
    _guardianEmailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _nameController.text = prefs.getString('name') ?? '';
    _ageController.text = prefs.getString('age') ?? '';
    _illnessController.text = prefs.getString('illness') ?? '';
    _caretakerNameController.text = prefs.getString('caretakerName') ?? '';
    _caretakerEmailController.text = prefs.getString('caretakerPhone') ?? '';
    _guardianNameController.text = prefs.getString('guardianName') ?? '';
    _guardianEmailController.text = prefs.getString('guardianPhone') ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text.trim());
    await prefs.setString('age', _ageController.text.trim());
    await prefs.setString('illness', _illnessController.text.trim());
    await prefs.setString('caretakerName', _caretakerNameController.text.trim());
    await prefs.setString('caretakerEmail', _caretakerEmailController.text.trim());
    await prefs.setString('guardianName', _guardianNameController.text.trim());
    await prefs.setString('guardianEmail', _guardianEmailController.text.trim());

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await PatientLinkService.linkAccounts(
        patientUid: uid,
        caretakerEmail: _caretakerEmailController.text.trim(),
        guardianEmail: _guardianEmailController.text.trim(),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile saved successfully'),
        backgroundColor: AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim().isEmpty
        ? 'Your Profile'
        : _nameController.text.trim();
    final illness = _illnessController.text.trim().isEmpty
        ? 'No health details added'
        : _illnessController.text.trim();
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _buildHeader(name, illness, email),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildCard(
                  title: 'Personal Details',
                  icon: Icons.badge_outlined,
                  color: AppTheme.primary,
                  children: [
                    _field('Name', _nameController,
                        icon: Icons.person_outline_rounded,
                        hint: 'Patient name'),
                    _field('Age', _ageController,
                        icon: Icons.cake_outlined,
                        type: TextInputType.number,
                        hint: 'Your age'),
                    _field('Illness / Condition', _illnessController,
                        icon: Icons.health_and_safety_outlined,
                        hint: 'e.g. Diabetes, BP'),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCard(
                  title: 'Caretaker',
                  icon: Icons.support_agent_rounded,
                  color: AppTheme.secondary,
                  children: [
                    _field('Caretaker Name', _caretakerNameController,
                        icon: Icons.person_add_alt_1_outlined),
                    _field('Caretaker Email', _caretakerEmailController,
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress),
                  ],
                ),
                const SizedBox(height: 12),
                _buildCard(
                  title: 'Guardian',
                  icon: Icons.family_restroom_rounded,
                  color: AppTheme.tertiary,
                  children: [
                    _field('Guardian Name', _guardianNameController,
                        icon: Icons.person_outline_rounded),
                    _field('Guardian Email', _guardianEmailController,
                        icon: Icons.email_outlined,
                        type: TextInputType.emailAddress),
                  ],
                ),
                const SizedBox(height: 20),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.profileGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.quaternary.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _save,
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text(
                      'Save Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String name, String illness, String email) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.profileGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      illness,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
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
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    required IconData icon,
    TextInputType type = TextInputType.text,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primary, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppTheme.primary, width: 1.8),
          ),
          filled: true,
          fillColor: AppTheme.surfaceVariant,
        ),
      ),
    );
  }
}
