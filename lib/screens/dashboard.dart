import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../api_service.dart';
import 'add_job.dart';
import 'search_jobs.dart';
import 'profile.dart';
import 'analytics.dart';
import 'distance_traveled.dart';
import 'applications.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String userName = "User";
  String userEmail = "";
  String userRole = "User";
  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    print("USER information");
    print("${prefs.getString('userEmail')} ,,, ${prefs.getString('userRole')}");  
    setState(() {
      userName = prefs.getString('full_name') ?? "ERP User";
      userEmail = prefs.getString('userEmail') ?? "";
      userRole = prefs.getString('userRole') ?? "User";
    });
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await ApiService().clearSession();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  const Text(
                    "Quick Actions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      children: [
                        if (userRole == "ADMIN GREAT INDIAN")
                          _buildStyledCard(
                            context,
                            title: "Add Job",
                            subtitle: "Post new openings",
                            icon: Icons.add_circle_outline,
                            color: Colors.blueAccent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddJobScreen())),
                          ),
                        if(userRole != "ADMIN GREAT INDIAN")
                        _buildStyledCard(
                          context,
                          title: "Search Job",
                          subtitle: "Manage listings",
                          icon: Icons.search_rounded,
                          color: Colors.orangeAccent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchJobScreen())),
                        ),
                        if(userRole == "ADMIN GREAT INDIAN")
                        _buildStyledCard(context, title: "Applicatons", subtitle: "View applications", icon: Icons.description_outlined, color: Colors.pinkAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ApplicationsScreen()))),
                        _buildStyledCard(
                          context,
                          title: "Analytics",
                          subtitle: "View reports",
                          icon: Icons.bar_chart_rounded,
                          color: Colors.greenAccent[700]!,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
                        ),
                        
                        _buildStyledCard(
                          context,
                          title: "Profile",
                          subtitle: "Account settings",
                          icon: Icons.person_outline_rounded,
                          color: Colors.purpleAccent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                        ),
                        // _buildStyledCard(context, title: "Distance Travel", subtitle: "Track your travel distance", icon: Icons.directions_car_outlined, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DistanceTraveledScreen())))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODERN HEADER SECTION ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 35),
      decoration: const BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Welcome, $userName",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                userEmail,
                style: TextStyle(color: Colors.indigo[100], fontSize: 14),
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: _logout,
            ),
          )
        ],
      ),
    );
  }

  // --- CLEAN ACTION CARD ---
  Widget _buildStyledCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 15),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}