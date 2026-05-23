import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage.dart';
import '../providers/auth_provider.dart';

const _kNavy = Color(0xFF1A237E);

class OtpScreen extends ConsumerStatefulWidget {
  final String mobile, schoolSubdomain;
  final String? admissionNo;
  const OtpScreen({
    super.key,
    required this.mobile,
    required this.schoolSubdomain,
    this.admissionNo,
  });
  @override
  ConsumerState<OtpScreen> createState() => _State();
}

class _State extends ConsumerState<OtpScreen> with TickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  int _secs = 60;
  bool _canResend = false;

  late final AnimationController _enterCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _shakeCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _cardFade;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _heroFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _cardSlide = Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(
          parent: _enterCtrl,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic)),
    );
    _cardFade = CurvedAnimation(
      parent: _enterCtrl,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _enterCtrl.forward();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    _enterCtrl.dispose();
    _floatCtrl.dispose();
    _shakeCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _secs = 60;
      _canResend = false;
    });
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _secs--);
      if (_secs <= 0) {
        setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _shakeCtrl.forward(from: 0);
      return;
    }
    FocusScope.of(context).unfocus();
    final (ok, pinSet) = await ref.read(authNotifierProvider.notifier).verifyOtp(
      schoolSubdomain: widget.schoolSubdomain,
      mobile: widget.mobile,
      otp: otp,
      admissionNo: widget.admissionNo,
    );
    if (!mounted) return;
    if (ok) {
      if (!pinSet) {
        // First time or PIN was reset — go to PIN setup
        context.go('/pin-setup');
      } else {
        final userType = await SecureStorageService.getUserType();
        if (!mounted) return;
        context.go(userType == 'teacher' ? '/teacher-dashboard' : '/dashboard');
      }
    } else {
      _shakeCtrl.forward(from: 0);
    }
  }

  Future<void> _resend() async {
    await ref.read(authNotifierProvider.notifier).requestOtp(
      schoolSubdomain: widget.schoolSubdomain,
      mobile: widget.mobile,
      admissionNo: widget.admissionNo,
    );
    _otpController.clear();
    setState(() {});
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(authNotifierProvider);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6F7FF),
      body: Column(
        children: [
          FadeTransition(
            opacity: _heroFade,
            child: _HeroSection(
                floatCtrl: _floatCtrl, pulseCtrl: _pulseCtrl),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 4,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SlideTransition(
                position: _cardSlide,
                child: FadeTransition(
                  opacity: _cardFade,
                  child: _FormCard(
                    mobile: widget.mobile,
                    otpController: _otpController,
                    focusNode: _focusNode,
                    shake: _shake,
                    isLoading: s.isLoading,
                    error: s.error,
                    secs: _secs,
                    canResend: _canResend,
                    onVerify: _verify,
                    onResend: _resend,
                    onBack: () {
                      ref.read(authNotifierProvider.notifier).reset();
                      context.go('/login');
                    },
                    onChanged: (v) {
                      setState(() {});
                      if (v.length == 6) _verify();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final AnimationController floatCtrl;
  final AnimationController pulseCtrl;
  const _HeroSection({required this.floatCtrl, required this.pulseCtrl});

  static const _icons = [
    _FD(icon: Icons.sms_rounded,        color: Color(0xFFFFD54F), lf: 0.07, tp: 0.10, ph: 0.0),
    _FD(icon: Icons.verified_rounded,   color: Color(0xFF80DEEA), lf: 0.74, tp: 0.08, ph: 1.05),
    _FD(icon: Icons.shield_rounded,     color: Color(0xFFA5D6A7), lf: 0.82, tp: 0.58, ph: 2.1),
    _FD(icon: Icons.smartphone_rounded, color: Color(0xFFFFCC80), lf: 0.05, tp: 0.60, ph: 3.15),
    _FD(icon: Icons.lock_open_rounded,  color: Color(0xFFCE93D8), lf: 0.50, tp: 0.05, ph: 4.2),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _WaveClipper(),
      child: Container(
        height: 215,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1B6E), Color(0xFF1A237E), Color(0xFF3F51B5)],
          ),
        ),
        child: Stack(
          children: [
            // floating icons
            ..._icons.map((f) => _FloatIcon(ctrl: floatCtrl, fd: f)),
            // center content
            Align(
              alignment: const Alignment(0, -0.15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: pulseCtrl,
                    builder: (_, child) => Transform.scale(
                      scale: 1.0 + pulseCtrl.value * 0.06,
                      child: child,
                    ),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.lock_rounded,
                          color: _kNavy, size: 36),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'OTP Verification',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Secure  ·  Fast  ·  Easy',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wave clipper ──────────────────────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..lineTo(0, s.height - 24)
      ..quadraticBezierTo(
          s.width * 0.13, s.height + 12, s.width * 0.35, s.height - 14)
      ..quadraticBezierTo(
          s.width * 0.58, s.height - 40, s.width * 0.76, s.height - 6)
      ..quadraticBezierTo(
          s.width * 0.90, s.height + 10, s.width, s.height - 16)
      ..lineTo(s.width, 0)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(_) => false;
}

// ── Floating icon data + widget ───────────────────────────────────────────────

class _FD {
  final IconData icon;
  final Color color;
  final double lf, tp, ph;
  const _FD(
      {required this.icon,
      required this.color,
      required this.lf,
      required this.tp,
      required this.ph});
}

class _FloatIcon extends StatelessWidget {
  final AnimationController ctrl;
  final _FD fd;
  const _FloatIcon({required this.ctrl, required this.fd});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final dy =
            math.sin(ctrl.value * 2 * math.pi + fd.ph) * 5.0;
        return Positioned(
          left: MediaQuery.of(context).size.width * fd.lf,
          top: 215 * fd.tp + dy,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: fd.color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: fd.color.withOpacity(0.50), width: 1.2),
            ),
            child: Icon(fd.icon, color: Colors.white, size: 18),
          ),
        );
      },
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final String mobile;
  final TextEditingController otpController;
  final FocusNode focusNode;
  final Animation<double> shake;
  final bool isLoading;
  final String? error;
  final int secs;
  final bool canResend;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;

  const _FormCard({
    required this.mobile,
    required this.otpController,
    required this.focusNode,
    required this.shake,
    required this.isLoading,
    required this.error,
    required this.secs,
    required this.canResend,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A237E).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16, color: _kNavy),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter OTP',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  Text(
                    'Code sent to $mobile',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 28),

          // OTP boxes
          AnimatedBuilder(
            animation: shake,
            builder: (_, child) =>
                Transform.translate(offset: Offset(shake.value, 0), child: child),
            child: _OtpBoxes(
                controller: otpController,
                focusNode: focusNode,
                onChanged: onChanged),
          ),

          const SizedBox(height: 10),

          // Tap anywhere to type hint
          Center(
            child: GestureDetector(
              onTap: () => focusNode.requestFocus(),
              child: const Text(
                'Tap boxes to type',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Error
          if (error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.danger.withOpacity(0.3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13)),
                  ),
                ],
              ),
            ),

          // Verify button
          GestureDetector(
            onTap: isLoading ? null : onVerify,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLoading
                      ? [Colors.grey.shade400, Colors.grey.shade400]
                      : const [Color(0xFF1A237E), Color(0xFF3949AB)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: isLoading
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF1A237E).withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Verify & Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Resend row
          Center(
            child: canResend
                ? GestureDetector(
                    onTap: onResend,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded, color: _kNavy, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: _kNavy,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        'Resend in $secs seconds',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 20),

          // Footer
          const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 12, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text(
                  'Secured with OTP verification',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── OTP box row (hidden field + 6 display boxes) ──────────────────────────────

class _OtpBoxes extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  const _OtpBoxes(
      {required this.controller,
      required this.focusNode,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          // Hidden actual input — 1px tall + fully transparent
          SizedBox(
            height: 1,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    counterText: '', border: InputBorder.none),
                onChanged: onChanged,
              ),
            ),
          ),
          // Display boxes
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, val, __) {
              final digits = val.text.padRight(6, ' ');
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  final ch = digits[i].trim();
                  final isFilled = ch.isNotEmpty;
                  final isCurrent = val.text.length == i;
                  return Container(
                    width: 44,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isFilled
                          ? const Color(0xFFEEF0FF)
                          : const Color(0xFFF6F7FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFilled
                            ? _kNavy
                            : isCurrent
                                ? const Color(0xFF7986CB)
                                : const Color(0xFFDDE1F8),
                        width: isFilled || isCurrent ? 2.0 : 1.2,
                      ),
                    ),
                    child: Center(
                      child: isFilled
                          ? Text(
                              ch,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                              ),
                            )
                          : isCurrent
                              ? _BlinkCursor()
                              : null,
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Blinking cursor ───────────────────────────────────────────────────────────

class _BlinkCursor extends StatefulWidget {
  @override
  State<_BlinkCursor> createState() => _BlinkCursorState();
}

class _BlinkCursorState extends State<_BlinkCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: 2,
          height: 22,
          color: _kNavy.withOpacity(_c.value),
        ),
      );
}
