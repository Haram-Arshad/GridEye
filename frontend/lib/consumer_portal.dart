import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'usage_history.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumerPortal extends StatelessWidget {
  final String meterID;
  ConsumerPortal({required this.meterID});

  // --- LIVE FIRESTORE ENTRY FUNCTION ---
Future<void> _sendFaultReport(BuildContext context, String mID, String faultType) async {
  // Pehle hi debug print karwa lein check karne ke liye
  print("Button Pressed for Meter: $mID");

  try {
    // 1. Fetch ALL reports for this meter (Simple Query)
    final snapshot = await FirebaseFirestore.instance
        .collection('Faults') // Capital 'F' as you confirmed
        .where('meterID', isEqualTo: mID)
        .get();

    // 2. Manual check for Pending status
    bool alreadyPending = false;
    for (var doc in snapshot.docs) {
      if (doc['status'] == 'Pending') {
        alreadyPending = true;
        break;
      }
    }

    if (alreadyPending) {
      print("Found a pending report. Stopping.");
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("A report is already pending for this meter."),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    // 3. Agar koi pending nahi mili toh naya document add karein
    print("No pending found. Adding new report to Firebase...");
    await FirebaseFirestore.instance.collection('Faults').add({
      'meterID': mID,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'Pending',
      'description': 'User reported outage manually.',
      'type': faultType,
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Fault Reported Successfully!"),
        backgroundColor: Color(0xFF00E5FF),
      ),
    );

  } catch (e) {
    print("CRITICAL ERROR: $e");
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Firebase Error: $e"), backgroundColor: Colors.redAccent),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("My GridEye", style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('meters').doc(meterID).snapshots(),
        builder: (context, meterSnapshot) {
          if (meterSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!meterSnapshot.hasData || !meterSnapshot.data!.exists) {
            return const Center(child: Text("Meter Not Found", style: TextStyle(color: Colors.white)));
          }

          var meterData = meterSnapshot.data!.data() as Map<String, dynamic>;
          double currentLoad = (meterData['currentLoad'] ?? 0.0).toDouble();
          int units = meterData['units'] ?? 0;
          int billEst = meterData['billEst'] ?? 0;
          String mID = meterData['meterID'] ?? meterID;

          // --- NAYA NESTED STREAM: FAULT STATUS CHECK ---
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Faults')
                .where('meterID', isEqualTo: mID)
                .where('status', isEqualTo: 'Pending')
                .snapshots(),
            builder: (context, faultSnapshot) {
              // Agar query mein koi document mila, iska matlab report pending hai
              bool isPending = faultSnapshot.hasData && faultSnapshot.data!.docs.isNotEmpty;

              // --- DYNAMIC UI LOGIC ---
            // --- DYNAMIC UI LOGIC (REPLACE IN YOUR CODE) ---
// --- DYNAMIC UI LOGIC (REFINED) ---
          List<Color> cardGradient = [const Color(0xFF1B263B), const Color(0xFF0D1B2A)]; // Solid Dark Base
          Color accentColor = const Color(0xFF00E5FF); // Default Cyan
          String alertTitle = "REPORT POWER FAULT";
          String alertSub = "Inform Admin about outages";
          IconData alertIcon = Icons.report_problem_outlined;

          if (isPending) {
            // Scenario 1: PENDING (Soft Purple Accents)
            accentColor = const Color(0xFFBB86FC); 
            alertTitle = "STATUS: PROCESSING";
            alertSub = "Report is live. Waiting for Admin...";
            alertIcon = Icons.sync_rounded;
          } else if (currentLoad == 0.0) {
            // Scenario 2: OUTAGE (Vibrant Orange-Red Accents)
            accentColor = const Color(0xFFFF5252); // Soft Red Neon
            alertTitle = "CRITICAL: NO LOAD";
            alertSub = "Potential outage! Tap to report.";
            alertIcon = Icons.power_off_rounded;
          } else if (currentLoad > 5.0) {
            // Scenario 3: HIGH LOAD (Warning Amber Accents)
            accentColor = const Color(0xFFFFB74D); // Warm Amber
            alertTitle = "SYSTEM: HIGH LOAD";
            alertSub = "High energy usage detected.";
            alertIcon = Icons.bolt;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Welcome Back,", style: TextStyle(color: Colors.white70, fontSize: 16)),
                Text("Consumer #$mID", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 30),
                
                _buildUsageCard(currentLoad, units, billEst),
                
                const SizedBox(height: 40),
                const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // --- SMART ACTION TILE (Dynamic Font Colors) ---
                _actionTile(
                  icon: alertIcon,
                  title: alertTitle,
                  subtitle: alertSub,
                  gradientColors: cardGradient, // Background stays dark/consistent
                  accentColor: accentColor,    // Only Font/Icon/Border changes
                  onTap: isPending 
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Processing report..."))
                      )
                    : () => _showReportDialog(context, mID, alertTitle),
                ),

                const SizedBox(height: 15),

                // --- USAGE HISTORY TILE (Static Cyan) ---
                _actionTile(
                  icon: Icons.analytics_outlined,
                  title: "USAGE HISTORY",
                  subtitle: "View your energy consumption logs",
                  gradientColors: [const Color(0xFF1B263B), const Color(0xFF0D1B2A)], 
                  accentColor: const Color(0xFF00E5FF), 
                  // Error yahan solve hoga:
                  onTap: () => Navigator.push(
                  context, 
                  MaterialPageRoute(
                  builder: (context) => UsageHistory(meterID: mID), // 'mID' variable jo aapne upar banaya hai
                    ),
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

  // --- UI COMPONENTS ---
  Widget _buildUsageCard(double load, int units, int bill) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF00E5FF).withOpacity(0.2), const Color(0xFF008CAB).withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Current Load", style: TextStyle(color: Colors.white70)),
              Icon(Icons.bolt, color: load > 5.0 ? Colors.redAccent : Colors.yellowAccent),
            ],
          ),
          const SizedBox(height: 10),
          Text("${load.toStringAsFixed(2)} kW", style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white10, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [
                const Text("Units", style: TextStyle(color: Colors.white54, fontSize: 12)), 
                Text("$units", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
              ]),
              Column(children: [
                const Text("Bill (Est)", style: TextStyle(color: Colors.white54, fontSize: 12)), 
                Text("Rs. $bill", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
              ]),
            ],
          )
        ],
      ),
    );
  }

Widget _actionTile({
  required IconData icon, 
  required String title, 
  required String subtitle, 
  required List<Color> gradientColors, 
  required Color accentColor, 
  required VoidCallback onTap
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        // Solid background with subtle gradient to match your premium theme
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        // Hairline border for that "Aesthetic" look
        border: Border.all(
          color: accentColor.withOpacity(0.4), 
          width: 1.2
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 26),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                Text(
                  title, 
                  style: TextStyle( // Removed Orbitron for clean UI
                    color: accentColor, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 15,
                    letterSpacing: 0.5
                  )
                ), 
                const SizedBox(height: 3),
                Text(
                  subtitle, 
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6), 
                    fontSize: 11,
                    fontWeight: FontWeight.w400
                  )
                )
              ]
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: accentColor.withOpacity(0.5), size: 20),
        ],
      ),
    ),
  );
}
void _showReportDialog(BuildContext context, String mID, String currentType) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("System Alert", style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Detected Issue: $currentType", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text(
            "Reporting this will alert the GridEye Admin with your Meter ID and current load data for immediate action.",
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            _sendFaultReport(context, mID, currentType); 
          },
          child: const Text("PROCEED", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
}