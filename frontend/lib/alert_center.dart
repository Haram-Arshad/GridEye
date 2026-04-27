import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'meter_analytics_history.dart';

// ── Design tokens ────────────────────────────────────────────
const _bgDeep  = Color(0xFF070E17);
const _bgMid   = Color(0xFF0D1B2A);
const _cyan    = Color(0xFF00E5FF);
const _cyanDim = Color(0xFF008CAB);

// ═══════════════════════════════════════════════════════════════
// AlertCenter — 100% UNCHANGED
// ═══════════════════════════════════════════════════════════════
class AlertCenter extends StatefulWidget {
  final bool showOnlyUnread;
  const AlertCenter({super.key, this.showOnlyUnread = false});

  @override
  State<AlertCenter> createState() => _AlertCenterState();
}

class _AlertCenterState extends State<AlertCenter>
    with SingleTickerProviderStateMixin {

  List<QueryDocumentSnapshot>? _lockedDocs;
  final Set<String> _tappedIds = {};
  late AnimationController _staggerCtrl;

  @override
  void initState() {
    super.initState();
    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Alerts')
        .orderBy('time', descending: true);

    return Scaffold(
      backgroundColor: _bgMid,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: _bgDeep,
            border: Border(
              bottom: BorderSide(color: _cyan.withOpacity(0.12), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: _cyan, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: widget.showOnlyUnread
                        ? RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: 'NEW ',
                                style: GoogleFonts.orbitron(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 2.5,
                                ),
                              ),
                              TextSpan(
                                text: 'NOTIFICATIONS',
                                style: GoogleFonts.orbitron(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: _cyan, letterSpacing: 2.5,
                                ),
                              ),
                            ]),
                          )
                        : RichText(
                            text: TextSpan(children: [
                              TextSpan(
                                text: 'ALERT ',
                                style: GoogleFonts.orbitron(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: Colors.white, letterSpacing: 2.5,
                                ),
                              ),
                              TextSpan(
                                text: 'ARCHIVE',
                                style: GoogleFonts.orbitron(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: _cyan, letterSpacing: 2.5,
                                ),
                              ),
                            ]),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _PulseDot(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lockedDocs == null) {
            return const Center(
                child: CircularProgressIndicator(color: _cyan, strokeWidth: 1.5));
          }

          if (snapshot.hasData && _lockedDocs == null) {
            final allDocs = snapshot.data!.docs;
            _lockedDocs = widget.showOnlyUnread
                ? allDocs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['isRead'] == false)
                    .toList()
                : List.from(allDocs);
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => _staggerCtrl.forward());
          }

          final docs = _lockedDocs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded,
                      color: Colors.white.withOpacity(0.15), size: 44),
                  const SizedBox(height: 14),
                  Text(
                    widget.showOnlyUnread ? 'All caught up' : 'No alerts found',
                    style: GoogleFonts.orbitron(
                        color: Colors.white.withOpacity(0.20),
                        fontSize: 12, letterSpacing: 1.5),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc  = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final mID    = data['meterId']     ?? 'Unknown';
              final desc   = data['description'] ?? 'No details provided';
              final type   = data['type']        ?? 'Warning';
              final isRead = data['isRead']       ?? false;
              final status = (data['status'] ?? '').toString().toLowerCase();

              final start    = (index * 0.08).clamp(0.0, 0.85);
              final end      = (start + 0.35).clamp(0.0, 1.0);
              final interval = Interval(start, end, curve: Curves.easeOutCubic);

              Widget card = widget.showOnlyUnread
                  ? _NotifCard(
                      key: ValueKey(doc.id),
                      doc: doc, mID: mID, desc: desc, type: type,
                      initialIsRead: isRead,
                    )
                  : _ArchiveCard(
                      key: ValueKey(doc.id),
                      doc: doc, mID: mID, desc: desc, status: status,
                      isTapped: _tappedIds.contains(doc.id),
                      onTapped: () => setState(() => _tappedIds.add(doc.id)),
                    );

              return AnimatedBuilder(
                animation: _staggerCtrl,
                builder: (_, child) {
                  final t = interval.transform(_staggerCtrl.value);
                  return Opacity(
                    opacity: t,
                    child: Transform.translate(
                        offset: Offset(0, 18 * (1 - t)), child: child),
                  );
                },
                child: card,
              );
            },
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _PulseDot — UNCHANGED
// ═══════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cyan.withOpacity(_a.value),
              boxShadow: [BoxShadow(
                color: _cyan.withOpacity(_a.value * 0.6),
                blurRadius: 6, spreadRadius: 1,
              )],
            ),
          ),
          const SizedBox(width: 5),
          Text('LIVE', style: GoogleFonts.rajdhani(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: _cyan.withOpacity(_a.value), letterSpacing: 1.5,
          )),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _NotifCard — UNCHANGED
