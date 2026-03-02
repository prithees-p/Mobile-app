import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../main.dart';
import 'search_jobs.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  // Data Variables
  String userName = "Loading...";
  String userEmail = "";
  String userRole = "";
  List<dynamic> myPostedJobs = [];
  List<dynamic> myAppliedJobs = [];
  bool isLoading = true;
  bool isError = false;

  // Counter Variables
  int openCount = 0;
  int completedCount = 0;
  int approvedCount = 0;
  int rejectedCount = 0;
  int totalCount = 0;

  // Animation Variables
  late AnimationController _mainController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeIn),
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  // --- LOGIC SECTION ---

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isError = false;
    });

    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('savedEmail') ?? "";
    String role = prefs.getString('userRole') ?? "User";

    setState(() {
      userName = prefs.getString('full_name') ?? "Guest User";
      userEmail = email;
      userRole = role;
    });

    try {
      if (email.isNotEmpty) {
        if (userRole == "Job Seeker") {
          await _getHistoryJobSeeker(email);
        } else {
          await _getPostedJobDetails(email);
        }
      }
    } catch (e) {
      setState(() => isError = true);
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
        _mainController.forward(from: 0.0);
      }
    }
  }

  Future<void> _getPostedJobDetails(String email) async {
    final response = await ApiService().dio.get(
      "/api/method/application.application.utils.py.api.get_posted_job_details",
      queryParameters: {"username": email},
    );
    if (response.statusCode == 200) {
      List data = response.data["message"] ?? [];
      setState(() {
        myPostedJobs = data;
        openCount = data.where((j) => j['status'] == 'Open').length;
        completedCount = data.where((j) => j['status'] == 'Completed').length;
      });
    }
  }

  Future<void> _getHistoryJobSeeker(String email) async {
    final response = await ApiService().dio.get(
      "/api/method/application.application.utils.py.api.get_history_job_seeker",
      queryParameters: {"email": email},
    );
    if (response.statusCode == 200) {
      List data = response.data["message"] ?? [];
      setState(() {
        myAppliedJobs = data;
        totalCount = data.length;
        approvedCount = data.where((j) => j['status'] == 'Approved').length;
        rejectedCount = data.where((j) => j['status'] == 'Rejected').length;
        openCount = data.where((j) => j['status'].toString().toLowerCase().contains('pen')).length;
      });
    }
  }

  // --- UI SECTION ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 3))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: RefreshIndicator(
                onRefresh: _loadUserData,
                color: const Color(0xFF6366F1),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildModernHeader(),
                    SliverToBoxAdapter(
                      child: Transform.translate(
                        offset: const Offset(0, -35),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileCard(),
                              const SizedBox(height: 24),
                              _buildSectionLabel("Quick Stats"),
                              const SizedBox(height: 12),
                              _buildStatGrid(),
                              const SizedBox(height: 32),
                              _buildSectionLabel("Recent Activity"),
                              const SizedBox(height: 12),
                              _buildActivityList(),
                              const SizedBox(height: 50),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModernHeader() {
    return SliverAppBar(
      expandedHeight: 100,
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF8FAFC),
      elevation: 0,
      pinned: true, 
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF4338CA)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: CircleAvatar(
                  radius: 60, 
                  backgroundColor: Colors.white.withOpacity(0.1)
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userRole == "Job Seeker" ? "My Journey" : "Admin Panel",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: _showLogoutDialog,
                        icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          padding: const EdgeInsets.all(10),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
  return Padding(
    padding: const EdgeInsets.only(top: 50, bottom: 10),
    child: Row(
      children: [
        Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : "?",
              style: const TextStyle(
                color: Color(0xFF6366F1),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              // Email "Pill"
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1)),
                ),
                child: Text(
                  userEmail,
                  style: const TextStyle(
                    color: Color(0xFF4338CA),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildStatGrid() {
    return Row(
      children: [
        if (userRole == "Job Seeker") ...[
          _statItem("Applied", "$totalCount", Icons.send_rounded, Colors.blue),
          _statItem("Pending", "$openCount", Icons.timer_rounded, Colors.orange),
          _statItem("Hired", "$approvedCount", Icons.check_circle_rounded, Colors.green),
        ] else ...[
          _statItem("Posted", "${myPostedJobs.length}", Icons.assignment_rounded, Colors.indigo),
          _statItem("Open", "$openCount", Icons.bolt_rounded, Colors.teal),
          _statItem("Filled", "$completedCount", Icons.verified_user_rounded, Colors.blueGrey),
        ],
      ],
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.7), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityList() {
    final list = userRole == "Job Seeker" ? myAppliedJobs : myPostedJobs;

    if (list.isEmpty) return _buildEmptyState();

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = list[index];
        final String title = userRole == "Job Seeker" ? (item['subject'] ?? "Application") : (item['job_title'] ?? "Job");
        final String status = item['status'] ?? "Pending";
        final Color statusColor = _getStatusColor(status);

        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(
            jobId: item['parent'] ?? "",
            showApplyButton: 0,
          ))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(_getStatusIcon(status), color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF334155))),
                      const SizedBox(height: 2),
                      Text(
                        userRole == "Job Seeker" ? "ID: ${item['parent']}" : "${item['designation']}",
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      Text(
                        DateFormat("dd MMM yyyy").format(DateTime.parse(item['date'] ?? DateTime.now().toString())),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                _statusChip(status, statusColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statusChip(String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF94A3B8),
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.layers_clear_outlined, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text("No records found", style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase();
    if (status.contains('pen')) return Colors.orange;
    if (status == 'approved' || status == 'open') return const Color(0xFF6366F1);
    if (status == 'rejected') return Colors.redAccent;
    if (status == 'completed') return Colors.teal;
    return Colors.blueGrey;
  }

  IconData _getStatusIcon(String status) {
    status = status.toLowerCase();
    if (status.contains('pen')) return Icons.pending_actions_rounded;
    if (status == 'approved' || status == 'open') return Icons.check_circle_outline_rounded;
    if (status == 'rejected') return Icons.cancel_outlined;
    return Icons.info_outline_rounded;
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await ApiService().clearSession();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
            },
            child: const Text("Logout"),
          ),
        ],
      ),
    );
  }
}