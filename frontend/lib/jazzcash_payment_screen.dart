import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

// ─────────────────────────────────────────────────────────────
// SIMULATED JAZZCASH PAYMENT FLOW (with REAL SMS OTP)
//
// Real fund transfer through JazzCash requires JazzCash merchant
// registration (business account, NTN/GST, merchant agreement,
// API keys), which is out of scope for this project. So the
// payment confirmation (MPIN step) is still simulated.
//
// HOWEVER, the OTP step here is REAL: it uses Firebase Phone
// Authentication to send an actual SMS code to the entered
// number and verifies it server-side. This confirms the
// consumer genuinely owns the phone number used for payment.
//
// On success, a document is written to:
//   payments/{txnId}
//     meterID, amount, phoneNumber, status, method, timestamp
// and meters/{meterID}.isPaid is set to true.
//
// PUBSPEC.YAML — add these (if not already present):
//   share_plus: ^7.2.2
//   gal: ^2.3.0
//   path_provider: ^2.1.3
//
// FIREBASE CONSOLE SETUP REQUIRED (one-time):
//   1. Authentication -> Sign-in method -> enable "Phone"
//   2. Project Settings -> Add your app's SHA-1 / SHA-256
//      (Android) so Play Integrity / SafetyNet can verify silently
//   3. (Optional but recommended for demos) Authentication ->
//      Sign-in method -> Phone -> "Phone numbers for testing" ->
//      add a test number + fixed code (e.g. 03001234567 / 123456)
//      so you can demo reliably without waiting for real SMS
// ─────────────────────────────────────────────────────────────
class JazzCashPaymentScreen extends StatefulWidget {
  final String meterID;
  final double amount;
  const JazzCashPaymentScreen({
    super.key,
    required this.meterID,
    required this.amount,
  });

  @override
  State<JazzCashPaymentScreen> createState() => _JazzCashPaymentScreenState();
}

enum _Step { number, otp, pin, processing, success }

class _JazzCashPaymentScreenState extends State<JazzCashPaymentScreen> {
  _Step _step = _Step.number;
  final _numberCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  String? _error;
  String _txnId = '';
  bool _busy = false;           // sending SMS / verifying code
  String? _verificationId;

  static const Color jcRed = Color(0xFFD3122A);   // JazzCash brand red
  static const Color jcOrange = Color(0xFFF6921E); // JazzCash brand orange

  @override
  void dispose() {
    _numberCtrl.dispose();
    _otpCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  String _genTxnId() {
    final rnd = Random();
    final digits = List.generate(10, (_) => rnd.nextInt(10)).join();
    return "JC$digits";
  }

  String _toE164(String local) => "+92${local.substring(1)}"; // 03XXXXXXXXX -> +923XXXXXXXXX

  // ── Step 1 -> 2: send real SMS OTP via Firebase Phone Auth ──
  Future<void> _sendOtp() async {
    final n = _numberCtrl.text.trim();
    if (n.length != 11 || !n.startsWith('03')) {
      setState(() => _error = "Enter a valid 11-digit JazzCash number (03XXXXXXXXX)");
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });

    final phone = _toE164(n);

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-retrieval — code was read automatically.
        // Skip straight past manual OTP entry into the PIN step.
        final ok = await _linkCredential(credential);
        if (ok && mounted) {
          setState(() {
            _busy = false;
            _step = _Step.pin;
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = _friendlyAuthError(e);
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _verificationId = verificationId;
          _step = _Step.otp;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  // ── Step 2 -> 3: verify the entered code ──
  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 4 || _verificationId == null) {
      setState(() => _error = "Enter the code sent to your number");
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    final ok = await _linkCredential(credential);
    if (ok && mounted) {
      setState(() {
        _busy = false;
        _step = _Step.pin;
      });
    } else if (mounted) {
      setState(() => _busy = false);
    }
  }

  /// Links the phone credential to the signed-in consumer account so the
  /// number is genuinely verified. If this number was already verified on
  /// this account before (previous payment), Firebase returns an
  /// "already linked" error — that still means the OTP was correct, so we
  /// treat it as success rather than an error.
  Future<bool> _linkCredential(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = "You're not signed in — please log in again");
      return false;
    }
    try {
      await user.linkWithCredential(credential);
      return true;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked' ||
          e.code == 'credential-already-in-use') {
        return true; // number already verified previously — still valid
      }
      setState(() => _error = _friendlyAuthError(e));
      return false;
    } catch (e) {
      setState(() => _error = "Verification failed — try again");
      return false;
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-verification-code':
        return "Incorrect code — please try again";
      case 'invalid-phone-number':
        return "Invalid phone number format";
      case 'too-many-requests':
        return "Too many attempts — please wait and try again";
      case 'session-expired':
        return "Code expired — request a new one";
      default:
        return e.message ?? "Something went wrong";
    }
  }

