import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../api_service.dart';
import 'add_job.dart';
import 'search_jobs.dart';
import 'profile.dart';
import 'analytics.dart';
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
  bool isLoading = true;
  List notifications = [];
  int notificationCount = 0; 

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
    get_notification_log(userEmail);
  }

  Future<void> get_notification_log(String email) async {
    print("Comes in");
    setState(() => isLoading = true);
    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_notification_log",
        queryParameters: {"user": email},
      );
      if (response.statusCode == 200) {
        List data = response.data["message"] ?? [];
        print("Notifications: $data");
        setState(() {
          notifications = data;
          notificationCount = data.length;
        });
      }

      
    } catch (e) {
      debugPrint("Error fetching profile stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> markNotificationsAsRead() async {
    try {
      await ApiService().dio.post(
        "/api/method/application.application.utils.py.api.mark_all_as_read",
        data: {"user_email": userEmail},
      );

      setState(() {
        notificationCount = 0;
      });
    } catch (e) {
      debugPrint("Failed to mark as read: $e");
    }
  }
  Future<void> markIndividualAsRead(String docname, int index) async {
    try {
      await ApiService().dio.post(
        "/api/method/application.application.utils.py.api.mark_single_as_read",
        data: {"docname": docname},
      );

      setState(() {
        notifications.removeAt(index); 
        notificationCount = notifications.length;
      });
    } catch (e) {
      debugPrint("Error marking as read: $e");
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    await ApiService().clearSession();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }
    Widget _buildVerticalDivider() => Container(height: 30, width: 1, color: Colors.grey[200]);

  Widget _buildSummarySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Applied", "0", Colors.orange),
          _buildVerticalDivider(),
          _buildStatItem("Approved", "0", Colors.blue),
          _buildVerticalDivider(),
          _buildStatItem("Rejected", "0", Colors.red),
          _buildVerticalDivider(),
          _buildStatItem("Completed", "0", Colors.green),
        ],
      ),
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
            child: RefreshIndicator(
              color: Colors.indigo,
              onRefresh: _loadUserInfo,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 25),
                  _buildSummarySection(),
                  const SizedBox(height: 30),
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
                        if (userRole == "JOB POSTER")
                          _buildStyledCard(
                            context,
                            title: "Add Job",
                            subtitle: "Post new openings",
                            icon: Icons.add_circle_outline,
                            color: Colors.blueAccent,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddJobScreen())),
                          ),
                        if(userRole != "JOB POSTER")
                        _buildStyledCard(
                          context,
                          title: "Search Job",
                          subtitle: "Manage listings",
                          icon: Icons.search_rounded,
                          color: Colors.orangeAccent,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchJobScreen())),
                        ),
                        if(userRole == "JOB POSTER")
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
                "Welcome User,",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              Text(
                "$userName",
                style: TextStyle(color: Colors.indigo[100], fontSize: 14),
              ),
            ],
          ),
          Badge(
            isLabelVisible: notificationCount > 0, 
            label: Text('$notificationCount'),
            backgroundColor: Colors.red,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent, // Required for custom shapes/colors
                    isScrollControlled: true,
                    builder: (context) => Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: Column(
                        children: [
                          // Handle bar for better UX
                          const SizedBox(height: 12),
                          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                          
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Notifications", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                    Text("You have $notificationCount unread", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                                  ],
                                ),
                                if (notificationCount > 0)
                                  TextButton.icon(
                                    onPressed: () {
                                      markNotificationsAsRead();
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.done_all_rounded, size: 18),
                                    label: const Text("Clear All"),
                                    style: TextButton.styleFrom(foregroundColor: Colors.blueAccent, backgroundColor: Colors.blue.withOpacity(0.05), shape: StadiumBorder()),
                                  ),
                              ],
                            ),
                          ),
                          const Divider(indent: 20, endIndent: 20),
                          Expanded(
                            child: notifications.isEmpty
                                ? _buildEmptyState()
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    itemCount: notifications.length,
                                    itemBuilder: (context, index) {
                                      final item = notifications[index];
                                      final String docName = item['name'];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Dismissible(
                                          key: Key(docName),
                                          direction: DismissDirection.endToStart,
                                          onDismissed: (direction) => markIndividualAsRead(docName, index),
                                          background: _buildSwipeBackground(),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                                              ],
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.all(12),
                                              leading: CircleAvatar(
                                                backgroundColor: Colors.blue.withOpacity(0.1),
                                                child: const Icon(Icons.notifications_active_outlined, color: Colors.blueAccent),
                                              ),
                                              title: Text(
                                                item['document_name'] ?? 'Update',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  item['email_content'] ?? '',
                                                  style: TextStyle(color: Colors.grey[700], height: 1.4),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
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
  // Helper widget for swipe design
  Widget _buildSwipeBackground() {
    return Container(
      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(16)),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 25),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          Text("Read", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))
        ],
      ),
    );
  }

  // Helper for Empty State
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("All caught up!", style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500)),
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