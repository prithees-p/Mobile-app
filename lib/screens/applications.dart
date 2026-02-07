import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning/api_service.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  String username = "";
  String email = ""; // This is the class-level variable
  String role = "";
  List<dynamic> applications = [];
  bool isLoading = true; // Added loading state

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // Combined to ensure email is loaded BEFORE fetching applications
  Future<void> _initData() async {
    await _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // REMOVED 'String' from the start to update the class variable
      email = prefs.getString('savedEmail') ?? ""; 
      username = prefs.getString('full_name') ?? "ERP User";
      role = prefs.getString('userRole') ?? "User";
    });
    await _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    if (email.isEmpty) return; // Don't call API if email is missing

    try {
      final response = await ApiService().dio.get(
            "/api/method/great_indian.great_indian.utils.api.get_applications",
            queryParameters: {"username": email},
          );

      if (response.statusCode == 200) {
        setState(() {
          applications = response.data["message"] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching applications: $e");
      setState(() => isLoading = false);
    }
    print(applications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Applications"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : applications.isEmpty
              ? _buildEmptyState()
              : _buildApplicationList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_outline, size: 80, color: Colors.grey),
          SizedBox(height: 20),
          Text("No applications yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildApplicationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: applications.length,
      itemBuilder: (context, index) {
        final app = applications[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Icon(Icons.description, color: Colors.white),
            ),
            title: Text(
              app['job_title'] ?? "Job Title",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  app['applicant'] ?? "Unknown Applicant",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text("Applied on: ${app['applied_on'] ?? 'N/A'}"),
                const SizedBox(height: 6),

                /// 🔥 STATUS CHIP
                Builder(
                  builder: (context) {
                    final status = app['status'] ?? "Unknown";

                    Color textColor;
                    Color bgColor;

                    if (status == "Open") {
                      textColor = Colors.green;
                      bgColor = Colors.green.withOpacity(0.1);
                    } else if (status == "Completed") {
                      textColor = Colors.red;
                      bgColor = Colors.red.withOpacity(0.1);
                    } else {
                      textColor = Colors.grey;
                      bgColor = Colors.grey.withOpacity(0.1);
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(color: textColor, fontSize: 12),
                      ),
                    );
                  },
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        );

      },
    );
  }
}