// ═══════════════════════════════════════════════════════════════
class _NotifCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String mID, desc, type;
  final bool initialIsRead;

  const _NotifCard({
    super.key, required this.doc, required this.mID,
    required this.desc, required this.type, required this.initialIsRead,
  });

  @override
  State<_NotifCard> createState() => _NotifCardState();
}

class _NotifCardState extends State<_NotifCard>
    with SingleTickerProviderStateMixin {
  late bool _isRead;
  late AnimationController _ctrl;
  late Animation<double> _readSlide;

  @override
  void initState() {
    super.initState();
    _isRead = widget.initialIsRead;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _readSlide = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    if (_isRead) _ctrl.value = 1.0;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _onTap() async {
    if (!_isRead) {
      FirebaseFirestore.instance
          .collection('Alerts').doc(widget.doc.id).update({'isRead': true});
      setState(() => _isRead = true);
      _ctrl.forward();
    }
    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => MeterDetailPage(alertData: widget.doc)));
  }

  @override
  Widget build(BuildContext context) {
    final Color accent =
        widget.type == 'Critical' ? Colors.redAccent : Colors.orangeAccent;

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: _isRead
              ? Colors.white.withOpacity(0.022)
              : Colors.white.withOpacity(0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isRead
                ? Colors.greenAccent.withOpacity(0.20)
                : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: _isRead
                    ? _IconCircle(key: const ValueKey('r'),
                        icon: Icons.check_rounded, color: Colors.greenAccent, size: 38)
                    : _IconCircle(key: const ValueKey('u'),
                        icon: Icons.warning_amber_rounded, color: accent, size: 38),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meter: ${widget.mID}',
                      style: TextStyle(
                        color: _isRead ? Colors.white38 : Colors.white.withOpacity(0.92),
                        fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.2,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(widget.desc,
                      style: TextStyle(
                        color: _isRead ? Colors.white24 : Colors.white54,
                        fontSize: 11.5, fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    SizeTransition(
                      sizeFactor: _readSlide, axisAlignment: -1,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          Icon(Icons.done_all_rounded,
                              color: Colors.greenAccent.withOpacity(0.65), size: 10),
                          const SizedBox(width: 4),
                          Text('Marked as read', style: TextStyle(
                            color: Colors.greenAccent.withOpacity(0.55),
                            fontSize: 10, letterSpacing: 0.3,
                          )),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                color: _isRead
                    ? Colors.greenAccent.withOpacity(0.28)
                    : Colors.white.withOpacity(0.14),
                size: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _ArchiveCard — UNCHANGED
// ═══════════════════════════════════════════════════════════════
class _ArchiveCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String mID, desc, status;
  final bool isTapped;
  final VoidCallback onTapped;

  const _ArchiveCard({
    super.key, required this.doc, required this.mID,
    required this.desc, required this.status,
    required this.isTapped, required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTheft = status == 'theft';
    final bool isFault = status == 'fault';
    final Color accent = isTheft ? Colors.redAccent
        : isFault ? Colors.orangeAccent : _cyan;
    final IconData icon = isTheft ? Icons.bolt_rounded
        : isFault ? Icons.build_circle_outlined : Icons.info_outline_rounded;

    return GestureDetector(
      onTap: () {
        if (!isTapped) onTapped();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => MeterDetailPage(alertData: doc)));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: const EdgeInsets.only(bottom: 10),
        height: 72,
        decoration: BoxDecoration(
          color: isTapped
              ? Colors.greenAccent.withOpacity(0.035)
              : Colors.white.withOpacity(0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTapped
                ? Colors.greenAccent.withOpacity(0.22)
                : Colors.white.withOpacity(0.07),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _IconCircle(icon: icon, color: accent, size: 38),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meter: $mID',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 13,
                        fontWeight: FontWeight.w600, letterSpacing: 0.2,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(desc,
                      style: const TextStyle(
                        color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: isTapped
                    ? _TickBadge(key: const ValueKey('tick'))
                    : Icon(key: const ValueKey('arrow'),
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white.withOpacity(0.14), size: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _IconCircle & _TickBadge — UNCHANGED
// ═══════════════════════════════════════════════════════════════
class _IconCircle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _IconCircle({super.key, required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.10),
        border: Border.all(color: color.withOpacity(0.22), width: 1),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class _TickBadge extends StatelessWidget {
  const _TickBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.greenAccent.withOpacity(0.10),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.40), width: 1),
      ),
      child: const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 13),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// METER DETAIL PAGE — UPDATED:
//   1. AppBar → same style as Alert Archive
//   2. Meter Scan Active card → animated eye logo (no text removed)
//   3. Info tiles → staggered slide+fade entry
//   4. Dynamic status (already existed, kept)
// ═══════════════════════════════════════════════════════════════
class MeterDetailPage extends StatefulWidget {
  final QueryDocumentSnapshot alertData;
  const MeterDetailPage({super.key, required this.alertData});

  @override
  State<MeterDetailPage> createState() => _MeterDetailPageState();
}

class _MeterDetailPageState extends State<MeterDetailPage>
    with TickerProviderStateMixin {

  // Eye logo: ring color cycling
  late AnimationController _ringCtrl;
  // Eye logo: breathing glow
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseOpacity;
  // Tile entry stagger
  late AnimationController _entryCtrl;
  late List<Animation<double>> _tileOpacity;
  late List<Animation<Offset>>  _tileSlide;

  @override
  void initState() {
    super.initState();

    // Continuous ring rotation — 4s loop, drives color cycling
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    // Breathing glow pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _pulseOpacity = Tween<double>(begin: 0.10, end: 0.28).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Tile stagger — 3 tiles, 650ms total
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..forward();

    _tileOpacity = List.generate(3, (i) {
      final s = (i * 0.22).clamp(0.0, 1.0);
      final e = (s + 0.45).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryCtrl,
            curve: Interval(s, e, curve: Curves.easeOut)),
      );
    });

    _tileSlide = List.generate(3, (i) {
      final s = (i * 0.22).clamp(0.0, 1.0);
      final e = (s + 0.50).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.16), end: Offset.zero,
      ).animate(CurvedAnimation(parent: _entryCtrl,
          curve: Interval(s, e, curve: Curves.easeOutCubic)));
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data      = widget.alertData.data() as Map<String, dynamic>;
    final meterId   = data['meterId']?.toString()  ?? 'N/A';
    final address   = data['location']?.toString() ??
                      data['address']?.toString()  ?? 'Address not found';
    final raw       = (data['status'] ?? '').toString().toLowerCase();
    final isTheft   = raw == 'theft';
    final isFault   = raw == 'fault';
    final statusLabel = isTheft ? 'Theft Detected'
                      : isFault ? 'Fault Detected' : 'Normal';
    final statusColor = isTheft ? Colors.redAccent
                      : isFault ? Colors.orangeAccent : Colors.greenAccent;
    final statusIcon  = isTheft ? Icons.gpp_bad_outlined
                      : isFault ? Icons.build_circle_outlined
                      : Icons.verified_outlined;

    return Scaffold(
      backgroundColor: _bgMid,

      // ── AppBar — identical to Alert Archive ────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: BoxDecoration(
            color: _bgDeep,
            border: Border(
              bottom: BorderSide(color: _cyan.withOpacity(0.12), width: 1),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: _cyan, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: 'METER_',
                          style: GoogleFonts.orbitron(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 2.5,
                          ),
                        ),
                        TextSpan(
                          text: 'ANALYTICS',
                          style: GoogleFonts.orbitron(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _cyan, letterSpacing: 2.5,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _PulseDot(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // ────────────────────────────────────────────────────────

      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1B263B), _bgMid],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Meter Scan Active card — eye logo inside, text kept ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 20, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    // ── Animated eye logo — replaces static icon ──────
                    AnimatedBuilder(
                      animation: Listenable.merge([_ringCtrl, _pulseCtrl]),
                      builder: (_, __) {
                        return SizedBox(
                          width: 76,
                          height: 76,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outermost breathing glow ring
                              Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(colors: [
                                    _cyan.withOpacity(_pulseOpacity.value),
                                    Colors.transparent,
                                  ]),
                                ),
                              ),
                              // Outer border ring — pulses subtly
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _cyan.withOpacity(
                                        _pulseOpacity.value * 0.55),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Inner dark fill ring
                              Container(
                                width: 53,
                                height: 53,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF051428)
                                      .withOpacity(0.55),
                                  border: Border.all(
                                    color: _cyan.withOpacity(0.10),
                                    width: 0.8,
                                  ),
                                ),
                              ),
                              // Eye CustomPainter
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: CustomPaint(
                                  painter: _EyeLogoPainter(
                                    ringPhase:   _ringCtrl.value,
                                    glowOpacity: _pulseOpacity.value,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    // ─────────────────────────────────────────────────

                    const SizedBox(height: 13),

                    // "METER SCAN ACTIVE" text — completely unchanged
                    Text(
                      'METER SCAN ACTIVE',
                      style: GoogleFonts.orbitron(
                        color: _cyan, fontSize: 12, letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              // ────────────────────────────────────────────────────

              const SizedBox(height: 20),

              // ── Info tiles with staggered entry ─────────────────
              _StagTile(
                opacity: _tileOpacity[0], slide: _tileSlide[0],
                child: _infoTile(Icons.fingerprint,
                    'METER IDENTIFICATION', meterId, Colors.white),
              ),
              _StagTile(
                opacity: _tileOpacity[1], slide: _tileSlide[1],
                child: _infoTile(Icons.map_outlined,
                    'GEOSPATIAL LOCATION', address, Colors.white70),
              ),
              _StagTile(
                opacity: _tileOpacity[2], slide: _tileSlide[2],
                child: _infoTile(statusIcon,
                    'CURRENT STATUS', statusLabel, statusColor),
              ),
              // ────────────────────────────────────────────────────

              const Spacer(),

              // CTA button — completely unchanged
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeterAnalyticsHistory(
                        meterId: meterId, address: address),
                  ),
                ),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_cyan, Color(0xFF00B2CC)]),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(
                      color: _cyan.withOpacity(0.35),
                      blurRadius: 15, offset: const Offset(0, 5),
                    )],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_outlined,
                            color: Colors.black, size: 22),
                        const SizedBox(width: 12),
                        Text('VIEW ANALYTICS HISTORY',
                          style: GoogleFonts.orbitron(
                            color: Colors.black, fontWeight: FontWeight.bold,
                            fontSize: 13, letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(
      IconData icon, String label, String value, Color valueColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(children: [
        Icon(icon, color: _cyan.withOpacity(0.70), size: 22),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                color: Colors.white38, fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1.2,
              )),
              const SizedBox(height: 4),
              Text(value,
                style: TextStyle(color: valueColor,
                    fontSize: 16, fontWeight: FontWeight.w500),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _StagTile — staggered slide+fade wrapper for info tiles
// ═══════════════════════════════════════════════════════════════
class _StagTile extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<Offset>  slide;
  final Widget child;
  const _StagTile({required this.opacity, required this.slide, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([opacity, slide]),
      builder: (_, __) => Opacity(
        opacity: opacity.value,
        child: Transform.translate(
          offset: Offset(0, slide.value.dy * 22),
          child: child,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _EyeLogoPainter — full eye at progress=1.0,
// ringPhase drives which quarter-arc segment is highlighted.
// Taken directly from splash _GridEyeLogoPainter logic.
// ═══════════════════════════════════════════════════════════════
class _EyeLogoPainter extends CustomPainter {
  final double ringPhase;    // 0.0→1.0, continuous from AnimationController
  final double glowOpacity;  // from pulse

  // 4 quarter-arc colors — same as splash screen
  static const _c0 = Color(0xFF00E5FF); // cyan
  static const _c1 = Color(0xFFFFAB40); // orange
  static const _c2 = Color(0xFF69F0AE); // green
  static const _c3 = Color(0xFFFF5252); // red

  static const _cyan    = Color(0xFF00E5FF);
  static const _navy    = Color(0xFF0055AA);
  static const _deepNav = Color(0xFF051428);

  const _EyeLogoPainter({
    required this.ringPhase,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final lx  = cx - size.width  * 0.47;
    final rx  = cx + size.width  * 0.47;
    final aH  = size.height * 0.36;

    // ── 1. Eye fill + grid ────────────────────────────────────
    final eyePath = Path()
      ..moveTo(lx, cy)
      ..quadraticBezierTo(cx, cy - aH, rx, cy)
      ..quadraticBezierTo(cx, cy + aH, lx, cy)
      ..close();

    canvas.save();
    canvas.clipPath(eyePath);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _deepNav.withOpacity(0.88)..style = PaintingStyle.fill);

    final gP = Paint()
      ..color = _cyan.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.45;
    final sp = size.width * 0.16;
    for (double x = lx; x <= rx + 1; x += sp) {
      canvas.drawLine(Offset(x, cy - aH), Offset(x, cy + aH), gP);
    }
    for (double y = cy - aH; y <= cy + aH + 1; y += sp) {
      canvas.drawLine(Offset(lx, y), Offset(rx, y), gP);
    }
    canvas.restore();

    // ── 2. Eye arcs ───────────────────────────────────────────
    final arcP = Paint()
      ..color = _cyan.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(Path()
      ..moveTo(lx, cy)..quadraticBezierTo(cx, cy - aH, rx, cy), arcP);
    canvas.drawPath(Path()
      ..moveTo(lx, cy)..quadraticBezierTo(cx, cy + aH, rx, cy), arcP);

    // ── 3. Iris rings ─────────────────────────────────────────
    final r1 = size.width * 0.195;
    final r2 = size.width * 0.130;

    canvas.drawCircle(Offset(cx, cy), r1,
      Paint()..color = _cyan.withOpacity(0.55)
              ..style = PaintingStyle.stroke..strokeWidth = 1.4);
    canvas.drawCircle(Offset(cx, cy), r2,
      Paint()..color = _navy.withOpacity(0.55)
              ..style = PaintingStyle.stroke..strokeWidth = 0.9);
    // iris interior fill
    canvas.drawCircle(Offset(cx, cy), r1 - 0.6,
      Paint()..color = _deepNav.withOpacity(0.50)..style = PaintingStyle.fill);

    // ── 4. Crosshair ──────────────────────────────────────────
    final xP = Paint()
      ..color = _cyan.withOpacity(0.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final gap = size.width * 0.135;
    final arm = size.width * 0.092;
    canvas.drawLine(Offset(cx-gap-arm, cy), Offset(cx-gap, cy), xP);
    canvas.drawLine(Offset(cx+gap, cy), Offset(cx+gap+arm, cy), xP);
    canvas.drawLine(Offset(cx, cy-gap-arm), Offset(cx, cy-gap), xP);
    canvas.drawLine(Offset(cx, cy+gap), Offset(cx, cy+gap+arm), xP);

    // ── 5. Rotating quarter-arc segments ──────────────────────
    final segR = size.width * 0.155;
    const gap2 = 0.10;
    const sweep = (math.pi / 2) - gap2;

    final activeIdx    = (ringPhase * 4).floor() % 4;
    final stepProgress = (ringPhase * 4) % 1.0;
    final highlight    = math.sin(stepProgress * math.pi).clamp(0.0, 1.0);

    final colors = [_c0, _c1, _c2, _c3];
    final starts = [
      -math.pi / 2 + gap2 / 2,
       0.0         + gap2 / 2,
       math.pi / 2 + gap2 / 2,
       math.pi     + gap2 / 2,
    ];
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: segR);

    final sP = Paint()..style = PaintingStyle.stroke
        ..strokeWidth = 2.2..strokeCap = StrokeCap.round;
    final gPainter = Paint()..style = PaintingStyle.stroke
        ..strokeWidth = 5.0..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final c = colors[i];
      if (i == activeIdx) {
        gPainter.color = c.withOpacity(0.22 * highlight);
        canvas.drawArc(rect, starts[i], sweep, false, gPainter);
        sP.color = c.withOpacity(0.55 + 0.40 * highlight);
        canvas.drawArc(rect, starts[i], sweep, false, sP);
      } else {
        sP.color = c.withOpacity(0.18);
        canvas.drawArc(rect, starts[i], sweep, false, sP);
      }
    }

    // ── 6. Center pupil ───────────────────────────────────────
    final pR = size.width * 0.072;

    // Glow
    canvas.drawCircle(Offset(cx, cy), pR * 1.6,
      Paint()..color = _cyan.withOpacity(glowOpacity * 0.9)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    // Navy base
    canvas.drawCircle(Offset(cx, cy), pR,
      Paint()..color = _deepNav.withOpacity(0.90)..style = PaintingStyle.fill);
    // Cyan ring
    canvas.drawCircle(Offset(cx, cy), pR,
      Paint()..color = _cyan.withOpacity(0.90)
              ..style = PaintingStyle.stroke..strokeWidth = 1.8);
    // Solid fill
    canvas.drawCircle(Offset(cx, cy), pR * 0.50,
      Paint()..color = _cyan.withOpacity(0.95)..style = PaintingStyle.fill);
    // Specular
    canvas.drawCircle(
      Offset(cx + size.width * 0.022, cy - size.height * 0.022),
      size.width * 0.024,
      Paint()..color = Colors.white.withOpacity(0.55)..style = PaintingStyle.fill,
    );

    // ── 7. Tip ticks ──────────────────────────────────────────
    final tP = Paint()
      ..color = _cyan.withOpacity(0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final tH = size.height * 0.10;
    canvas.drawLine(Offset(lx, cy - tH), Offset(lx, cy + tH), tP);
    canvas.drawLine(Offset(rx, cy - tH), Offset(rx, cy + tH), tP);
  }

  @override
  bool shouldRepaint(_EyeLogoPainter old) =>
      old.ringPhase != ringPhase || old.glowOpacity != glowOpacity;
}