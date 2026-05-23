import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage.dart';
import '../providers/auth_provider.dart';

// ── Login Screen ──────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _schoolCtrl = TextEditingController(text: 'demo');
  final _mobileCtrl = TextEditingController();
  final _admCtrl    = TextEditingController();
  final _formKey    = GlobalKey<FormState>();
  bool _isTeacher   = false;

  late final AnimationController _floatCtrl;
  late final AnimationController _enterCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _headerFade;
  late final Animation<double> _formSlide;
  late final Animation<double> _formFade;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _checkPinAndRedirect();

    _floatCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 4))..repeat();

    _enterCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 1400))..forward();

    _pulseCtrl = AnimationController(vsync: this,
        duration: const Duration(seconds: 2))..repeat(reverse: true);

    _headerFade = CurvedAnimation(parent: _enterCtrl,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOut));

    _formSlide = Tween<double>(begin: 80, end: 0).animate(
        CurvedAnimation(parent: _enterCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)));

    _formFade = CurvedAnimation(parent: _enterCtrl,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOut));

    _pulse = Tween<double>(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _enterCtrl.dispose();
    _pulseCtrl.dispose();
    _schoolCtrl.dispose();
    _mobileCtrl.dispose();
    _admCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkPinAndRedirect() async {
    final pinSet = await SecureStorageService.getPinSet();
    if (!pinSet || !mounted) return;
    final last = await SecureStorageService.getLastLogin();
    if (!mounted) return;
    if (last.mobile != null && last.school != null) {
      context.go('/pin-login'
          '?mobile=${Uri.encodeComponent(last.mobile!)}'
          '&school=${last.school!}'
          '&admissionNo=${last.admissionNo ?? ''}');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final mobile = '+91${_mobileCtrl.text.trim()}';
    final ok = await ref.read(authNotifierProvider.notifier).requestOtp(
      schoolSubdomain: _schoolCtrl.text.trim(),
      mobile: mobile,
      admissionNo: _isTeacher ? null : _admCtrl.text.trim(),
    );
    if (ok && mounted) {
      context.go('/otp'
          '?mobile=${Uri.encodeComponent(mobile)}'
          '&school=${_schoolCtrl.text.trim()}'
          '&admissionNo=${_admCtrl.text.trim()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      resizeToAvoidBottomInset: true,
      body: Column(children: [
        // ── Animated hero ──────────────────────────────────────────────
        FadeTransition(
          opacity: _headerFade,
          child: _HeroSection(floatCtrl: _floatCtrl, pulse: _pulse),
        ),

        // ── Form card slides up ────────────────────────────────────────
        Expanded(
          child: AnimatedBuilder(
            animation: _enterCtrl,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, _formSlide.value),
              child: FadeTransition(opacity: _formFade, child: child!),
            ),
            child: _FormCard(
              formKey:    _formKey,
              schoolCtrl: _schoolCtrl,
              mobileCtrl: _mobileCtrl,
              admCtrl:    _admCtrl,
              isTeacher:  _isTeacher,
              isLoading:  auth.isLoading,
              error:      auth.error,
              onToggle:   (v) => setState(() => _isTeacher = v),
              onSubmit:   _submit,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Hero Section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final AnimationController floatCtrl;
  final Animation<double> pulse;
  const _HeroSection({required this.floatCtrl, required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatCtrl,
      builder: (_, __) {
        final t = floatCtrl.value * 2 * math.pi;
        return ClipPath(
          clipper: _WaveClipper(),
          child: Container(
            height: 270,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1B6E), Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3F51B5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(children: [
              // ── Background decorative circles ──────────────────────
              Positioned(right: -40, top: -40,
                child: _bgDot(200, 0.06)),
              Positioned(left: -30, bottom: 10,
                child: _bgDot(140, 0.05)),
              Positioned(right: 80, bottom: -20,
                child: _bgDot(90, 0.04)),

              // ── Floating subject icons (6 icons, different phases) ──
              Positioned(left: 18, top: 52 + 12 * math.sin(t),
                child: _FloatIcon(Icons.menu_book_rounded, const Color(0xFFFFB300), 46)),

              Positioned(right: 20, top: 38 + 10 * math.sin(t + math.pi / 3),
                child: _FloatIcon(Icons.edit_rounded, const Color(0xFFEC407A), 40)),

              Positioned(left: 54, bottom: 52 + 9 * math.sin(t + 2 * math.pi / 3),
                child: _FloatIcon(Icons.calculate_rounded, const Color(0xFF26C6DA), 38)),

              Positioned(right: 52, bottom: 60 + 9 * math.sin(t + math.pi),
                child: _FloatIcon(Icons.star_rounded, const Color(0xFFFFD54F), 36)),

              Positioned(left: 116, top: 24 + 7 * math.sin(t + 4 * math.pi / 3),
                child: _FloatIcon(Icons.science_rounded, const Color(0xFF69F0AE), 32)),

              Positioned(right: 112, bottom: 52 + 7 * math.sin(t + 5 * math.pi / 3),
                child: _FloatIcon(Icons.palette_rounded, const Color(0xFFFF6E40), 32)),

              // ── Center logo ────────────────────────────────────────
              Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const SizedBox(height: 20),
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, child) => Transform.scale(
                        scale: pulse.value, child: child!),
                    child: Container(
                      width: 78, height: 78,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.22),
                              blurRadius: 22, offset: const Offset(0, 8)),
                          BoxShadow(color: const Color(0xFF3F51B5).withOpacity(0.35),
                              blurRadius: 16, spreadRadius: 2),
                        ],
                      ),
                      child: const Icon(Icons.school_rounded,
                          color: Color(0xFF1A237E), size: 42),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text('Sikhya',
                    style: TextStyle(color: Colors.white, fontSize: 20,
                        fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Text('Connecting Schools & Families',
                      style: TextStyle(color: Colors.white70, fontSize: 11,
                          fontWeight: FontWeight.w500)),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _bgDot(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
        color: Colors.white.withOpacity(opacity)));
}

// ── Wave Clipper ──────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..lineTo(0, s.height - 28)
      ..quadraticBezierTo(s.width * 0.15, s.height + 14, s.width * 0.38, s.height - 16)
      ..quadraticBezierTo(s.width * 0.60, s.height - 44, s.width * 0.78, s.height - 8)
      ..quadraticBezierTo(s.width * 0.91, s.height + 8, s.width, s.height - 18)
      ..lineTo(s.width, 0)
      ..close();
    return p;
  }
  @override bool shouldReclip(_WaveClipper _) => false;
}

// ── Float Icon ────────────────────────────────────────────────────────────────

class _FloatIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _FloatIcon(this.icon, this.color, this.size);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withOpacity(0.55), width: 1.5),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.25), blurRadius: 8, offset: const Offset(0, 3))
        ],
      ),
      child: Icon(icon, color: Colors.white.withOpacity(0.92), size: size * 0.54),
    );
  }
}

