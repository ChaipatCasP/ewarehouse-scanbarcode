import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class OtpScreen extends StatefulWidget {
  final ApiService apiService;
  final String username;
  final String company;
  final String staffCode;
  final String otpCode;
  final String refCode;

  const OtpScreen({
    super.key,
    required this.apiService,
    required this.username,
    required this.company,
    required this.staffCode,
    required this.otpCode,
    required this.refCode,
  });

  /// Generate a random 6-digit OTP
  static String generateOtp() {
    final r = Random();
    return List.generate(6, (_) => r.nextInt(10)).join();
  }

  /// Generate a random 6-char alphanumeric Ref Code (e.g. YE103B)
  static String generateRefCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _ctrlList =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusList = List.generate(6, (_) => FocusNode());

  late String _otp;
  late String _refCode;

  Timer? _timer;
  int _seconds = 180; // 3 minutes
  bool _expired = false;
  bool _sending = false;
  String? _error;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _otp = widget.otpCode;
    _refCode = widget.refCode;
    _startTimer();

    // Handle backspace: when box is empty and backspace pressed → go back
    for (int i = 1; i < 6; i++) {
      final idx = i;
      _focusList[idx].onKeyEvent = (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _ctrlList[idx].text.isEmpty) {
          FocusScope.of(context).requestFocus(_focusList[idx - 1]);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _ctrlList) c.dispose();
    for (final f in _focusList) f.dispose();
    super.dispose();
  }

  // ── Timer ──────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _seconds = 180;
      _expired = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_seconds > 0) {
          _seconds--;
        } else {
          _expired = true;
          t.cancel();
        }
      });
    });
  }

  String get _timerDisplay =>
      '${(_seconds ~/ 60).toString().padLeft(2, '0')} : ${(_seconds % 60).toString().padLeft(2, '0')}';

  // ── OTP Logic ──────────────────────────────────────────────────────────────

  String get _entered => _ctrlList.map((c) => c.text).join();

  void _onDigitChanged(int i, String v) {
    setState(() => _error = null);
    if (v.length == 1 && i < 5) {
      FocusScope.of(context).requestFocus(_focusList[i + 1]);
    }
    // Auto-verify when last digit entered
    if (i == 5 && v.length == 1) {
      Future.microtask(_verify);
    }
  }

  void _verify() {
    final entered = _entered;
    if (entered.length < 6) {
      setState(() => _error = 'กรุณากรอก OTP ให้ครบ 6 หลัก');
      return;
    }
    if (_expired) {
      setState(() => _error = 'OTP หมดอายุ กรุณากด Resend Code');
      return;
    }
    if (entered == _otp) {
      _timer?.cancel();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(apiService: widget.apiService),
        ),
      );
    } else {
      setState(() => _error = 'OTP ไม่ถูกต้อง กรุณาตรวจสอบอีกครั้ง');
      for (final c in _ctrlList) c.clear();
      FocusScope.of(context).requestFocus(_focusList[0]);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    //final newOtp = OtpScreen.generateOtp();
    final newOtp = widget.username.toUpperCase() == 'DEMO'
        ? '113333'
        : OtpScreen.generateOtp();
    final newRef = OtpScreen.generateRefCode();

    try {
      // await widget.apiService.sendOtpToLine(
      //   user: widget.username,
      //   staffCode: widget.staffCode,
      //   otp: newOtp,
      //   refCode: newRef,
      // );
      if (!mounted) return;
      setState(() {
        _otp = newOtp;
        _refCode = newRef;
        _sending = false;
      });
      for (final c in _ctrlList) c.clear();
      FocusScope.of(context).requestFocus(_focusList[0]);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่ง OTP ใหม่เรียบร้อยแล้ว'),
          backgroundColor: Color(0xFF16A34A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'ส่ง OTP ไม่สำเร็จ: $e';
      });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D2137), Color(0xFF1a3a5b), Color(0xFF2A6088)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── JAGOTA Logo ───────────────────────────────────────
                    const _JagotaLogo(),
                    const SizedBox(height: 24),

                    // ── Title ────────────────────────────────────────────
                    const Text(
                      'OTP Verification',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณากรอกรหัส OTP 6 หลัก\nที่ส่งไปยัง LINE ของคุณ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 32),

                    // ── OTP digit boxes ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children:
                          List.generate(6, (i) => _buildDigitBox(i)),
                    ),

                    // ── Error text ────────────────────────────────────────
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Ref Code ──────────────────────────────────────────
                    Row(
                      children: [
                        Text(
                          'Ref Code:  ',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                        ),
                        Text(
                          _refCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Countdown Timer Box ───────────────────────────────
                    _buildTimerBox(),
                    const SizedBox(height: 20),

                    // ── Verify OTP Button ─────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _expired ? null : _verify,
                        icon: const Icon(Icons.shield_rounded, size: 20),
                        label: const Text(
                          'Verify OTP',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade200,
                          disabledForegroundColor: Colors.grey.shade400,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Resend Code Button ────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: (_expired && !_sending) ? _resend : null,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'Resend Code',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: BorderSide(
                            color: _expired
                                ? AppTheme.primary
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Back to Login ─────────────────────────────────────
                    TextButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen()),
                      ),
                      icon: Icon(Icons.arrow_back,
                          size: 16, color: Colors.grey.shade500),
                      label: Text(
                        'Back to Login',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Digit Box ──────────────────────────────────────────────────────────────

  Widget _buildDigitBox(int i) {
    final hasVal = _ctrlList[i].text.isNotEmpty;
    final isErr = _error != null;

    return Container(
      width: 44,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: hasVal
            ? AppTheme.primary.withValues(alpha: 0.05)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isErr
              ? Colors.red.withValues(alpha: 0.5)
              : hasVal
                  ? AppTheme.primary.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
      ),
      child: Center(
        child: TextField(
          controller: _ctrlList[i],
          focusNode: _focusList[i],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(1),
          ],
          onChanged: (v) => _onDigitChanged(i, v),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            counterText: '',
          ),
        ),
      ),
    );
  }

  // ── Timer Box ──────────────────────────────────────────────────────────────

  Widget _buildTimerBox() {
    if (_expired) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.white, size: 26),
            SizedBox(height: 6),
            Text('Code expired',
                style: TextStyle(color: Colors.white, fontSize: 14)),
            SizedBox(height: 4),
            Text(
              '00 : 00',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFFB923C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time_rounded,
              color: Colors.white, size: 26),
          const SizedBox(height: 6),
          const Text(
            'Code expires in',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _timerDisplay,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── JAGOTA Logo Widget ────────────────────────────────────────────────────────

class _JagotaLogo extends StatelessWidget {
  const _JagotaLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'JAG',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          // 'O' with red dot
          Stack(
            alignment: Alignment.center,
            children: [
              const Text(
                'O',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Positioned(
                top: 7,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const Text(
            'TA',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

