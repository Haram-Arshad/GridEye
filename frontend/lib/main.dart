import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'splash_screen.dart';
import 'admin_dashboard.dart';
import 'consumer_portal.dart';
import 'meter_id_input.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(GridEyeApp());
}

class GridEyeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GridEye',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF0D1B2A),
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => GridEyeLogin(),
        '/adminDashboard': (context) => AdminDashboard(),
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED DESIGN CONSTANTS — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _GE {
  static const bgDeep   = Color(0xFF070E17);
  static const bgMid    = Color(0xFF0D1B2A);
  static const bgLight  = Color(0xFF102240);
  static const cyan     = Color(0xFF00E5FF);
  static const navyBlue = Color(0xFF0055AA);
  static const deepNavy = Color(0xFF051428);
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGO — 100% unchanged
// ─────────────────────────────────────────────────────────────────────────────
class GridEyeLogoMark extends StatefulWidget {
  final double size;
  final double progress;
  final double glowOpacity;

  const GridEyeLogoMark({
    Key? key,
    required this.size,
    this.progress = 1.0,
    this.glowOpacity = 0.20,
  }) : super(key: key);

  @override
  State<GridEyeLogoMark> createState() => _GridEyeLogoMarkState();
}

class _GridEyeLogoMarkState extends State<GridEyeLogoMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _ringCtrl;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _GE.cyan.withOpacity(widget.glowOpacity),
                Colors.transparent,
              ]),
            ),
          ),
          Container(
            width: widget.size * 0.80,
            height: widget.size * 0.80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _GE.deepNavy.withOpacity(0.55),
              border: Border.all(color: _GE.cyan.withOpacity(0.18), width: 1.0),
            ),
          ),
          Container(
            width: widget.size * 0.68,
            height: widget.size * 0.68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: _GE.cyan.withOpacity(0.08), width: 0.8),
            ),
          ),
          AnimatedBuilder(
            animation: _ringCtrl,
            builder: (_, __) => SizedBox(
              width: widget.size * 0.575,
              height: widget.size * 0.575,
              child: CustomPaint(
                painter: _GridEyeLogoPainter(
                  progress: widget.progress,
                  cyanColor: _GE.cyan,
                  navyColor: _GE.navyBlue,
                  deepNavy: _GE.deepNavy,
                  glowOpacity: widget.glowOpacity,
                  ringPhase: _ringCtrl.value,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridEyeLogoPainter extends CustomPainter {
  final double progress;
  final Color cyanColor;
  final Color navyColor;
  final Color deepNavy;
  final double glowOpacity;
  final double ringPhase;

  const _GridEyeLogoPainter({
    required this.progress,
    required this.cyanColor,
    required this.navyColor,
    required this.deepNavy,
    required this.glowOpacity,
    this.ringPhase = 0.0,
  });

  void _drawPathSegment(Canvas canvas, Path path, Paint paint, double t) {
    if (t <= 0) return;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * t.clamp(0.0, 1.0)), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final leftX  = cx - size.width * 0.47;
    final rightX = cx + size.width * 0.47;
    final arcH   = size.height * 0.36;

    final arcPaint = Paint()
      ..color = cyanColor.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final arcInnerPaint = Paint()
      ..color = cyanColor.withOpacity(0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = deepNavy.withOpacity(0.88)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = cyanColor.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.55;

    final crosshairPaint = Paint()
      ..color = cyanColor.withOpacity(0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final tickPaint = Paint()
      ..color = cyanColor.withOpacity(0.60)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final eyePath = Path()
      ..moveTo(leftX, cy)
      ..quadraticBezierTo(cx, cy - arcH, rightX, cy)
      ..quadraticBezierTo(cx, cy + arcH, leftX, cy)
      ..close();

    if (progress > 0.0) {
      final p = (progress / 0.35).clamp(0.0, 1.0);
      fillPaint.color = deepNavy.withOpacity(0.88 * p);
      canvas.save();
      canvas.clipPath(eyePath);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), fillPaint);
      if (p > 0.3) {
        final gp = ((p - 0.3) / 0.7).clamp(0.0, 1.0);
        gridPaint.color = cyanColor.withOpacity(0.22 * gp);
        final spacing = size.width * 0.16;
        for (double x = leftX; x <= rightX + 1; x += spacing) {
          canvas.drawLine(Offset(x, cy - arcH), Offset(x, cy + arcH), gridPaint);
        }
        for (double y = cy - arcH; y <= cy + arcH + 1; y += spacing) {
          canvas.drawLine(Offset(leftX, y), Offset(rightX, y), gridPaint);
        }
      }
      canvas.restore();
    }

    final topP = (progress / 0.42).clamp(0.0, 1.0);
    if (topP > 0) {
      final topPath = Path()
        ..moveTo(leftX, cy)
        ..quadraticBezierTo(cx, cy - arcH, rightX, cy);
      _drawPathSegment(canvas, topPath, arcPaint, topP);
      if (topP > 0.5) {
        final innerTop = Path()
          ..moveTo(leftX + 6, cy - 2)
          ..quadraticBezierTo(cx, cy - arcH * 0.55, rightX - 6, cy - 2);
        _drawPathSegment(canvas, innerTop, arcInnerPaint,
            ((topP - 0.5) / 0.5).clamp(0.0, 1.0));
      }
    }

    final botP = ((progress - 0.18) / 0.42).clamp(0.0, 1.0);
    if (botP > 0) {
      final botPath = Path()
        ..moveTo(leftX, cy)
        ..quadraticBezierTo(cx, cy + arcH, rightX, cy);
      _drawPathSegment(canvas, botPath, arcPaint, botP);
      if (botP > 0.5) {
        final innerBot = Path()
          ..moveTo(leftX + 6, cy + 2)
          ..quadraticBezierTo(cx, cy + arcH * 0.55, rightX - 6, cy + 2);
        _drawPathSegment(canvas, innerBot, arcInnerPaint,
            ((botP - 0.5) / 0.5).clamp(0.0, 1.0));
      }
    }

    final irisP = ((progress - 0.45) / 0.27).clamp(0.0, 1.0);
    if (irisP > 0) {
      final irisR1 = size.width * 0.195;
      final irisR2 = size.width * 0.130;
      final irisR3 = size.width * 0.078;
      final outerIrisPaint = Paint()
        ..color = cyanColor.withOpacity(0.62 * irisP)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6;
      canvas.drawCircle(Offset(cx, cy), irisR1, outerIrisPaint);
      if (irisP > 0.35) {
        final innerIrisPaint = Paint()
          ..color = navyColor.withOpacity(0.70 * ((irisP - 0.35) / 0.65))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset(cx, cy), irisR2, innerIrisPaint);
      }
      if (irisP > 0.60) {
        final midIrisPaint = Paint()
          ..color = cyanColor.withOpacity(0.28 * ((irisP - 0.60) / 0.40))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7;
        canvas.drawCircle(Offset(cx, cy), irisR3, midIrisPaint);
      }
      canvas.drawCircle(Offset(cx, cy), irisR1 - 0.8,
          Paint()..color = deepNavy.withOpacity(0.50 * irisP)..style = PaintingStyle.fill);
    }

    final xhP = ((progress - 0.62) / 0.20).clamp(0.0, 1.0);
    if (xhP > 0) {
      crosshairPaint.color = cyanColor.withOpacity(0.82 * xhP);
      final gap = size.width * 0.135;
      final arm = size.width * 0.105;
      canvas.drawLine(Offset(cx - gap - arm, cy), Offset(cx - gap, cy), crosshairPaint);
      canvas.drawLine(Offset(cx + gap, cy), Offset(cx + gap + arm, cy), crosshairPaint);
      canvas.drawLine(Offset(cx, cy - gap - arm), Offset(cx, cy - gap), crosshairPaint);
      canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + gap + arm), crosshairPaint);
    }

    final pupilP = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
    if (pupilP > 0) {
      final segR = size.width * 0.155;
      const gapRad = 0.10;
      const quarterSweep = (math.pi / 2) - gapRad;
      const segColors = [
        Color(0xFF00E5FF),
        Color(0xFFFFAB40),
        Color(0xFF69F0AE),
        Color(0xFFFF5252),
      ];
      final activeIdx = (ringPhase * 4).floor() % 4;
      final stepProgress = (ringPhase * 4) % 1.0;
      final highlight = math.sin(stepProgress * math.pi).clamp(0.0, 1.0);
      final segStrokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      final segGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round;
      final startAngles = [
        -math.pi / 2 + gapRad / 2,
         0.0         + gapRad / 2,
         math.pi / 2 + gapRad / 2,
         math.pi     + gapRad / 2,
      ];
      final segRect = Rect.fromCircle(center: Offset(cx, cy), radius: segR);
      for (int i = 0; i < 4; i++) {
        final isActive = i == activeIdx;
        final color = segColors[i];
        if (isActive) {
          segGlowPaint.color = color.withOpacity(0.22 * highlight * pupilP);
          canvas.drawArc(segRect, startAngles[i], quarterSweep, false, segGlowPaint);
          segStrokePaint.color = color.withOpacity((0.55 + 0.40 * highlight) * pupilP);
          canvas.drawArc(segRect, startAngles[i], quarterSweep, false, segStrokePaint);
        } else {
          segStrokePaint.color = color.withOpacity(0.18 * pupilP);
          canvas.drawArc(segRect, startAngles[i], quarterSweep, false, segStrokePaint);
        }
      }
      final pupilR = size.width * 0.072;
      canvas.drawCircle(Offset(cx, cy), pupilR * 1.7,
          Paint()..color = cyanColor.withOpacity(0.30 * pupilP)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
      canvas.drawCircle(Offset(cx, cy), pupilR,
          Paint()..color = deepNavy.withOpacity(0.90 * pupilP)..style = PaintingStyle.fill);
      canvas.drawCircle(Offset(cx, cy), pupilR,
          Paint()..color = cyanColor.withOpacity(0.92 * pupilP)
            ..style = PaintingStyle.stroke..strokeWidth = 2.0);
      canvas.drawCircle(Offset(cx, cy), pupilR * 0.52,
          Paint()..color = cyanColor.withOpacity(0.95 * pupilP)..style = PaintingStyle.fill);
      canvas.drawCircle(
        Offset(cx + size.width * 0.024, cy - size.height * 0.024),
        size.width * 0.026,
        Paint()..color = Colors.white.withOpacity(0.58 * pupilP)..style = PaintingStyle.fill,
      );
    }

    final tipsP = ((progress - 0.86) / 0.14).clamp(0.0, 1.0);
    if (tipsP > 0) {
      tickPaint.color = cyanColor.withOpacity(0.60 * tipsP);
      final tickH = size.height * 0.10;
      canvas.drawLine(Offset(leftX, cy - tickH), Offset(leftX, cy + tickH), tickPaint);
      canvas.drawLine(Offset(rightX, cy - tickH), Offset(rightX, cy + tickH), tickPaint);
      tickPaint.color = cyanColor.withOpacity(0.30 * tipsP);
      tickPaint.strokeWidth = 1.0;
      canvas.drawLine(Offset(leftX - 5, cy), Offset(leftX + 5, cy), tickPaint);
      canvas.drawLine(Offset(rightX - 5, cy), Offset(rightX + 5, cy), tickPaint);
    }
  }

  @override
  bool shouldRepaint(_GridEyeLogoPainter old) =>
      old.progress != progress || old.glowOpacity != glowOpacity ||
      old.ringPhase != ringPhase;
}

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _GEBackground extends StatelessWidget {
  const _GEBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(children: [
      Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.25),
            radius: 1.05,
            colors: [_GE.bgLight, _GE.bgMid, _GE.bgDeep],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
      ),
      CustomPaint(
        size: Size(size.width, size.height),
        painter: _GridTexturePainter(),
      ),
      Positioned(
        top: -size.width * 0.25,
        right: -size.width * 0.20,
        child: Container(
          width: size.width * 0.65,
          height: size.width * 0.65,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _GE.cyan.withOpacity(0.08),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      Positioned(
        bottom: -size.width * 0.18,
        left: -size.width * 0.15,
        child: Container(
          width: size.width * 0.50,
          height: size.width * 0.50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              _GE.navyBlue.withOpacity(0.12),
              Colors.transparent,
            ]),
          ),
        ),
      ),
    ]);
  }
}

