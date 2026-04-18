import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'usage_history.dart';
import 'profile_screen.dart'; // Import profile screen

class ConsumerPortal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("My GridEye", style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)),
    
        centerTitle: false,
        actions: [
          // --- PROFILE BUTTON ADDED HERE ---
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, color: Colors.white70),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            onPressed: () => Navigator.pushReplacementNamed(context, '/roleSelection'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome Back,", style: TextStyle(color: Colors.white70, fontSize: 16)),
            const Text("Consumer #MTR-5520", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            _buildUsageCard(),
            const SizedBox(height: 40),
            const Text("Quick Actions", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _actionTile(
              icon: Icons.report_problem_outlined,
              title: "Report Power Fault",
              subtitle: "Inform Admin about outages",
              color: Colors.orangeAccent,
              onTap: () => _showReportDialog(context),
            ),
            const SizedBox(height: 15),
            _actionTile(
              icon: Icons.history,
              title: "Usage History",
              subtitle: "Check previous months",
              color: const Color(0xFF00E5FF),
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => UsageHistory()),
                 );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageCard() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF00E5FF).withOpacity(0.2), const Color(0xFF008CAB).withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Current Load", style: TextStyle(color: Colors.white70)),
              Icon(Icons.bolt, color: Colors.yellowAccent),
            ],
          ),
          SizedBox(height: 10),
          Text("1.45 kW", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
          Divider(color: Colors.white10, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(children: [Text("Units", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("124", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
              Column(children: [Text("Bill (Est)", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("Rs. 4,250", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionTile({required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11))]),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Report Fault", 
          style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 18)
        ),
        content: const Text(
          "Are you sure you want to report a power fault? Admin will be notified immediately.", 
          style: TextStyle(color: Colors.white70)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 5,
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Fault Reported Successfully!"),
                  backgroundColor: Color(0xFF00E5FF),
                )
              );
            },
            child: const Text("REPORT", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}