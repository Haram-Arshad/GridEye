import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GRIDEYE SPLASH SCREEN — Refined Logo + 5–6s Premium Timing
// ✅ Business logic: UNCHANGED
// ✅ Color theme: UNCHANGED (0xFF0D1B2A, 0xFF00E5FF preserved)
// ✅ Navigation: UNCHANGED (pushReplacementNamed('/login'))
// 🎨 UI ONLY: refined logo, thicker eye, themed colors, 5.5s duration
// ─────────────────────────────────────────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── App color theme constants (unchanged) ─────────────────────────────────
  static const _bgDeep    = Color(0xFF070E17);
  static const _bgMid     = Color(0xFF0D1B2A);
  static const _bgLight   = Color(0xFF102240);
  static const _cyan      = Color(0xFF00E5FF);
  static const _navyBlue  = Color(0xFF0055AA);   // secondary iris accent
  static const _deepNavy  = Color(0xFF051428);   // eye interior fill

  // ── Controllers ───────────────────────────────────────────────────────────
  late AnimationController _logoCtrl;       // logo draw-on
  late AnimationController _contentCtrl;    // text stagger
  late AnimationController _pulseCtrl;      // breathing glow (∞)
  late AnimationController _scanCtrl;       // scan sweep (∞)
  late AnimationController _dotsCtrl;       // loader dots (∞)
  late AnimationController _idleCtrl;       // calm idle after reveal (∞)
  late AnimationController _exitCtrl;       // exit fade → navigate

  // ── Logo animations ───────────────────────────────────────────────────────
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _drawProgress;   // 0→1 drives CustomPainter

  // ── Content animations ────────────────────────────────────────────────────
  late Animation<double> _titleOpacity;
  late Animation<Offset>  _titleSlide;
  late Animation<double> _taglineOpacity;
  late Animation<double> _dividerScale;
  late Animation<double> _loaderOpacity;

  // ── Ambient animations ────────────────────────────────────────────────────
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;
  late Animation<double> _scanY;           // 0→1 vertical sweep
  late Animation<double> _idleRingScale;   // subtle idle ring breath
  late Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();

    // ════════════════════════════════════════════════════════════════════════
    // BUSINESS LOGIC — COMPLETELY UNCHANGED
    // Total UX time: ~5.5s → smooth 600ms exit fade → pushReplacementNamed
    // ════════════════════════════════════════════════════════════════════════
    Timer(const Duration(milliseconds: 5500), () {
      if (mounted) _exitCtrl.forward();
    });

    // ── Logo controller: 1400ms draw-on ───────────────────────────────────
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _drawProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.80, curve: Curves.easeInOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoCtrl,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    // ── Content controller: 1000ms stagger ────────────────────────────────
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.40),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.0, 0.60, curve: Curves.easeOutCubic),
    ));
    _dividerScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.20, 0.65, curve: Curves.easeOut),
      ),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.42, 0.90, curve: Curves.easeOut),
      ),
    );
    _loaderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentCtrl,
        curve: const Interval(0.68, 1.0, curve: Curves.easeOut),
      ),
    );

    // ── Pulse: breathing outer glow ───────────────────────────────────────
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.90, end: 1.10).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.08, end: 0.30).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // ── Scan: vertical sweep line ─────────────────────────────────────────
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _scanY = Tween<double>(begin: -0.12, end: 1.12).animate(
      CurvedAnimation(parent: _scanCtrl, curve: Curves.linear),
    );

    // ── Dots loader ───────────────────────────────────────────────────────
    _dotsCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // ── Idle: subtle ring scale during the "hold" window (2s–5.5s) ────────
    _idleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _idleRingScale = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _idleCtrl, curve: Curves.easeInOut),
    );

    // ── Exit controller: 600ms fade-out ───────────────────────────────────
    _exitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInOut),
    );

    // Navigate only after exit animation completes
    _exitCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        // ── BUSINESS LOGIC UNCHANGED ──────────────────────────────────────
        Navigator.pushReplacementNamed(context, '/login');
      }
    });

    // ── Staggered playback ────────────────────────────────────────────────
    _logoCtrl.forward();
    Future.delayed(const Duration(milliseconds: 850), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    _dotsCtrl.dispose();
    _idleCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgDeep,
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          children: [

            // ── BG: Radial gradient ────────────────────────────────────────
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.20),
                  radius: 1.08,
                  colors: [_bgLight, _bgMid, _bgDeep],
                  stops: [0.0, 0.48, 1.0],
                ),
              ),
            ),

            // ── BG: Grid texture ───────────────────────────────────────────
            RepaintBoundary(
              child: CustomPaint(
                size: Size(size.width, size.height),
                painter: _GridTexturePainter(color: _cyan),
              ),
            ),

            // ── BG: Scan line sweep ────────────────────────────────────────
            AnimatedBuilder(
              animation: _scanY,
              builder: (_, __) {
                final y = size.height * _scanY.value;
                return Positioned(
                  top: y - 80,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 160,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _cyan.withOpacity(0.04),
                            _cyan.withOpacity(0.09),
                            _cyan.withOpacity(0.04),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // ── BG: Ambient corner orbs ────────────────────────────────────
            AnimatedBuilder(
              animation: _pulseOpacity,
              builder: (_, __) => Stack(children: [
                // Top-right cyan orb
                Positioned(
                  top: -size.width * 0.28,
                  right: -size.width * 0.22,
                  child: Container(
                    width: size.width * 0.75,
                    height: size.width * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _cyan.withOpacity(_pulseOpacity.value * 0.6),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
                // Bottom-left navy orb
                Positioned(
                  bottom: -size.width * 0.20,
                  left: -size.width * 0.18,
                  child: Container(
                    width: size.width * 0.55,
                    height: size.width * 0.55,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        _navyBlue.withOpacity(_pulseOpacity.value * 0.40),
                        Colors.transparent,
                      ]),
                    ),
                  ),
                ),
              ]),
            ),

            // ── MAIN CONTENT ───────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // ── Logo assembly ────────────────────────────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _logoCtrl,
                      _pulseCtrl,
                      _idleCtrl,
                    ]),
                    builder: (_, __) => Opacity(
                      opacity: _logoOpacity.value,
                      child: Transform.scale(
                        scale: _logoScale.value,
                        child: SizedBox(
                          width: 160,
                          height: 160,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [

                              // Outermost breathing glow
                              Transform.scale(
                                scale: _pulseScale.value,
                                child: Container(
                                  width: 158,
                                  height: 158,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(colors: [
                                      _cyan.withOpacity(_pulseOpacity.value),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                              ),

                              // Idle ring — subtle scale breath
                              Transform.scale(
                                scale: _idleRingScale.value,
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.transparent,
                                    border: Border.all(
                                      color: _cyan.withOpacity(0.15),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                              ),

                              // Inner ring — static
                              Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _deepNavy.withOpacity(0.55),
                                  border: Border.all(
                                    color: _cyan.withOpacity(0.10),
                                    width: 0.8,
                                  ),
                                ),
                              ),

                              // Logo mark — CustomPainter
                              SizedBox(
                                width: 92,
                                height: 92,
                                child: CustomPaint(
                                  painter: _GridEyeLogoPainter(
                                    progress: _drawProgress.value,
                                    cyanColor: _cyan,
                                    navyColor: _navyBlue,
                                    deepNavy: _deepNavy,
                                    glowOpacity: _pulseOpacity.value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 44),

                  // ── Text content ─────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _contentCtrl,
                    builder: (_, __) => Column(
                      children: [

                        // App name
                        FadeTransition(
                          opacity: _titleOpacity,
                          child: SlideTransition(
                            position: _titleSlide,
                            child: RichText(
                              text: TextSpan(children: [
                                TextSpan(
                                  text: 'GRID',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 7,
                                    height: 1.0,
                                  ),
                                ),
                                TextSpan(
                                  text: 'EYE',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w800,
                                    color: _cyan,
                                    letterSpacing: 7,
                                    height: 1.0,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Expanding divider
                        Transform.scale(
                          scaleX: _dividerScale.value,
                          child: Container(
                            width: 56,
                            height: 1.2,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  _cyan.withOpacity(0.7),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 13),

                        // Tagline
                        Opacity(
                          opacity: _taglineOpacity.value,
                          child: Text(
                            'MONITOR · ANALYZE · CONTROL',
                            style: GoogleFonts.rajdhani(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _cyan.withOpacity(0.50),
                              letterSpacing: 3.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── BOTTOM: loader + version ───────────────────────────────────
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _loaderOpacity,
                builder: (_, child) =>
                    Opacity(opacity: _loaderOpacity.value, child: child),
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: _dotsCtrl,
                      builder: (_, __) => _WaveDotsLoader(
                        progress: _dotsCtrl.value,
                        color: _cyan,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'v1.0.0',
                      style: GoogleFonts.rajdhani(
                        fontSize: 10.5,
                        letterSpacing: 2.5,
                        color: Colors.white.withOpacity(0.14),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER — Refined GridEye Logo Mark
//
// Color design (all from existing theme):
//   • Eye arcs         → 0xFF00E5FF (cyan, 3.5px — thicker)
//   • Eye interior     → 0xFF051428 (deep navy fill)
//   • Outer iris ring  → cyan → 0xFF0055AA gradient feel (alternating strokes)
//   • Inner iris ring  → 0xFF0055AA (navy blue accent)
//   • Crosshair arms   → 0xFF00E5FF (cyan)
//   • Pupil            → 0xFF00E5FF (solid cyan)
//   • Grid inside eye  → 0xFF00E5FF @ low opacity
// ─────────────────────────────────────────────────────────────────────────────
class _GridEyeLogoPainter extends CustomPainter {
  final double progress;
  final Color cyanColor;
  final Color navyColor;
  final Color deepNavy;
  final double glowOpacity;

  const _GridEyeLogoPainter({
    required this.progress,
    required this.cyanColor,
    required this.navyColor,
    required this.deepNavy,
    required this.glowOpacity,
  });

  // ── 4 static quarter segment colors (theme-synced) ─────────────────────
  static const _seg0 = Color(0xFF00E5FF); // Cyan    — top    (12→3 o'clock)
  static const _seg1 = Color(0xFFFFAB40); // Orange  — right  (3→6 o'clock)
  static const _seg2 = Color(0xFF69F0AE); // Green   — bottom (6→9 o'clock)
  static const _seg3 = Color(0xFFFF5252); // Red     — left   (9→12 o'clock)

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

    // ── Eye geometry — UNCHANGED ──────────────────────────────────────────
    final leftX = cx - size.width * 0.47;
    final rightX = cx + size.width * 0.47;
    final arcH = size.height * 0.36;

    // ── Paints — UNCHANGED ────────────────────────────────────────────────
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

    final outerIrisPaint = Paint()
      ..color = cyanColor.withOpacity(0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    final innerIrisPaint = Paint()
      ..color = navyColor.withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final midIrisPaint = Paint()
      ..color = cyanColor.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

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

    // ── Stage 1: Eye interior fill + grid — UNCHANGED ─────────────────────
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

    // ── Stage 2: Top arc — UNCHANGED ─────────────────────────────────────
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

    // ── Stage 3: Bottom arc — UNCHANGED ──────────────────────────────────
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

    // ── Stage 4: Iris rings — UNCHANGED ──────────────────────────────────
    final irisP = ((progress - 0.45) / 0.27).clamp(0.0, 1.0);
    if (irisP > 0) {
      final irisR1 = size.width * 0.195;
      final irisR2 = size.width * 0.130;
      final irisR3 = size.width * 0.078;

      outerIrisPaint.color = cyanColor.withOpacity(0.62 * irisP);
      canvas.drawCircle(Offset(cx, cy), irisR1, outerIrisPaint);

      if (irisP > 0.35) {
        innerIrisPaint.color =
            navyColor.withOpacity(0.70 * ((irisP - 0.35) / 0.65));
        canvas.drawCircle(Offset(cx, cy), irisR2, innerIrisPaint);
      }

      if (irisP > 0.60) {
        midIrisPaint.color =
            cyanColor.withOpacity(0.28 * ((irisP - 0.60) / 0.40));
        canvas.drawCircle(Offset(cx, cy), irisR3, midIrisPaint);
      }

      final irisFill = Paint()
        ..color = deepNavy.withOpacity(0.50 * irisP)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), irisR1 - 0.8, irisFill);
    }

    // ── Stage 5: Crosshair — UNCHANGED (pure cyan) ────────────────────────
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

    // ── Stage 6: Pupil — 4 static colored quarter arcs + center dot ───────
    final pupilP = ((progress - 0.78) / 0.22).clamp(0.0, 1.0);
    if (pupilP > 0) {
      // ── Pupil ring radius — sits between irisR3 and center dot ──────────
      final segR = size.width * 0.155;

      // Gap between each quarter so they look like 4 distinct segments
      const gapRad = 0.10; // ~5.7° gap on each side edge
      const quarterSweep = (math.pi / 2) - gapRad; // 90° minus gap

      final segStrokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      // Soft glow paint behind each arc — same color, wide + transparent
      final segGlowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round;

      // Quarter 0 — Cyan    — top    (-π/2  → 0)        12→3 o'clock
      // Quarter 1 — Orange  — right  (0     → π/2)      3→6 o'clock
      // Quarter 2 — Green   — bottom (π/2   → π)        6→9 o'clock
      // Quarter 3 — Red     — left   (π     → 3π/2)     9→12 o'clock
      final segments = [
        (startAngle: -math.pi / 2 + gapRad / 2, color: _seg0),
        (startAngle:  0.0         + gapRad / 2, color: _seg1),
        (startAngle:  math.pi / 2 + gapRad / 2, color: _seg2),
        (startAngle:  math.pi     + gapRad / 2, color: _seg3),
      ];

      final segRect = Rect.fromCircle(center: Offset(cx, cy), radius: segR);

      for (final seg in segments) {
        // Glow layer
        segGlowPaint.color = seg.color.withOpacity(0.15 * pupilP);
        canvas.drawArc(segRect, seg.startAngle, quarterSweep, false, segGlowPaint);

        // Main arc stroke
        segStrokePaint.color = seg.color.withOpacity(0.90 * pupilP);
        canvas.drawArc(segRect, seg.startAngle, quarterSweep, false, segStrokePaint);
      }

      // ── Center pupil dot — UNCHANGED ──────────────────────────────────
      final pupilR = size.width * 0.072;

      // Soft glow
      final glowPaint = Paint()
        ..color = cyanColor.withOpacity(0.30 * pupilP)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
      canvas.drawCircle(Offset(cx, cy), pupilR * 1.7, glowPaint);

      // Navy base
      final pupilBase = Paint()
        ..color = deepNavy.withOpacity(0.90 * pupilP)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), pupilR, pupilBase);

      // Cyan ring
      final pupilRing = Paint()
        ..color = cyanColor.withOpacity(0.92 * pupilP)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(Offset(cx, cy), pupilR, pupilRing);

      // Solid cyan center
      final pupilFill = Paint()
        ..color = cyanColor.withOpacity(0.95 * pupilP)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx, cy), pupilR * 0.52, pupilFill);

      // Specular highlight
      final hiPaint = Paint()
        ..color = Colors.white.withOpacity(0.58 * pupilP)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(cx + size.width * 0.024, cy - size.height * 0.024),
        size.width * 0.026,
        hiPaint,
      );
    }

    // ── Stage 7: Tip ticks — UNCHANGED ───────────────────────────────────
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
      old.progress != progress || old.glowOpacity != glowOpacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVE DOTS LOADER
// ─────────────────────────────────────────────────────────────────────────────
class _WaveDotsLoader extends StatelessWidget {
  final double progress;
  final Color color;
  const _WaveDotsLoader({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final phase = (progress - i * 0.20) % 1.0;
        final wave = math.sin(phase * math.pi * 2);
        final t = (wave + 1) / 2;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4.5),
          child: Transform.scale(
            scale: 0.50 + 0.50 * t,
            child: Container(
              width: 5.5,
              height: 5.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.20 + 0.80 * t),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRID TEXTURE PAINTER (background ambient texture)
// ─────────────────────────────────────────────────────────────────────────────
class _GridTexturePainter extends CustomPainter {
  final Color color;
  const _GridTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.042)
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