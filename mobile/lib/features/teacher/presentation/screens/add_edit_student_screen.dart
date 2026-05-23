import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

class AddEditStudentScreen extends ConsumerStatefulWidget {
  final String classId;
  final Map<String, dynamic>? existing;
  const AddEditStudentScreen({super.key, required this.classId, this.existing});

  @override
  ConsumerState<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends ConsumerState<AddEditStudentScreen> {
  final _form      = GlobalKey<FormState>();
  final _name      = TextEditingController();
  final _admNo     = TextEditingController();
  final _rollNo    = TextEditingController();
  final _address   = TextEditingController();
  final _emergency = TextEditingController();

  String?    _gender;
  DateTime?  _dob;
  Uint8List? _photoBytes;
  String?    _photoBase64;
  bool       _saving = false;

  bool get _isEdit => widget.existing != null;

  static const _kPrimary = AppColors.primary;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final e = widget.existing!;
      _name.text      = e['full_name']          as String? ?? '';
      _admNo.text     = e['admission_no']        as String? ?? '';
      _rollNo.text    = e['roll_number']         as String? ?? '';
      _gender         = e['gender']              as String?;
      _address.text   = e['address']             as String? ?? '';
      _emergency.text = e['emergency_contact']   as String? ?? '';
      final dob = e['date_of_birth'] as String?;
      if (dob != null) _dob = DateTime.tryParse(dob);
      final photo = e['profile_photo'] as String?;
      if (photo != null && photo.isNotEmpty) {
        try {
          final data = photo.contains(',') ? photo.split(',').last : photo;
          _photoBytes  = base64Decode(data);
          _photoBase64 = photo;
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _name.dispose(); _admNo.dispose(); _rollNo.dispose();
    _address.dispose(); _emergency.dispose();
    super.dispose();
  }

  // ── Photo ──────────────────────────────────────────────────────────────

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await ImagePicker()
        .pickImage(source: source, maxWidth: 600, imageQuality: 75);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    setState(() { _photoBytes = bytes; _photoBase64 = base64Encode(bytes); });
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded),
            title: const Text('Take Photo'),
            onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded),
            title: const Text('Choose from Gallery'),
            onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
          ),
          if (_photoBytes != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
              title: const Text('Remove Photo',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(context);
                setState(() { _photoBytes = null; _photoBase64 = null; });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── Date of birth ──────────────────────────────────────────────────────

  Future<void> _pickDob() async {
    // Start in text-input mode for fast typing; fallback to calendar via toggle
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(DateTime.now().year - 10, 6, 1),
      firstDate: DateTime(1980),
      lastDate: DateTime.now().subtract(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'DATE OF BIRTH',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: _kPrimary,
            primary: _kPrimary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: AppColors.textPrimary,
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _kPrimary)),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _dob = d);
  }

  // ── Save ───────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'class_id':     widget.classId,
        'full_name':    _name.text.trim(),
        'admission_no': _admNo.text.trim(),
        if (_rollNo.text.isNotEmpty)    'roll_number':       _rollNo.text.trim(),
        if (_gender != null)            'gender':            _gender,
        if (_dob != null)               'date_of_birth':     DateFormat('yyyy-MM-dd').format(_dob!),
        if (_photoBase64 != null)       'profile_photo':     _photoBase64,
        if (_address.text.isNotEmpty)   'address':           _address.text.trim(),
        if (_emergency.text.isNotEmpty) 'emergency_contact': _emergency.text.trim(),
      };
      if (_isEdit) {
        body.remove('class_id');
        await ApiClient.instance.put(
            ApiConstants.studentUpdate(widget.existing!['id'] as String), data: body);
      } else {
        await ApiClient.instance.post(ApiConstants.teacherStudents, data: body);
      }
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Failed to save student';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Student' : 'Add Student'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              ),
              child: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isEdit ? 'Save' : 'Add',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(children: [
            // ── Hero photo header ────────────────────────────────────────
            _buildPhotoHero(),

            const SizedBox(height: 16),

            // ── Basic Information ────────────────────────────────────────
            _SectionCard(
              icon: Icons.badge_rounded,
              title: 'Basic Information',
              child: Column(children: [
                _FieldLabel('Full Name', required: true),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: _deco('e.g. Arjun Singh',
                      icon: Icons.person_outline_rounded),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Enter full name' : null,
                ),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Admission No.', required: true),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _admNo,
                        decoration: _deco('e.g. 2024-001'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Required' : null,
                      ),
                    ],
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('Roll No.'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _rollNo,
                        decoration: _deco('e.g. 01'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  )),
                ]),
              ]),
            ),

            // ── Personal Details ─────────────────────────────────────────
            _SectionCard(
              icon: Icons.person_rounded,
              title: 'Personal Details',
              child: Column(children: [
                _FieldLabel('Gender'),
                const SizedBox(height: 10),
                _buildGenderPicker(),
                const SizedBox(height: 16),
                _FieldLabel('Date of Birth'),
                const SizedBox(height: 6),
                _buildDobPicker(),
              ]),
            ),

            // ── Contact & Emergency ──────────────────────────────────────
            _SectionCard(
              icon: Icons.contact_phone_rounded,
              title: 'Contact & Emergency',
              child: Column(children: [
                _FieldLabel('Home Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _address,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _deco('Street, City, PIN',
                      icon: Icons.home_outlined),
                ),
                const SizedBox(height: 16),
                _FieldLabel('Emergency Contact'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emergency,
                  keyboardType: TextInputType.phone,
                  decoration: _deco('Phone number',
                      icon: Icons.emergency_rounded),
                ),
              ]),
            ),

            // ── Save button ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: _buildSaveButton(),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Photo hero ─────────────────────────────────────────────────────────

  Widget _buildPhotoHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, _kPrimary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: _showPhotoOptions,
          child: Stack(alignment: Alignment.bottomRight, children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4))
                ],
              ),
              child: CircleAvatar(
                radius: 52,
                backgroundColor: const Color(0xFF1E40AF),
                backgroundImage:
                    _photoBytes != null ? MemoryImage(_photoBytes!) : null,
                child: _photoBytes == null
                    ? const Icon(Icons.person_rounded,
                        size: 52, color: Colors.white60)
                    : null,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 6)
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: _kPrimary, size: 16),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
          _photoBytes != null ? 'Tap to change photo' : 'Tap to add photo',
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, letterSpacing: 0.3),
        ),
      ]),
    );
  }

  // ── Gender picker ──────────────────────────────────────────────────────

  Widget _buildGenderPicker() {
    final options = [
      (_GenderOpt('Male',   'male',   Icons.male_rounded)),
      (_GenderOpt('Female', 'female', Icons.female_rounded)),
      (_GenderOpt('Other',  'other',  Icons.person_outline_rounded)),
    ];
    return Row(
      children: options.map((opt) {
        final active = _gender == opt.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
                right: opt.value != 'other' ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(
                  () => _gender = active ? null : opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: active
                      ? _kPrimary
                      : AppColors.surface,
                  border: Border.all(
                    color: active
                        ? _kPrimary
                        : AppColors.border,
                    width: active ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [BoxShadow(
                          color: _kPrimary.withOpacity(0.25),
                          blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(opt.icon, size: 22,
                        color: active ? Colors.white : AppColors.textSecondary),
                    const SizedBox(height: 4),
                    Text(opt.label,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: active
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── DOB picker ─────────────────────────────────────────────────────────

  Widget _buildDobPicker() {
    return GestureDetector(
      onTap: _pickDob,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded,
              color: _kPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: _dob != null
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Date of Birth',
                        style: TextStyle(
                            fontSize: 11,
                            color: _kPrimary,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMMM yyyy').format(_dob!),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ])
                : const Text('Select date of birth',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textMuted)),
          ),
          if (_dob != null)
            GestureDetector(
              onTap: () => setState(() => _dob = null),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textMuted),
            )
          else
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted, size: 20),
        ]),
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, _kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withOpacity(0.4),
              blurRadius: 14,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : _save,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white24,
          child: Center(
            child: _saving
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        _isEdit
                            ? Icons.check_circle_rounded
                            : Icons.person_add_rounded,
                        color: Colors.white,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(
                        _isEdit ? 'Save Changes' : 'Add Student',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ]),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  InputDecoration _deco(String hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 18) : null,
  );
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SectionCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // Section header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 3, height: 16,
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 15, color: AppColors.primary),
            const SizedBox(width: 7),
            Text(title,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.4)),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel(this.label, {this.required = false});

  @override
  Widget build(BuildContext context) => Row(children: [
    Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary)),
    if (required) const Text(' *',
        style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
  ]);
}

class _GenderOpt {
  final String label, value;
  final IconData icon;
  const _GenderOpt(this.label, this.value, this.icon);
}
