import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/secure_storage.dart';
import '../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});
  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen>
    with SingleTickerProviderStateMixin {
  String _pin        = '';
  String _firstPin   = '';
  bool   _confirming = false;
  String? _error;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0),   weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _onComplete();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      setState(() { _firstPin = _pin; _pin = ''; _confirming = true; });
      return;
    }
    // Confirm step
    if (_pin != _firstPin) {
      setState(() { _error = 'PINs do not match. Try again.'; _pin = ''; _confirming = false; _firstPin = ''; });
      _shakeCtrl.forward(from: 0);
      return;
    }
    // Save
    final ok = await ref.read(authNotifierProvider.notifier).setPin(_pin);
    if (!mounted) return;
    if (ok) {
      final userType = await SecureStorageService.getUserType();
      if (!mounted) return;
      context.go(userType == 'teacher' ? '/teacher-dashboard' : '/dashboard');
    } else {
      setState(() { _error = ref.read(authNotifierProvider).error ?? 'Failed'; _pin = ''; _confirming = false; _firstPin = ''; });
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 48),
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.lock_outline_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            _confirming ? 'Confirm Your PIN' : 'Create a PIN',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E)),
          ),
          const SizedBox(height: 8),
          Text(
            _confirming
              ? 'Enter your PIN again to confirm'
              : 'Set a 4-digit PIN for quick login',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),

          // PIN dots
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shake.value, 0), child: child),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _PinDot(filled: i < _pin.length)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ),
          ],

          const Spacer(),

          // Numpad
          if (isLoading)
            const CircularProgressIndicator()
          else
            _Numpad(onDigit: _onDigit, onBackspace: _onBackspace),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}

// ── PIN Login Screen ──────────────────────────────────────────────────────────

class PinLoginScreen extends ConsumerStatefulWidget {
  final String mobile;
  final String schoolSubdomain;
  final String? admissionNo;
  const PinLoginScreen({
    super.key,
    required this.mobile,
    required this.schoolSubdomain,
    this.admissionNo,
  });
  @override
  ConsumerState<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends ConsumerState<PinLoginScreen>
    with SingleTickerProviderStateMixin {
  String  _pin   = '';
  String? _error;

  late final AnimationController _shakeCtrl;
  late final Animation<double>   _shake;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shake = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -6.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 0.0),   weight: 1),
    ]).animate(_shakeCtrl);
  }

  @override
  void dispose() { _shakeCtrl.dispose(); super.dispose(); }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() { _pin += d; _error = null; });
    if (_pin.length == 4) _login();
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _login() async {
    final ok = await ref.read(authNotifierProvider.notifier).loginWithPin(
      schoolSubdomain: widget.schoolSubdomain,
      mobile: widget.mobile,
      pin: _pin,
      admissionNo: widget.admissionNo,
    );
    if (!mounted) return;
    if (ok) {
      final userType = await SecureStorageService.getUserType();
      if (!mounted) return;
      context.go(userType == 'teacher' ? '/teacher-dashboard' : '/dashboard');
    } else {
      setState(() {
        _error = ref.read(authNotifierProvider).error ?? 'Incorrect PIN';
        _pin   = '';
      });
      _shakeCtrl.forward(from: 0);
    }
  }

  void _useOtpInstead() {
    // Clear PIN state so they go through OTP flow and reset PIN
    SecureStorageService.clearAll();
    context.go('/login');
  }

  String get _maskedMobile {
    final m = widget.mobile.replaceAll('+91', '');
    if (m.length < 5) return widget.mobile;
    return '+91 ${m.substring(0, 2)}****${m.substring(m.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authNotifierProvider).isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 48),
          // Icon
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF1565C0)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Welcome Back',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                color: Color(0xFF1A237E))),
          const SizedBox(height: 6),
          Text(_maskedMobile,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary,
                fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Enter your 4-digit PIN',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 40),

          // PIN dots
          AnimatedBuilder(
            animation: _shake,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shake.value, 0), child: child),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _PinDot(filled: i < _pin.length)),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],

          const Spacer(),

          if (isLoading)
            const CircularProgressIndicator()
          else
            _Numpad(onDigit: _onDigit, onBackspace: _onBackspace),

          const SizedBox(height: 20),

          TextButton(
            onPressed: _useOtpInstead,
            child: const Text('Use OTP instead / Forgot PIN',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _PinDot extends StatelessWidget {
  final bool filled;
  const _PinDot({required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 18, height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: filled ? AppColors.primary : Colors.grey.shade400,
          width: 2,
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  const _Numpad({required this.onDigit, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1','2','3'],
      ['4','5','6'],
      ['7','8','9'],
      ['','0','⌫'],
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: rows.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: row.map((key) {
              if (key.isEmpty) return const SizedBox(width: 72, height: 56);
              return _NumKey(
                label: key,
                onTap: () => key == '⌫' ? onBackspace() : onDigit(key),
              );
            }).toList(),
          ),
        )).toList(),
      ),
    );
  }
}

class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBackspace = label == '⌫';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72, height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(
          child: isBackspace
            ? const Icon(Icons.backspace_outlined, size: 20,
                color: AppColors.textSecondary)
            : Text(label,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E))),
        ),
      ),
    );
  }
}