// ── Form Card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController schoolCtrl, mobileCtrl, admCtrl;
  final bool isTeacher, isLoading;
  final String? error;
  final void Function(bool) onToggle;
  final VoidCallback onSubmit;

  const _FormCard({
    required this.formKey,
    required this.schoolCtrl,
    required this.mobileCtrl,
    required this.admCtrl,
    required this.isTeacher,
    required this.isLoading,
    required this.error,
    required this.onToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 32),
        child: Form(
          key: formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Header text
            const Text('Welcome Back!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                  color: Color(0xFF1A237E))),
            const SizedBox(height: 3),
            const Text('Sign in to your school account',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),

            const SizedBox(height: 18),

            // ── Parent / Teacher toggle ──────────────────────────────
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1FF),
                borderRadius: BorderRadius.circular(13),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                _ToggleBtn('Parent',  !isTeacher, () => onToggle(false)),
                _ToggleBtn('Teacher',  isTeacher, () => onToggle(true)),
              ]),
            ),

            const SizedBox(height: 16),

            // ── School ID ────────────────────────────────────────────
            _Field(
              controller: schoolCtrl,
              label: 'School ID',
              icon: Icons.domain_rounded,
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            // ── Mobile number ────────────────────────────────────────
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFDDE1F8)),
                ),
                child: const Center(
                  child: Text('+91',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: Color(0xFF1A237E)))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Field(
                  controller: mobileCtrl,
                  label: 'Mobile Number',
                  hint: '10-digit number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) => (v?.length ?? 0) != 10
                      ? 'Enter valid 10-digit number' : null,
                ),
              ),
            ]),

            // ── Admission Number (parent only) ───────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => SizeTransition(
                sizeFactor: anim, axisAlignment: -1, child: child),
              child: !isTeacher
                  ? Padding(
                      key: const ValueKey('adm'),
                      padding: const EdgeInsets.only(top: 12),
                      child: _Field(
                        controller: admCtrl,
                        label: 'Admission Number',
                        icon: Icons.badge_rounded,
                        validator: (v) => v?.isEmpty == true ? 'Required' : null,
                      ),
                    )
                  : const SizedBox.shrink(key: ValueKey('none')),
            ),

            // ── Error ────────────────────────────────────────────────
            if (error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                ]),
              ),
            ],

            const SizedBox(height: 20),

            // ── Send OTP button ──────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  foregroundColor: Colors.white,
                  elevation: 6,
                  shadowColor: const Color(0xFF1A237E).withOpacity(0.45),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: isLoading
                    ? const SizedBox(width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Send OTP',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Footer ───────────────────────────────────────────────
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded,
                    size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Secured with OTP verification',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Toggle Button ─────────────────────────────────────────────────────────────

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleBtn(this.label, this.active, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF1A237E) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3),
                    blurRadius: 8, offset: const Offset(0, 2))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(
                label == 'Parent'
                    ? Icons.family_restroom_rounded
                    : Icons.school_rounded,
                size: 15,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: active ? Colors.white : AppColors.textSecondary,
                )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Styled input field ────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: Color(0xFF000000), fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: const Color(0xFFF6F7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1F8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE1F8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
    );
  }
}
