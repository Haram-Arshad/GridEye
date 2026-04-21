import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore import add kiya
import 'splash_screen.dart';
import 'admin_dashboard.dart';
import 'consumer_portal.dart';
import 'meter_id_input.dart'; // Ye line lazmi add karein

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
        // Note: consumerDashboard aur roleSelection ab dynamic Navigator se chalenge
      },
    );
  }
}

// ==========================================
// LOGIN SCREEN
// ==========================================
class GridEyeLogin extends StatefulWidget {
  @override
  _GridEyeLoginState createState() => _GridEyeLoginState();
}

class _GridEyeLoginState extends State<GridEyeLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      // 1. Auth Login
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Fetch User Data from Firestore using UID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

// main.dart ke andar _handleLogin function mein:
if (userDoc.exists) {
  String role = userDoc['role'] ?? "consumer";
  String mID = userDoc['meterID'] ?? "";

  if (role == 'multi') {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => RoleSelectionScreen(meterID: mID)),
    );
  } else if (role == 'admin') {
    Navigator.pushReplacementNamed(context, '/adminDashboard');
  } else {
    // AB YE CHANGE KAREIN: Direct portal ki jagah Input screen par bhejain
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => MeterIdInputScreen()), 
    );
  }
}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', width: 150),
              const SizedBox(height: 20),
              const Text("GridEye", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), letterSpacing: 2)),
              const Text("Smart Grid Monitoring System", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 60),

              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF00E5FF)),
                  hintText: 'Corporate Email',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                  hintText: 'Password',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 30),

              GestureDetector(
                onTap: _isLoading ? null : _handleLogin,
                child: Container(
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF008CAB)]),
                  ),
                  child: Center(
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text("LOGIN", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ROLE SELECTION SCREEN
// ==========================================
class RoleSelectionScreen extends StatelessWidget {
  final String meterID; // MeterID receive karne ke liye
  RoleSelectionScreen({required this.meterID});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Identify Your Role",
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00E5FF),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            const Text("Select access level to continue", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 50),
            
           // Admin Card
// Admin Card
_buildRoleCard(
  context,
  title: "Utility Admin",
  subtitle: "Monitor Grid & Theft Alerts", // Ye line miss thi
  icon: Icons.admin_panel_settings_outlined, // Ye line miss thi
  onTap: () {
    Navigator.pushNamed(context, '/adminDashboard');
  },
),

const SizedBox(height: 20),

// Consumer Card
// main.dart ke RoleSelectionScreen mein:
_buildRoleCard(
  context,
  title: "Consumer Portal",
  subtitle: "View Usage & Report Faults",
  icon: Icons.bolt_outlined,
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MeterIdInputScreen()), // Ab yahan bhejain
    );
  },
),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF00E5FF).withOpacity(0.1),
              radius: 30,
              child: Icon(icon, color: const Color(0xFF00E5FF), size: 30),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}