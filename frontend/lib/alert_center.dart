import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'meter_analytics_history.dart';

class AlertCenter extends StatefulWidget {
  final bool showOnlyUnread;
  const AlertCenter({super.key, this.showOnlyUnread = false});

  @override
  State<AlertCenter> createState() => _AlertCenterState();
}

class _AlertCenterState extends State<AlertCenter> {
  // Docs ek baar lock hongi, phir stream unhe change nahi kar sakta
  List<QueryDocumentSnapshot>? _lockedDocs;

  // Archive cards ke tapped IDs — back aane par bhi survive karta hai
  final Set<String> _tappedArchiveIds = {};

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('Alerts')
        .orderBy('time', descending: true);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        // Line 38: Text widget ko ShaderMask se wrap karein
title: ShaderMask(
  shaderCallback: (bounds) => const LinearGradient(
    colors: [Color(0xFF00E5FF), Color(0xFF008CAB)],
  ).createShader(bounds),
  child: Text(
    widget.showOnlyUnread ? 'NEW NOTIFICATIONS' : 'THEFT ARCHIVE',
    style: GoogleFonts.orbitron(
      fontSize: 16, // Thora bara size
      fontWeight: FontWeight.normal, 
      color: Colors.white, 
      letterSpacing: 1.5
    ),
  ),
),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _lockedDocs == null) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }

          // ── KEY FIX 1 ──────────────────────────────────────────
          // ────────────────────────────────────────────────────────
          if (snapshot.hasData && _lockedDocs == null) {
            final allDocs = snapshot.data!.docs;
            if (widget.showOnlyUnread) {
              _lockedDocs = allDocs
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['isRead'] == false)
                  .toList();
            } else {
              _lockedDocs = List.from(allDocs);
            }
          }

           final docs = _lockedDocs ?? [];
          

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      color: Colors.white24, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    widget.showOnlyUnread
                        ? 'All caught up!'
                        : 'No alerts found.',
                    style: GoogleFonts.orbitron(
                        color: Colors.white24, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final alertData = doc.data() as Map<String, dynamic>;

              final String mID = alertData['meterId'] ?? 'Unknown';
              final String desc =
                  alertData['description'] ?? 'No details provided';
              final String type = alertData['type'] ?? 'Warning';
              final bool initialIsRead = alertData['isRead'] ?? false;
              final String status =
                  (alertData['status'] ?? '').toString().toLowerCase();

              if (widget.showOnlyUnread) {
                return _NotificationCard(
                  key: ValueKey(doc.id),
                  doc: doc,
                  mID: mID,
                  desc: desc,
                  type: type,
                  initialIsRead: initialIsRead,
                );
              } else {
                // ── KEY FIX 2 ────────────────────────────────────
                // isTapped parent state (_tappedArchiveIds) se aata hai
                // Back aane par bhi Set survive karta hai
                // StatelessWidget hai to rebuild pe reset nahi hoga
                // ─────────────────────────────────────────────────
                return _ArchiveCard(
                  key: ValueKey(doc.id),
                  doc: doc,
                  mID: mID,
                  desc: desc,
                  type: type,
                  status: status,
                  isTapped: _tappedArchiveIds.contains(doc.id),
                  onTapped: () {
                    setState(() => _tappedArchiveIds.add(doc.id));
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATION CARD
// ══════════════════════════════════════════════════════════════
class _NotificationCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String mID, desc, type;
  final bool initialIsRead;

  const _NotificationCard({
    super.key,
    required this.doc,
    required this.mID,
    required this.desc,
    required this.type,
    required this.initialIsRead,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard>
    with SingleTickerProviderStateMixin {
  late bool _isRead;
  late AnimationController _controller;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _isRead = widget.initialIsRead;
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _slideAnim =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    if (_isRead) _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    if (!_isRead) {
      FirebaseFirestore.instance
          .collection('Alerts')
          .doc(widget.doc.id)
          .update({'isRead': true});
      setState(() => _isRead = true);
      _controller.forward();
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => MeterDetailPage(alertData: widget.doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return GestureDetector(
          onTap: _onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            margin:
                const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
            decoration: BoxDecoration(
              color: _isRead
                  ? Colors.white.withOpacity(0.025)
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isRead
                    ? Colors.greenAccent.withOpacity(0.3)
                    : Colors.white.withOpacity(0.08),
                width: 1.2,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: _isRead
                        ? Container(
                            key: const ValueKey('read_icon'),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color:
                                      Colors.greenAccent.withOpacity(0.35),
                                  width: 1),
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.greenAccent, size: 20),
                          )
                        : Container(
                            key: const ValueKey('unread_icon'),
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: (widget.type == 'Critical'
                                      ? Colors.redAccent
                                      : Colors.orangeAccent)
                                  .withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: widget.type == 'Critical'
                                  ? Colors.redAccent
                                  : Colors.orangeAccent,
                              size: 20,
                            ),
                          ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: GoogleFonts.orbitron(
                            color:
                                _isRead ? Colors.white38 : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          child: Text('Meter: ${widget.mID}'),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 400),
                          style: TextStyle(
                            color:
                                _isRead ? Colors.white24 : Colors.white60,
                            fontSize: 12,
                          ),
                          child: Text(
                            widget.desc,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizeTransition(
                          sizeFactor: _slideAnim,
                          axisAlignment: -1,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Row(
                              children: [
                                Icon(Icons.done_all_rounded,
                                    color:
                                        Colors.greenAccent.withOpacity(0.8),
                                    size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'Marked as read',
                                  style: TextStyle(
                                    color:
                                        Colors.greenAccent.withOpacity(0.65),
                                    fontSize: 10,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: _isRead
                        ? Colors.greenAccent.withOpacity(0.35)
                        : Colors.white12,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ARCHIVE CARD — StatelessWidget
// isTapped parent (_AlertCenterState) se aata hai
// Back aane par Set survive karta hai, tick reset nahi hoga
// ══════════════════════════════════════════════════════════════
class _ArchiveCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String mID, desc, type, status;
  final bool isTapped;
  final VoidCallback onTapped;

  const _ArchiveCard({
    super.key,
    required this.doc,
    required this.mID,
    required this.desc,
    required this.type,
    required this.status,
    required this.isTapped,
    required this.onTapped,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTheft = status == 'theft';
    final Color accent =
        type == 'Critical' ? Colors.redAccent : Colors.orangeAccent;

    return GestureDetector(
      onTap: () {
        if (isTheft && !isTapped) onTapped();
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MeterDetailPage(alertData: doc)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.bolt_rounded, color: accent, size: 20),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Meter: $mID',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isTapped && isTheft
                    ? Container(
                        key: const ValueKey('tick'),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.greenAccent.withOpacity(0.45),
                              width: 1),
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.greenAccent, size: 13),
                      )
                    : const Icon(
                        key: ValueKey('arrow'),
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white12,
                        size: 13,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// METER DETAIL PAGE
// ══════════════════════════════════════════════════════════════
class MeterDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot alertData;
  const MeterDetailPage({super.key, required this.alertData});

  @override
  Widget build(BuildContext context) {
    var data = alertData.data() as Map<String, dynamic>;
    String meterId = data['meterId']?.toString() ?? 'N/A';
    String address = data['location']?.toString() ??
        data['address']?.toString() ??
        'Address not found';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        title: Text('Meter Analytics',
            style:
                GoogleFonts.orbitron(fontSize: 16, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [Color(0xFF1B263B), Color(0xFF0D1B2A)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.location_searching_rounded,
                        color: Color(0xFF00E5FF), size: 40),
                    const SizedBox(height: 15),
                    Text(
                      'METER SCAN ACTIVE',
                      style: GoogleFonts.orbitron(
                          color: const Color(0xFF00E5FF),
                          fontSize: 12,
                          letterSpacing: 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              _buildInfoTile(Icons.fingerprint, 'METER IDENTIFICATION',
                  meterId, Colors.white),
              _buildInfoTile(Icons.map_outlined, 'GEOSPATIAL LOCATION',
                  address, Colors.white70),
              _buildInfoTile(Icons.gpp_bad_outlined, 'CURRENT STATUS',
                  'Theft Detected', Colors.redAccent),
              const Spacer(),
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
                      colors: [Color(0xFF00E5FF), Color(0xFF00B2CC)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.analytics_outlined,
                            color: Colors.black, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'VIEW ANALYTICS HISTORY',
                          style: GoogleFonts.orbitron(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1),
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

  Widget _buildInfoTile(
      IconData icon, String label, String value, Color valueColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: const Color(0xFF00E5FF).withOpacity(0.7), size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: valueColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}