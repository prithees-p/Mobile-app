import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; 
import '../api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userName = "Loading...";
  String userEmail = "...";
  String userRole = "...";
  List<dynamic> myPostedJobs = [];
  List<dynamic> myAppliedJobs = [];
  bool isLoading = true;

  int openCount = 0;
  int completedCount = 0;
  int approvedCount = 0;
  int rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Wrapped API logic to return a Future for the RefreshIndicator
  Future<void> get_posted_job_details(String email) async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_posted_job_details",
        queryParameters: {"username": email},
      );

      if (response.statusCode == 200) {
        List data = response.data["message"] ?? [];
        if (mounted) {
          setState(() {
            myPostedJobs = data;
            openCount = data.where((job) => job['status'] == 'Open').length;
            completedCount = data.where((job) => job['status'] == 'Completed').length;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }
  Future<void> _get_history_job_seeker(String email) async {
    print("coms in");
    setState(() => isLoading = true);
    try {
      print("coms in try $email");
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_history_job_seeker",
        queryParameters: {"email": email},
      );
      print(response.statusCode);
      if (response.statusCode == 200) {
        print(response.data);
        print("------------------");
        List data = response.data["message"] ?? [];
        if (mounted) {
          setState(() {
            myAppliedJobs = data;
            approvedCount = data.where((job) => job['status'] == 'Approved').length;
            rejectedCount = data.where((job) => job['status'] == 'Rejected').length;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching profile stats: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }
  Future<void> _handleLogout(context) async {
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

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('savedEmail') ?? "";
    print(email);
    setState(() {
      userName = prefs.getString('full_name') ?? "ERP User";
      userEmail = email;
      userRole = prefs.getString('userRole') ?? "User";
    });
    if (email.isNotEmpty) get_posted_job_details(email);
    _get_history_job_seeker(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD), 
      appBar: AppBar(
        title: const Text("Admin Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo[900],
        elevation: 0,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout_rounded),
        //     onPressed: () => _handleLogout(context),
        //   )
        // ],
      ),
      // --- REFRESH INDICATOR ADDED HERE ---
      body: RefreshIndicator(
        onRefresh: () => get_posted_job_details(userEmail),
        color: Colors.indigo,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Ensures pulling works even if list is short
          child: Column(
            children: [
              _buildModernHeader(),
              const SizedBox(height: 10),
              _buildStatGrid(),
              const SizedBox(height: 25),
              _buildActivityHeader(),
              _buildJobHistoryList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernHeader() {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.indigo.shade100, width: 2),
            ),
            child: const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFE8EAF6),
              child: Icon(Icons.person_rounded, size: 45, color: Colors.indigo),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(userEmail, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 4),
                Text(userRole, style: TextStyle(color: Colors.indigo[400], fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid() {
    if (userRole != "Job Seeker") {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(
        children: [
          _buildStatCard("Total Applied", "${myPostedJobs.length}", Colors.indigo),
          const SizedBox(width: 12),
          _buildStatCard("In Review", "$openCount", Colors.orange),
          const SizedBox(width: 12),
          _buildStatCard("Completed", "$completedCount", Colors.green),
        ],
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard("Total", "${myPostedJobs.length}", Colors.indigo),
          const SizedBox(width: 12),
          _buildStatCard("Approved", "$approvedCount", Colors.green),
          const SizedBox(width: 12),
          _buildStatCard("Rejected", "$rejectedCount", Colors.orange),
        ],
      ),
    );
  }


  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityHeader() {
    if(userRole != "Job Seeker") {
      return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 20, color: Colors.black54),
          SizedBox(width: 8),
          Text("Application History", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
    } else {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.history_rounded, size: 20, color: Colors.black54),
            SizedBox(width: 8),
            Text("Posting History To be applied", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
  }

  Widget _buildJobHistoryList() {
    if (isLoading && myPostedJobs.isEmpty) {
      return const Padding(padding: EdgeInsets.only(top: 50), child: CircularProgressIndicator());
    }
    if(userRole != "Job Seeker") {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: myPostedJobs.length,
        itemBuilder: (context, index) {
          final job = myPostedJobs[index];
          final bool isOpen = job['status'] == 'Open';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(job['job_title'] ?? "Job Title Not Mentioned", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("${job['designation']} • ${job['date']}"),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    isOpen ? Icons.check_circle_outline : Icons.done_all_rounded,
                    color: isOpen ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job['status'] ?? "",
                    style: TextStyle(color: isOpen ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: myPostedJobs.length,
        itemBuilder: (context, index) {
          final job = myPostedJobs[index];
          final bool isOpen = job['status'] == 'Open';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Text(job['job_title'] ?? "Job Title Not Mentioned", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text("${job['designation']} • ${job['date']}"),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(
                    isOpen ? Icons.check_circle_outline : Icons.done_all_rounded,
                    color: isOpen ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job['status'] ?? "",
                    style: TextStyle(color: isOpen ? Colors.green : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}