class _GridTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _GE.cyan.withOpacity(0.038)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const spacing = 36.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_GridTexturePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGIN SCREEN — logic unchanged, font fixes only
// ─────────────────────────────────────────────────────────────────────────────
class GridEyeLogin extends StatefulWidget {
  @override
  _GridEyeLoginState createState() => _GridEyeLoginState();
}

class _GridEyeLoginState extends State<GridEyeLogin>
    with TickerProviderStateMixin {

  // ── LOGIC — UNTOUCHED ─────────────────────────────────────────────────────
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscure   = true;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email:    _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'] ?? "consumer";
        String mID  = userDoc['meterID'] ?? "";
        if (role == 'multi') {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => RoleSelectionScreen(meterID: mID)));
        } else if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/adminDashboard');
        } else {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => MeterIdInputScreen()));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.toString()}"),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _formOpacity;
  late Animation<Offset>   _formSlide;
  late Animation<double>   _pulseOpacity;

  final FocusNode _emailFocus    = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))..forward();
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _formOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.40, 1.0, curve: Curves.easeOut)));
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.25), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.38, 0.90, curve: Curves.easeOutCubic)));
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.08, end: 0.22).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _emailFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GE.bgDeep,
      body: Stack(children: [
        const _GEBackground(),
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(children: [
              const SizedBox(height: 52),

              // Logo block — unchanged
              AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, __) => Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Column(children: [
                      AnimatedBuilder(
                        animation: _pulseOpacity,
                        builder: (_, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 130, height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(colors: [
                                  _GE.cyan.withOpacity(_pulseOpacity.value),
                                  Colors.transparent,
                                ]),
                              ),
                            ),
                            child!,
                          ],
                        ),
                        child: const GridEyeLogoMark(
                            size: 140, progress: 1.0, glowOpacity: 0.18),
                      ),
                      const SizedBox(height: 20),
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                            text: 'GRID',
                            style: GoogleFonts.orbitron(
                              fontSize: 30, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: 4,
                            ),
                          ),
                          TextSpan(
                            text: 'EYE',
                            style: GoogleFonts.orbitron(
                              fontSize: 30, fontWeight: FontWeight.w800,
                              color: _GE.cyan, letterSpacing: 4,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 48, height: 1.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(1),
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            _GE.cyan.withOpacity(0.7),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'SMART GRID MONITORING SYSTEM',
                        style: GoogleFonts.rajdhani(
                          fontSize: 10.5, fontWeight: FontWeight.w600,
                          color: _GE.cyan.withOpacity(0.65), letterSpacing: 2.5,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),

              const SizedBox(height: 52),

              // Form block
              AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) => FadeTransition(
                  opacity: _formOpacity,
                  child: SlideTransition(position: _formSlide, child: child),
                ),
                child: Column(children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SYSTEM ACCESS',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _GE.cyan.withOpacity(0.70), letterSpacing: 2.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _GETextField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hint: 'Corporate Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  _GETextField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscure,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: _GE.cyan.withOpacity(0.5),
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // ── AUTHENTICATE BUTTON — font changed to match consumer cards ──
                  _GEPrimaryButton(
                    label: 'AUTHENTICATE',
                    isLoading: _isLoading,
                    onTap: _isLoading ? null : _handleLogin,
                  ),

                  const SizedBox(height: 36),

                  Text(
                    'v1.0.0  ·  SECURE ACCESS',
                    style: GoogleFonts.rajdhani(
                      fontSize: 10, letterSpacing: 2.5,
                      color: Colors.white.withOpacity(0.84),
                    ),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE SELECTION SCREEN — logic unchanged, font fixes only
// ─────────────────────────────────────────────────────────────────────────────
class RoleSelectionScreen extends StatefulWidget {
  final String meterID;
  RoleSelectionScreen({required this.meterID});

  @override
  _RoleSelectionScreenState createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {

  late AnimationController _entryCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double>   _logoOpacity;
  late Animation<double>   _logoScale;
  late Animation<double>   _card0Opacity;
  late Animation<Offset>   _card0Slide;
  late Animation<double>   _card1Opacity;
  late Animation<Offset>   _card1Slide;
  late Animation<double>   _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))..forward();
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.0, 0.40, curve: Curves.easeOut)));
    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.0, 0.55, curve: Curves.elasticOut)));
    _card0Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.38, 0.72, curve: Curves.easeOut)));
    _card0Slide = Tween<Offset>(
      begin: const Offset(0, 0.30), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.35, 0.70, curve: Curves.easeOutCubic)));
    _card1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryCtrl,
          curve: const Interval(0.52, 0.88, curve: Curves.easeOut)));
    _card1Slide = Tween<Offset>(
      begin: const Offset(0, 0.30), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOutCubic)));
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.07, end: 0.20).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _GE.bgDeep,
      body: Stack(children: [
        const _GEBackground(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Logo — unchanged
                AnimatedBuilder(
                  animation: Listenable.merge([_entryCtrl, _pulseCtrl]),
                  builder: (_, __) => Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Column(children: [
                        Stack(alignment: Alignment.center, children: [
                          Container(
                            width: 116, height: 116,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                _GE.cyan.withOpacity(_pulseOpacity.value),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                          const GridEyeLogoMark(
                              size: 140, progress: 1.0, glowOpacity: 0.16),
                        ]),
                        const SizedBox(height: 20),
                        RichText(
                          text: TextSpan(children: [
                            TextSpan(
                              text: 'GRID',
                              style: GoogleFonts.orbitron(
                                fontSize: 26, fontWeight: FontWeight.w800,
                                color: Colors.white, letterSpacing: 4,
                              ),
                            ),
                            TextSpan(
                              text: 'EYE',
                              style: GoogleFonts.orbitron(
                                fontSize: 26, fontWeight: FontWeight.w800,
                                color: _GE.cyan, letterSpacing: 4,
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          width: 40, height: 1.0,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            gradient: LinearGradient(colors: [
                              Colors.transparent,
                              _GE.cyan.withOpacity(0.6),
                              Colors.transparent,
                            ]),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'SELECT ACCESS LEVEL',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: _GE.cyan.withOpacity(0.68), letterSpacing: 2.5,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Admin card
                AnimatedBuilder(
                  animation: _entryCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _card0Opacity,
                    child: SlideTransition(position: _card0Slide, child: child),
                  ),
                  child: _GERoleCard(
                    title: 'Utility Admin',
                    subtitle: 'Monitor Grid & Theft Alerts',
                    icon: Icons.admin_panel_settings_outlined,
                    accentColor: _GE.cyan,
                    onTap: () => Navigator.pushNamed(context, '/adminDashboard'),
                  ),
                ),

                const SizedBox(height: 16),

                // Consumer card
                AnimatedBuilder(
                  animation: _entryCtrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _card1Opacity,
                    child: SlideTransition(position: _card1Slide, child: child),
                  ),
                  child: _GERoleCard(
                    title: 'Consumer Portal',
                    subtitle: 'View Usage & Report Faults',
                    icon: Icons.bolt_outlined,
                    accentColor: const Color(0xFF69F0AE),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => MeterIdInputScreen())),
                  ),
                ),

                const SizedBox(height: 48),

                Text(
                  'GRIDEYE  ·  SECURE ROLE SELECTION',
                  style: GoogleFonts.rajdhani(
                    fontSize: 9.5, letterSpacing: 2.5,
                    color: const Color.fromARGB(255, 252, 249, 249).withOpacity(0.90),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TEXT FIELD — unchanged
// ─────────────────────────────────────────────────────────────────────────────
class _GETextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  const _GETextField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffixIcon,
  });

  @override
  State<_GETextField> createState() => _GETextFieldState();
}

class _GETextFieldState extends State<_GETextField> {
  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? _GE.cyan.withOpacity(0.55) : _GE.cyan.withOpacity(0.12),
          width: focused ? 1.4 : 1.0,
        ),
        boxShadow: focused
            ? [BoxShadow(color: _GE.cyan.withOpacity(0.10), blurRadius: 14, spreadRadius: 1)]
            : [],
        color: focused ? _GE.cyan.withOpacity(0.04) : Colors.white.withOpacity(0.04),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        style: GoogleFonts.rajdhani(
          color: Colors.white.withOpacity(0.92),
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(widget.icon,
              color: focused ? _GE.cyan : _GE.cyan.withOpacity(0.55), size: 20),
          suffixIcon: widget.suffixIcon,
          hintText: widget.hint,
          hintStyle: GoogleFonts.rajdhani(
            color: Colors.white.withOpacity(0.38),
            fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.3,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRIMARY BUTTON
// CHANGE: label text → plain TextStyle matching consumer card font (w700, no orbitron)
// ─────────────────────────────────────────────────────────────────────────────
class _GEPrimaryButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  const _GEPrimaryButton({
    required this.label,
    required this.isLoading,
    this.onTap,
  });

  @override
  State<_GEPrimaryButton> createState() => _GEPrimaryButtonState();
}

class _GEPrimaryButtonState extends State<_GEPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 100));
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) { _pressCtrl.reverse(); widget.onTap?.call(); },
      onTapCancel: () => _pressCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (_, child) => Transform.scale(scale: _pressScale.value, child: child),
        child: Container(
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              colors: [Color(0xFF00E5FF), Color(0xFF007A99)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: _GE.cyan.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5),
                  )
                : Text(
                    widget.label,
                    // ── CHANGED: plain TextStyle — same as consumer card labels ──
                    // fontFamily: Roboto (Material default), w700, letterSpacing 1.5
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE CARD
// CHANGE: title keeps orbitron (GridEye font is correct per requirement)
//         subtitle → plain TextStyle matching consumer card subtitle font
// ─────────────────────────────────────────────────────────────────────────────
class _GERoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _GERoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_GERoleCard> createState() => _GERoleCardState();
}

class _GERoleCardState extends State<_GERoleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _pressScale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 120));
    _pressScale = Tween<double>(begin: 1.0, end: 0.972).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _pressCtrl.forward(); setState(() => _pressed = true); },
      onTapUp: (_) {
        _pressCtrl.reverse();
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () { _pressCtrl.reverse(); setState(() => _pressed = false); },
      child: AnimatedBuilder(
        animation: _pressScale,
        builder: (_, child) => Transform.scale(scale: _pressScale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _pressed
                ? widget.accentColor.withOpacity(0.06)
                : Colors.white.withOpacity(0.04),
            border: Border.all(
              color: _pressed
                  ? widget.accentColor.withOpacity(0.40)
                  : widget.accentColor.withOpacity(0.20),
              width: _pressed ? 1.5 : 1.0,
            ),
            boxShadow: _pressed
                ? [BoxShadow(
                    color: widget.accentColor.withOpacity(0.10),
                    blurRadius: 16, spreadRadius: 0, offset: const Offset(0, 4))]
                : [],
          ),
          child: Row(children: [

            // Icon circle — unchanged
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withOpacity(0.09),
                border: Border.all(
                    color: widget.accentColor.withOpacity(0.28), width: 1.0),
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 26),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title — orbitron kept (GridEye theme font, correct)
                  Text(
                    widget.title,
                    style: GoogleFonts.orbitron(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  // ── CHANGED: subtitle → plain TextStyle matching consumer card ──
                  // Same as _AnimatedActionTile subtitle: color 0xFF6B7F99, 12px, w400
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF8899AA),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow — unchanged
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accentColor.withOpacity(0.08),
                border: Border.all(
                    color: widget.accentColor.withOpacity(0.22), width: 0.8),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.accentColor.withOpacity(0.65), size: 13),
            ),
          ]),
        ),
      ),
    );
  }
}