import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'usage_history.dart';
import 'profile_screen.dart';

// --------------------
// ANIMATED ACTION TILE 
// --------------------
class _AnimatedActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  const _AnimatedActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_AnimatedActionTile> createState() => _AnimatedActionTileState();
}

class _AnimatedActionTileState extends State<_AnimatedActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: widget.accentColor.withOpacity(0.25), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: widget.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: widget.accentColor.withOpacity(0.2), width: 1),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6B7F99),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: widget.accentColor.withOpacity(0.35),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// CONSUMER PORTAL — StatefulWidget

class ConsumerPortal extends StatefulWidget {
  final String meterID;
  const ConsumerPortal({super.key, required this.meterID});

  @override
  State<ConsumerPortal> createState() => _ConsumerPortalState();
}

class _ConsumerPortalState extends State<ConsumerPortal> {
  
  String _resolvedMeterID = '';

  //  Fault Report Logic 
  Future<void> _sendFaultReport(
      BuildContext context, String mID, String faultType) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Faults')
          .where('meterID', isEqualTo: mID)
          .get();

      bool alreadyPending = false;
      for (var doc in snapshot.docs) {
        if (doc['status'] == 'Pending') {
          alreadyPending = true;
          break;
        }
      }

      if (alreadyPending) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("A report is already pending for this meter."),
          backgroundColor: Colors.orangeAccent,
        ));
        return;
      }

     
      String cleanType = 'POWER_FAULT';
      if (faultType.contains('NO LOAD'))   cleanType = 'NO_LOAD';
      if (faultType.contains('HIGH LOAD')) cleanType = 'HIGH_LOAD';

      await FirebaseFirestore.instance.collection('Faults').add({
        'meterID':     mID,
        'timestamp':   FieldValue.serverTimestamp(),
        'status':      'Pending',
        'description': 'User reported outage manually.',
        'type':        cleanType,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Fault Reported Successfully!"),
        backgroundColor: Color(0xFF00E5FF),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Firebase Error: $e"),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showReportDialog(
      BuildContext context, String mID, String currentType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "System Alert",
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Detected Issue: $currentType",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Reporting this will alert the GridEye Admin with your "
              "Meter ID and current load data for immediate action.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL",
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _sendFaultReport(context, mID, currentType);
            },
            child: const Text("PROCEED",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Helpers 
  String _formatTimestamp(dynamic ts) {
    if (ts == null || ts is! Timestamp) return "—";
    final dt   = ts.toDate();
    final hour = dt.hour > 12
        ? dt.hour - 12
        : (dt.hour == 0 ? 12 : dt.hour);
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final min  = dt.minute.toString().padLeft(2, '0');
    return "${dt.day}/${dt.month}/${dt.year} | $hour:$min $ampm";
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'fault': return const Color(0xFFFFB74D);
      case 'theft': return const Color(0xFFFF5252);
      default:      return const Color(0xFF69F0AE);
    }
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF00E5FF), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'GRID',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              TextSpan(
                text: 'EYE',
                style: GoogleFonts.orbitron(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF00E5FF),
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined,
                color: Colors.white70),
            // ✅ FIX: resolved meterID pass ho rahi hai
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(
                  meterID: _resolvedMeterID.isEmpty
                      ? widget.meterID
                      : _resolvedMeterID,
                ),
              ),
            ),
          ),
        ],
      ),

      //  Body: 
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('meters')
            .doc(widget.meterID)   //widget.meterID
            .snapshots(),
        builder: (context, meterSnapshot) {

          if (meterSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!meterSnapshot.hasData || !meterSnapshot.data!.exists) {
            return const Center(
              child: Text(
                "Meter Not Found",
                style: TextStyle(color: Colors.white),
              ),
            );
          }

          final meterData =
              meterSnapshot.data!.data() as Map<String, dynamic>;

          // Data reads 
          double currentLoad =
              (meterData['currentLoad'] ?? 0.0).toDouble();
          double units   = (meterData['units']   ?? 0.0).toDouble();
          double billEst = (meterData['billEst'] ?? 0.0).toDouble();
          String mID         = meterData['meterId'] ?? widget.meterID;
          String meterStatus = meterData['status']  ?? 'Normal';
          String city        = meterData['city']    ?? '—';
          String area        = meterData['area']    ?? '—';
          dynamic timestamp  = meterData['timestamp'];

         
          if (_resolvedMeterID != mID) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _resolvedMeterID = mID);
            });
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Faults')
                .where('meterID', isEqualTo: mID)
                .where('status', isEqualTo: 'Pending')
                .snapshots(),
            builder: (context, faultSnapshot) {

              // Alert tile logic
              bool isPending = faultSnapshot.hasData &&
                  faultSnapshot.data!.docs.isNotEmpty;

              Color    accentColor = const Color(0xFF00E5FF);
              String   alertTitle  = "REPORT POWER FAULT";
              String   alertSub    = "Inform Admin about outages";
              IconData alertIcon   = Icons.report_problem_outlined;

              if (isPending) {
                accentColor = const Color(0xFFBB86FC);
                alertTitle  = "STATUS: PROCESSING";
                alertSub    = "Report is live. Waiting for Admin...";
                alertIcon   = Icons.sync_rounded;
              } else if (currentLoad == 0.0) {
                accentColor = const Color(0xFFFF5252);
                alertTitle  = "CRITICAL: NO LOAD";
                alertSub    = "Potential outage! Tap to report.";
                alertIcon   = Icons.power_off_rounded;
              } else if (currentLoad > 5.0) {
                accentColor = const Color(0xFFFFB74D);
                alertTitle  = "SYSTEM: HIGH LOAD";
                alertSub    = "High energy usage detected.";
                alertIcon   = Icons.bolt;
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Greeting 
                    const Text(
                      "Welcome Back,",
                      style: TextStyle(
                        color: Color(0xFF8899AA),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Consumer #$mID",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),

                    //  Status Badge 
                    _buildStatusBadge(meterStatus),
                    const SizedBox(height: 22),

                    // Usage Card 
                    _buildUsageCard(
                        currentLoad, units, billEst, timestamp, meterStatus),
                    const SizedBox(height: 10),

                    // Location Bar 
                    _buildLocationSlim(area, city),
                    const SizedBox(height: 28),

                    //  Quick Actions
                    const Text(
                      "Quick Actions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fault report tile
                    _AnimatedActionTile(
                      icon:        alertIcon,
                      title:       alertTitle,
                      subtitle:    alertSub,
                      accentColor: accentColor,
                      onTap: isPending
                          ? () => ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                                  content: Text("Processing report...")))
                          : () => _showReportDialog(
                              context, mID, alertTitle),
                    ),
                    const SizedBox(height: 10),

                    // Usage history tile
                    _AnimatedActionTile(
                      icon:        Icons.analytics_outlined,
                      title:       "USAGE HISTORY",
                      subtitle:    "View your energy consumption logs",
                      accentColor: const Color(0xFF00E5FF),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => UsageHistory(meterID: mID)),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Status Badge 
  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _statusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _statusColor(status).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: _statusColor(status), size: 8),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  // Usage Card 
  Widget _buildUsageCard(double load, double units, double bill,
      dynamic timestamp, String status) {

    Color primaryNumColor = const Color(0xFF00E5FF);
    if (load == 0.0) {
      primaryNumColor = const Color(0xFFFF5252);
    } else if (status.toLowerCase() == 'fault') {
      primaryNumColor = Colors.orangeAccent;
    }

    const Color unitsColor = Color(0xFF69F0AE);
    const Color billColor  = Color(0xFFFFD740);

    const TextStyle labelStyle = TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    );

    TextStyle valueStyle(double size, Color color) => TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size > 30 ? -1.0 : 0.0,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2137), Color(0xFF0A1A2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00C4D4).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                const Text("CURRENT LOAD", style: labelStyle),
                const SizedBox(height: 8),
                Text(
                  "${load.toStringAsFixed(2)} kW",
                  style: valueStyle(46, primaryNumColor),
                ),
                const SizedBox(height: 20),

                Container(height: 1, color: Colors.white.withOpacity(0.07)),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("UNITS", style: labelStyle),
                        const SizedBox(height: 6),
                        Text(units.toStringAsFixed(1),
                            style: valueStyle(24, unitsColor)),
                      ],
                    ),
                    Container(
                        width: 1,
                        height: 44,
                        color: Colors.white.withOpacity(0.07)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("BILL (EST)", style: labelStyle),
                        const SizedBox(height: 6),
                        Text("Rs. ${bill.toStringAsFixed(0)}",
                            style: valueStyle(24, billColor)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: const BorderRadius.only(
                bottomLeft:  Radius.circular(22),
                bottomRight: Radius.circular(22),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sync_rounded,
                    color: Color(0xFF00E5FF), size: 13),
                const SizedBox(width: 7),
                Text(
                  "UPDATED  ${_formatTimestamp(timestamp)}",
                  style: const TextStyle(
                    color: Color(0xFF00E5FF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Location Slim Bar
  Widget _buildLocationSlim(String area, String city) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: Color(0xFFFF5252), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$area, $city",
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}