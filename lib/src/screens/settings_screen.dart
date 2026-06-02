import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application/src/screens/login_screen.dart';
import 'package:flutter_application/src/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_reminder_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _voiceEnabled = false;
  bool _notificationsEnabled = true;
  bool _locationRemindersEnabled = false;
  bool _hasHomeLocation = false;
  String userName = "";
  String userEmail = "";
  String userRole = "";

  @override
  void initState() {
    super.initState();
    _loadSettings();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();

    if (data == null) return;

    setState(() {
      userName = data['name'] ?? '';

      userEmail = data['email'] ?? '';

      userRole = data['role'] ?? 'patient';
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _voiceEnabled = prefs.getBool('voice_enabled') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _locationRemindersEnabled =
          prefs.getBool('location_reminders_enabled') ?? false;
      _hasHomeLocation = prefs.getDouble('home_latitude') != null &&
          prefs.getDouble('home_longitude') != null;
      userName = prefs.getString('name') ?? 'User';
      userEmail = user?.email ?? '';
    });
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Logout', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileCard(),
                const SizedBox(height: 20),
                _buildSectionLabel('Preferences'),
                const SizedBox(height: 10),
                _buildPreferencesCard(),
                const SizedBox(height: 20),
                _buildSectionLabel('About'),
                const SizedBox(height: 10),
                _buildAboutCard(),
                const SizedBox(height: 20),
                _buildLogoutCard(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.settingsGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.settings_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Manage your preferences',
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

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.tertiary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppTheme.settingsGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child:
                const Icon(Icons.person_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName.isEmpty ? 'User' : userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userEmail.isEmpty ? 'No email' : userEmail,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppTheme.tertiary.withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userRole.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.tertiary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return _sectionCard(
      title: 'Preferences',
      child: Column(
        children: [
          // =========================
          // PATIENT ONLY SETTINGS
          // =========================

          if (userRole == 'patient') ...[
            _switchTile(
              icon: Icons.mic_rounded,
              iconColor: AppTheme.primary,
              title: 'Voice Assistance',
              subtitle: 'Enable voice assistant',
              value: _voiceEnabled,
              activeThumbColor: AppTheme.primary,
              onChanged: (v) async {
                setState(() {
                  _voiceEnabled = v;
                });

                final prefs = await SharedPreferences.getInstance();

                await prefs.setBool(
                  'voice_enabled',
                  v,
                );
              },
            ),
            _divider(),
            _switchTile(
              icon: Icons.notifications_active_rounded,
              iconColor: AppTheme.secondary,
              title: 'Notification Setting',
              subtitle: 'Medicine reminder alerts',
              value: _notificationsEnabled,
              activeThumbColor: AppTheme.secondary,
              onChanged: (v) async {
                setState(() {
                  _notificationsEnabled = v;
                });

                final prefs = await SharedPreferences.getInstance();

                await prefs.setBool(
                  'notifications_enabled',
                  v,
                );
              },
            ),
            _divider(),
            _switchTile(
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.warning,
              title: 'Location Reminder',
              subtitle: 'Enable location reminders',
              value: _locationRemindersEnabled,
              activeThumbColor: AppTheme.warning,
              onChanged: (v) async {
                setState(() {
                  _locationRemindersEnabled = v;
                });

                final prefs = await SharedPreferences.getInstance();

                await prefs.setBool(
                  'location_reminder',
                  v,
                );
              },
            ),
            _divider(),
            _listTile(
              icon: Icons.save_rounded,
              iconColor: AppTheme.success,
              title: 'Save Location',
              subtitle: 'Save current reminder location',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Location Saved',
                    ),
                  ),
                );
              },
            ),
          ],

          // =========================
          // CARETAKER/GUARDIAN
          // =========================

          if (userRole != 'patient') ...[
            _switchTile(
              icon: Icons.notifications_active_rounded,
              iconColor: AppTheme.secondary,
              title: 'Notification Setting',
              subtitle: 'Enable notifications',
              value: _notificationsEnabled,
              activeThumbColor: AppTheme.secondary,
              onChanged: (v) async {
                setState(() {
                  _notificationsEnabled = v;
                });

                final prefs = await SharedPreferences.getInstance();

                await prefs.setBool(
                  'notifications_enabled',
                  v,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard() {
    return _sectionCard(
      title: 'About',
      child: Column(
        children: [
          _listTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppTheme.primary,
            title: 'App Version',
            subtitle: 'Version 1.0.0',
          ),
          _divider(),
          _listTile(
            icon: Icons.health_and_safety_rounded,
            iconColor: AppTheme.secondary,
            title: 'MedSync Manager',
            subtitle: 'Healthcare management system',
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLogoutCard() {
    return GestureDetector(
      onTap: _logout,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.error.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  color: AppTheme.error, size: 20),
            ),
            const SizedBox(width: 14),
            const Text(
              'Logout',
              style: TextStyle(
                color: AppTheme.error,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.error, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required Color activeThumbColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SwitchListTile(
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12))
            : null,
        value: value,
        activeThumbColor: activeThumbColor,
        onChanged: onChanged,
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle,
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: trailing ??
          (onTap != null
              ? const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary)
              : null),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 64);
}