  // ── Step 3 -> 4 -> 5: simulated MPIN confirmation + write payment ──
  Future<void> _confirmPin() async {
    if (_pinCtrl.text.trim().length != 4) {
      setState(() => _error = "Enter your 4-digit MPIN");
      return;
    }
    setState(() {
      _error = null;
      _step = _Step.processing;
    });

    await Future.delayed(const Duration(milliseconds: 1800));

    try {
      _txnId = _genTxnId();
      final batch = FirebaseFirestore.instance.batch();

      final paymentRef =
          FirebaseFirestore.instance.collection('payments').doc(_txnId);
      batch.set(paymentRef, {
        'meterID':     widget.meterID,
        'amount':      widget.amount,
        'phoneNumber': _numberCtrl.text.trim(),
        'status':      'Completed',
        'method':      'JazzCash (Simulated)',
        'timestamp':   FieldValue.serverTimestamp(),
      });

      final meterRef =
          FirebaseFirestore.instance.collection('meters').doc(widget.meterID);
      batch.set(meterRef, {'isPaid': true}, SetOptions(merge: true));

      await batch.commit();

      if (mounted) setState(() => _step = _Step.success);
    } catch (e) {
      if (mounted) {
        setState(() {
          _step = _Step.pin;
          _error = "Payment could not be recorded — try again";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: _step == _Step.processing || _step == _Step.success
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0D1B2A),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: jcRed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "JC",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "JazzCash",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.number:
        return _NumberStep(
          key: const ValueKey('number'),
          amount: widget.amount,
          controller: _numberCtrl,
          error: _error,
          busy: _busy,
          onNext: _sendOtp,
        );
      case _Step.otp:
        return _OtpStep(
          key: const ValueKey('otp'),
          number: _numberCtrl.text.trim(),
          controller: _otpCtrl,
          error: _error,
          busy: _busy,
          onNext: _verifyOtp,
          onResend: _sendOtp,
          onBack: () => setState(() {
            _error = null;
            _busy = false;
            _step = _Step.number;
          }),
        );
      case _Step.pin:
        return _PinStep(
          key: const ValueKey('pin'),
          amount: widget.amount,
          controller: _pinCtrl,
          error: _error,
          onConfirm: _confirmPin,
          onBack: () => setState(() {
            _error = null;
            _step = _Step.otp;
          }),
        );
      case _Step.processing:
        return const _ProcessingStep(key: ValueKey('processing'));
      case _Step.success:
        return _SuccessStep(
          key: const ValueKey('success'),
          amount: widget.amount,
          txnId: _txnId,
          meterID: widget.meterID,
          phoneNumber: _numberCtrl.text.trim(),
        );
    }
  }
}

// ── Shared brand header used across steps ─────────────────────
class _AmountBanner extends StatelessWidget {
  final double amount;
  const _AmountBanner({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_JazzCashPaymentScreenState.jcRed,
                   _JazzCashPaymentScreenState.jcOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Bill Payment",
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Text(
            "Rs. ${amount.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 1 — Enter JazzCash number
// ─────────────────────────────────────────────────────────────
class _NumberStep extends StatelessWidget {
  final double amount;
  final TextEditingController controller;
  final String? error;
  final bool busy;
  final VoidCallback onNext;

  const _NumberStep({
    super.key,
    required this.amount,
    required this.controller,
    required this.error,
    required this.busy,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountBanner(amount: amount),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Enter your JazzCash number",
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "You'll receive a real SMS verification code on this number.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 20),
                _boxedField(
                  controller: controller,
                  hint: "03XXXXXXXXX",
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  maxLength: 11,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFFF5252), fontSize: 12)),
                ],
                const SizedBox(height: 28),
                _primaryButton(
                  busy ? "SENDING..." : "SEND CODE",
                  busy ? null : onNext,
                  loading: busy,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_outlined,
                        color: Colors.white24, size: 13),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Number verified via SMS — payment confirmation simulated",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 2 — OTP verification (REAL SMS)
// ─────────────────────────────────────────────────────────────
class _OtpStep extends StatelessWidget {
  final String number;
  final TextEditingController controller;
  final String? error;
  final bool busy;
  final VoidCallback onNext;
  final VoidCallback onResend;
  final VoidCallback onBack;

  const _OtpStep({
    super.key,
    required this.number,
    required this.controller,
    required this.error,
    required this.busy,
    required this.onNext,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Verification code",
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Enter the code sent via SMS to $number",
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 20),
            _boxedField(
              controller: controller,
              hint: "• • • • • •",
              icon: Icons.sms_outlined,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscure: true,
              center: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!,
                  style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12)),
            ],
            const SizedBox(height: 28),
            _primaryButton(
              busy ? "VERIFYING..." : "VERIFY",
              busy ? null : onNext,
              loading: busy,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: busy ? null : onBack,
                  child: const Text("Change number",
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
                TextButton(
                  onPressed: busy ? null : onResend,
                  child: const Text("Resend code",
                      style: TextStyle(
                          color: Color(0xFF00E5FF), fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 3 — MPIN entry (simulated payment confirmation)
// ─────────────────────────────────────────────────────────────
class _PinStep extends StatelessWidget {
  final double amount;
  final TextEditingController controller;
  final String? error;
  final VoidCallback onConfirm;
  final VoidCallback onBack;

  const _PinStep({
    super.key,
    required this.amount,
    required this.controller,
    required this.error,
    required this.onConfirm,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AmountBanner(amount: amount),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF69F0AE), size: 15),
                    const SizedBox(width: 6),
                    Text("Number verified",
                        style: TextStyle(
                            color: const Color(0xFF69F0AE).withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  "Enter your MPIN",
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Confirm this payment with your JazzCash MPIN.",
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 20),
                _boxedField(
                  controller: controller,
                  hint: "• • • •",
                  icon: Icons.lock_outline_rounded,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscure: true,
                  center: true,
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!,
                      style: const TextStyle(
                          color: Color(0xFFFF5252), fontSize: 12)),
                ],
                const SizedBox(height: 28),
                _primaryButton(
                    "PAY  Rs. ${amount.toStringAsFixed(0)}", onConfirm),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: onBack,
                    child: const Text("Back",
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 4 — Processing
// ─────────────────────────────────────────────────────────────
class _ProcessingStep extends StatelessWidget {
  const _ProcessingStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
              color: _JazzCashPaymentScreenState.jcOrange),
          const SizedBox(height: 22),
          Text(
            "Processing payment...",
            style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            "Please do not close this screen",
            style: TextStyle(color: Colors.white24, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// STEP 5 — Success (✅ Professional JazzCash-style RECEIPT)
// White ticket-style card, brand header, dashed perforation,
// captured via RepaintBoundary for Save (gallery) / Share.
// ─────────────────────────────────────────────────────────────
class _SuccessStep extends StatefulWidget {
  final double amount;
  final String txnId;
  final String meterID;
  final String phoneNumber;

  const _SuccessStep({
    super.key,
    required this.amount,
    required this.txnId,
    required this.meterID,
    required this.phoneNumber,
  });

  @override
  State<_SuccessStep> createState() => _SuccessStepState();
}

class _SuccessStepState extends State<_SuccessStep> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _savingBusy = false;
  bool _sharingBusy = false;

  DateTime get _now => DateTime.now();

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }

  String _fmtTime(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return "$h:${d.minute.toString().padLeft(2, '0')} $ampm";
  }

  String _maskPhone(String n) {
    if (n.length != 11) return n;
    return "${n.substring(0, 4)}-XXX${n.substring(7)}";
  }

  /// Receipt card ko PNG bytes mein capture karta hai (RepaintBoundary se) —
  /// koi extra "screenshot" package nahi chahiye, Flutter mein built-in hai.
  Future<Uint8List?> _captureReceipt() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  void _toast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : const Color(0xFF00E5FF),
    ));
  }

  // ── SAVE: device ki gallery mein PNG save karta hai ──
  Future<void> _onSave() async {
    if (_savingBusy) return;
    setState(() => _savingBusy = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) throw Exception("Capture failed");
      await Gal.putImageBytes(bytes, name: "grideye_receipt_${widget.txnId}");
      _toast("Receipt saved to gallery");
    } catch (e) {
      _toast("Couldn't save receipt — $e", isError: true);
    } finally {
      if (mounted) setState(() => _savingBusy = false);
    }
  }

  // ── SHARE: OS share sheet ke zariye PNG bhejta hai ──
  Future<void> _onShare() async {
    if (_sharingBusy) return;
    setState(() => _sharingBusy = true);
    try {
      final bytes = await _captureReceipt();
      if (bytes == null) throw Exception("Capture failed");
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/grideye_receipt_${widget.txnId}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: "GridEye — Bill payment of Rs. ${widget.amount.toStringAsFixed(0)} "
            "for meter ${widget.meterID} (Txn: ${widget.txnId})",
      );
    } catch (e) {
      _toast("Couldn't share receipt — $e", isError: true);
    } finally {
      if (mounted) setState(() => _sharingBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 36, 20, 24),
        child: Column(
          children: [
            Text(
              "Payment Successful",
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 22),

            // ✅ RepaintBoundary — yehi hissa Save/Share mein image banta hai
            RepaintBoundary(
              key: _receiptKey,
              child: _ReceiptCard(
                amount: widget.amount,
                txnId: widget.txnId,
                meterID: widget.meterID,
                phoneMasked: _maskPhone(widget.phoneNumber),
                date: _fmtDate(_now),
                time: _fmtTime(_now),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _savingBusy ? null : _onSave,
                    icon: _savingBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white54),
                          )
                        : const Icon(Icons.download_rounded,
                            size: 18, color: Colors.white70),
                    label: Text(_savingBusy ? "Saving..." : "Save",
                        style: const TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sharingBusy ? null : _onShare,
                    icon: _sharingBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF00E5FF)),
                          )
                        : const Icon(Icons.share_rounded,
                            size: 18, color: Color(0xFF00E5FF)),
                    label: Text(_sharingBusy ? "Sharing..." : "Share",
                        style: const TextStyle(color: Color(0xFF00E5FF))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(
                          color: Color(0xFF00E5FF), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("DONE",
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// RECEIPT CARD — white ticket-style, JazzCash brand header,
// dashed perforation, transaction details, footer. This whole
// widget is what gets captured for Save/Share.
// ─────────────────────────────────────────────────────────────
class _ReceiptCard extends StatelessWidget {
  final double amount;
  final String txnId;
  final String meterID;
  final String phoneMasked;
  final String date;
  final String time;

  const _ReceiptCard({
    required this.amount,
    required this.txnId,
    required this.meterID,
    required this.phoneMasked,
    required this.date,
    required this.time,
  });

  static const Color jcRed = _JazzCashPaymentScreenState.jcRed;
  static const Color jcOrange = _JazzCashPaymentScreenState.jcOrange;
  static const Color ink = Color(0xFF1A1A1A);
  static const Color subInk = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Brand header ──
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [jcRed, jcOrange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Text(
                        "JC",
                        style: TextStyle(
                          color: jcRed,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      "JazzCash",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.white, size: 13),
                      SizedBox(width: 4),
                      Text(
                        "PAID",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Amount ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              children: [
                const Text(
                  "AMOUNT PAID",
                  style: TextStyle(
                    color: subInk,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Rs. ${amount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: ink,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$date  •  $time",
                  style: const TextStyle(color: subInk, fontSize: 11.5),
                ),
              ],
            ),
          ),

          // ── Dashed perforation ──
          const _DashedDivider(),

          // ── Transaction details ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              children: [
                _detailRow("Transaction ID", txnId, mono: true),
                _detailRow("Meter Number", meterID, mono: true),
                _detailRow("Paid From", phoneMasked),
                _detailRow("Payment Method", "JazzCash Mobile Wallet"),
                _detailRow("Status", "Completed",
                    valueColor: const Color(0xFF1B8A5A)),
              ],
            ),
          ),

          const _DashedDivider(),

          // ── Footer ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Color(0xFF00E5FF), size: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                RichText(
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(
                        text: "Grid",
                        style: TextStyle(color: Color(0xFF0D1B2A)),
                      ),
                      TextSpan(
                        text: "Eye",
                        style: TextStyle(color: Color(0xFF00A9BD)),
                      ),
                      TextSpan(
                        text: " Power Distribution",
                        style: TextStyle(color: ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String k, String v,
      {bool mono = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: subInk, fontSize: 12.5)),
          Text(
            v,
            style: TextStyle(
              color: valueColor ?? ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple dashed horizontal line (like a receipt's tear/perforation line).
class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 6.0;
          const dashSpace = 4.0;
          final count =
              (constraints.maxWidth / (dashWidth + dashSpace)).floor();
          return Row(
            children: List.generate(count, (_) {
              return Padding(
                padding: const EdgeInsets.only(right: dashSpace),
                child: Container(
                  width: dashWidth,
                  height: 1,
                  color: const Color(0xFFDDDDDD),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────
Widget _boxedField({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required TextInputType keyboardType,
  required int maxLength,
  bool obscure = false,
  bool center = false,
}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0D1B2A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      obscuringCharacter: '●',
      textAlign: center ? TextAlign.center : TextAlign.start,
      maxLength: maxLength,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: TextStyle(
        color: Colors.white,
        fontSize: center ? 20 : 15,
        letterSpacing: center ? 8 : 1,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: center ? null : Icon(icon, color: Colors.white38, size: 18),
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    ),
  );
}

Widget _primaryButton(String label, VoidCallback? onTap, {bool loading = false}) {
  return SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _JazzCashPaymentScreenState.jcRed,
        foregroundColor: Colors.white,
        disabledBackgroundColor:
            _JazzCashPaymentScreenState.jcRed.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.4),
            )
          : Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, letterSpacing: 0.6)),
    ),
  );
}