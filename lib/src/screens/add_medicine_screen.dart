import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_application/src/services/notification_service.dart';
import 'package:flutter_application/src/theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddMedicineScreen extends StatefulWidget {
  /// Pass [medicineId] + [initialData] to open in edit mode.
  const AddMedicineScreen({
    super.key,
    this.medicineId,
    this.initialData,
  });

  final String? medicineId;
  final Map<String, dynamic>? initialData;

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _noteController = TextEditingController();
  final _durationController = TextEditingController();

  File? _image;
  String _medicineType = 'Tablet';
  String _medicineDuration = 'regular';
  int _frequency = 1;
  List<TimeOfDay?> _selectedTimes = [null];
  bool _isSaving = false;

  // Holds the id when editing an existing medicine
  String? _medicineId;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _medicineTypes = [
    {
      'label': 'Tablet',
      'img': 'assets/tablet.png',
    },
    {
      'label': 'Capsule',
      'img': 'assets/capsule.png',
    },
    {
      'label': 'Ointment',
      'img': 'assets/ointment.png',
    },
    {
      'label': 'Drops',
      'img': 'assets/drops.png',
    },
    {
      'label': 'Syrup',
      'img': 'assets/syrup.png',
    },
    {
      'label': 'Injection',
      'img': 'assets/injection.png',
    },
    {
      'label': 'Inhaler',
      'img': 'assets/inhaler.png',
    },
    {
      'label': 'Powder',
      'img': 'assets/powder.png',
    },
  ];

  bool get _isEditing => _medicineId != null;

  @override
  void initState() {
    super.initState();

    _medicineId = widget.medicineId;

    // Pre-fill fields when editing
    final d = widget.initialData;
    if (d != null) {
      _nameController.text = d['name'] ?? '';
      _dosageController.text = d['dosage'] ?? '';
      _noteController.text = d['note'] ?? '';
      _medicineType = d['type'] ?? 'Tablet';
      _medicineDuration = d['medicineType'] ?? 'regular';

      final rawTimes = d['times'];
      if (rawTimes is List && rawTimes.isNotEmpty) {
        _frequency = rawTimes.length;
        _selectedTimes = rawTimes.map<TimeOfDay?>((t) {
          if (t is TimeOfDay) return t;
          if (t is Map) {
            return TimeOfDay(
              hour: (t['hour'] as num).toInt(),
              minute: (t['minute'] as num).toInt(),
            );
          }
          return null;
        }).toList();
      } else {
        _frequency = 1;
        _selectedTimes = [null];
      }
    }

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _pickTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppTheme.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTimes[index] = time);
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter a medicine name', isError: true);
      return;
    }
    if (_selectedTimes.any((t) => t == null)) {
      _showSnack('Please set all dose times', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? imageUrl;
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'medicine_images/${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_image!);
        imageUrl = await ref.getDownloadURL();
      }

      final times = _selectedTimes
          .map((t) => {'hour': t!.hour, 'minute': t.minute})
          .toList();

      DateTime? endDate;
      if (_medicineDuration == 'temporary' &&
          _durationController.text.isNotEmpty) {
        final days = int.tryParse(_durationController.text);
        if (days != null) endDate = DateTime.now().add(Duration(days: days));
      }

      final data = {
        // =========================
        // BASIC INFO
        // =========================

        'name': _nameController.text.trim(),

        'dosage': _dosageController.text.trim(),

        'note': _noteController.text.trim(),

        'type': _medicineType,

        // =========================
        // REGULAR / TEMPORARY
        // =========================

        'medicineType': _medicineDuration,

        // =========================
        // TIMES
        // =========================

        'frequency': _frequency,

        'times': times,

        // =========================
        // IMAGE
        // =========================

        'imageUrl': imageUrl,

        // =========================
        // TRACKING
        // =========================

        'takenDates': {},

        // =========================
        // REGULAR MEDICINE
        // =========================

        if (_medicineDuration == 'regular') 'stock': 30,

        if (_medicineDuration == 'regular') 'lowStockThreshold': 5,

        // =========================
        // DOSES
        // =========================

        'doses': List.generate(
          _frequency,
          (index) {
            if (index == 0) {
              return 'morning';
            }

            if (index == 1) {
              return 'afternoon';
            }

            return 'night';
          },
        ),

        // =========================
        // TEMPORARY MEDICINE
        // =========================

        if (_medicineDuration == 'temporary')
          'endDate': endDate != null
              ? Timestamp.fromDate(
                  endDate,
                )
              : null,
      };

      String docId;
      if (_medicineId != null) {
        // Edit mode — update existing document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medicine_schedule')
            .doc(_medicineId)
            .update(data);
        docId = _medicineId!;
      } else {
        // Add mode — create new document
        final docRef = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('medicine_schedule')
            .add({...data, 'createdAt': Timestamp.now()});
        docId = docRef.id;
      }

      // Schedule notifications — wrap separately so a failure here
      // doesn't show an error toast when the medicine was already saved.
      try {
        await NotificationService.scheduleFromMedicineTimes(
          medicineName: _nameController.text.trim(),
          dosage: _dosageController.text.trim(),
          times: _selectedTimes
              .whereType<TimeOfDay>()
              .map((t) => {'hour': t.hour, 'minute': t.minute})
              .toList(),
          medicineId: docId,
        );
      } catch (_) {
        // Notification scheduling may fail on some devices/permissions;
        // the medicine is already saved — don't surface this as an error.
      }

      if (!mounted) return;
      _showSnack(_medicineId != null
          ? 'Medicine updated successfully'
          : 'Medicine added successfully');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildImagePicker(),
                    const SizedBox(height: 24),
                    _buildLabel('Medicine Name'),
                    _buildTextField(_nameController, 'e.g. Metformin 500mg',
                        Icons.medication_outlined),
                    const SizedBox(height: 20),
                    _buildLabel('Medicine Form'),
                    _buildTypeSelector(),
                    const SizedBox(height: 20),
                    _buildLabel('Dosage'),
                    _buildTextField(_dosageController, 'e.g. 1 tablet',
                        Icons.colorize_outlined),
                    const SizedBox(height: 20),
                    _buildLabel('Doses Per Day'),
                    _buildFrequencySelector(),
                    const SizedBox(height: 20),
                    _buildLabel('Dose Times'),
                    _buildTimePickers(),
                    const SizedBox(height: 20),
                    _buildLabel('Schedule Type'),
                    _buildDurationSelector(),
                    if (_medicineDuration == 'temporary') ...[
                      const SizedBox(height: 12),
                      _buildTextField(
                        _durationController,
                        'Number of days',
                        Icons.calendar_today_outlined,
                        isNumber: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    _buildLabel('Notes (Optional)'),
                    _buildNotesField(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildSaveButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.addMedicineGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isEditing ? 'Edit Medicine' : 'Add Medicine',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _isEditing
                          ? 'Update your medication details'
                          : 'Fill in your medication details',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 13, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Smart',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _image != null ? AppTheme.primary : const Color(0xFFE5E7EB),
            width: _image != null ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: AppTheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add Medicine Photo',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to browse gallery',
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              )
            : Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      _image!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.edit_rounded,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon,
            color: AppTheme.primary.withValues(alpha: 0.7), size: 20),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _medicineTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 100,
      ),
      itemBuilder: (context, index) {
        final type = _medicineTypes[index];

        final selected = _medicineType == type['label'];

        const color = Color(0xFF16A34A); // Green

        return GestureDetector(
          onTap: () {
            setState(() {
              _medicineType = type['label'] as String;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.08) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? color : const Color(0xFFE5E7EB),
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        type['img'],
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    color: selected ? color : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(
                    type['label'] as String,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrequencySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Times per day',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
          _counterBtn(Icons.remove_rounded, () {
            if (_frequency > 1) {
              setState(() {
                _frequency--;
                _selectedTimes = List.generate(_frequency, (_) => null);
              });
            }
          }),
          SizedBox(
            width: 40,
            child: Center(
              child: Text(
                '$_frequency',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _counterBtn(Icons.add_rounded, () {
            if (_frequency < 6) {
              setState(() {
                _frequency++;
                _selectedTimes = List.generate(_frequency, (_) => null);
              });
            }
          }),
        ],
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 16),
      ),
    );
  }

  Widget _buildTimePickers() {
    return Column(
      children: List.generate(_frequency, (index) {
        final picked = _selectedTimes[index];
        return GestureDetector(
          onTap: () => _pickTime(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: picked != null
                  ? AppTheme.primary.withValues(alpha: 0.06)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: picked != null
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : const Color(0xFFE5E7EB),
                width: picked != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: picked != null
                        ? AppTheme.primary.withValues(alpha: 0.12)
                        : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.schedule_rounded,
                    color: picked != null
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dose ${index + 1}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        picked == null
                            ? 'Tap to set time'
                            : picked.format(context),
                        style: TextStyle(
                          color: picked != null
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  picked != null
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: picked != null
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  size: 22,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      children: [
        _durationOption('Regular', 'regular', Icons.all_inclusive_rounded,
            AppTheme.success),
        const SizedBox(width: 12),
        _durationOption(
            'Temporary', 'temporary', Icons.timer_outlined, AppTheme.warning),
      ],
    );
  }

  Widget _durationOption(
      String label, String value, IconData icon, Color color) {
    final selected = _medicineDuration == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _medicineDuration = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.1) : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : const Color(0xFFE5E7EB),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : AppTheme.textSecondary, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? color : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _noteController,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: 'e.g. Take after meals, avoid dairy...',
        alignLabelWithHint: true,
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: 40),
          child: Icon(Icons.notes_rounded,
              color: AppTheme.textSecondary, size: 20),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: GestureDetector(
        onTap: _isSaving ? null : _save,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 56,
          decoration: BoxDecoration(
            gradient: _isSaving ? null : AppTheme.addMedicineGradient,
            color: _isSaving ? Colors.grey.shade200 : null,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _isSaving
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.success.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: _isSaving
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: AppTheme.primary, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isEditing
                            ? Icons.save_rounded
                            : Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isEditing ? 'Update Medicine' : 'Save Medicine',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
