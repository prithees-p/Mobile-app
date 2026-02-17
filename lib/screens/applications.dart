import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:learning/api_service.dart';
import 'package:flutter/services.dart';
import 'package:pay/pay.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  String username = "";
  String email = "";
  String role = "";
  List<dynamic> applications = [];
  bool isLoading = true;
  List filteredApplications = []; 
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    print("comes in inistate");
    _initData();
  }

  void _filterApplications(String query) {
    setState(() {
      filteredApplications = applications
          .where((app) =>
              app['job_title'].toLowerCase().contains(query.toLowerCase()) ||
              app['applicant'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }
  // Combined to ensure email is loaded BEFORE fetching applications
  Future<void> _initData() async {
    print("Initializing Applications Screen data...");
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
    print("Loaded user data: $email, $username, $role");
    await _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    if (email.isEmpty) return; 

    try {
      final response = await ApiService().dio.get(
            "/api/method/application.application.utils.py.api.get_applications",
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
    filteredApplications = applications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Applications", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              onChanged: _filterApplications,
              decoration: InputDecoration(
                hintText: "Search by job or applicant...",
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                suffixIcon: searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear), 
                      onPressed: () {
                        searchController.clear();
                        _filterApplications("");
                      }) 
                  : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: Colors.indigo.withOpacity(0.1)),
                ),
              ),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _fetchApplications(), 
              child: filteredApplications.isEmpty
                  ? _buildEmptyState()
                  : _buildApplicationList(),
            ),
          ),
        ],
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredApplications.length,
      itemBuilder: (context, index) {
        final app = filteredApplications[index];
        
        // Animation wrapper for smooth entry
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ApplicationApproval(applicationData: app)),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _buildLeadingAvatar(app['status']),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app['job_title'] ?? "Job Title",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            app['applicant'] ?? "Applicant",
                            style: TextStyle(color: Colors.indigo[900], fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "📅 ${app['applied_on'] ?? 'N/A'}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    
                    _buildStatusBadge(app['status'] ?? "Unknown"),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeadingAvatar(String? status) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: status == "Open" ? Colors.green : (status == "Completed" ? Colors.red : Colors.grey),
          width: 2,
        ),
      ),
      child: const CircleAvatar(
        backgroundColor: Colors.indigo,
        child: Icon(Icons.person, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = status == "Open" ? Colors.green : (status == "Completed" ? Colors.red : Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}


class ApplicationApproval extends StatefulWidget {
  final Map<String, dynamic> applicationData;
  const ApplicationApproval({super.key, required this.applicationData});

  @override
  State<ApplicationApproval> createState() => _ApplicationApprovalState();
}

class _ApplicationApprovalState extends State<ApplicationApproval> {
  bool isProcessing = false;
  String? currentStatus;
  String? applicationStatus;
  @override
  void initState() {
    super.initState();
    print("Application date--test------");
    print(widget.applicationData);
    currentStatus = widget.applicationData['status'] ?? "Pending";
    applicationStatus = widget.applicationData['astatus'] ?? "Pending";
  }

  Future<void> _updateStatus(String newStatus, String name) async {
    if (isProcessing) return;

    setState(() => isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.update_status_in_application",
        queryParameters: {
          "application_name": name,
          "status": newStatus,
        },
      );

      if (mounted) {
        setState(() {
          applicationStatus = newStatus;
          isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  newStatus == "Approved" ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Text("Successfully marked as $newStatus"),
              ],
            ),
            backgroundColor: newStatus == "Approved" ? Colors.green : Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(context, true); 
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update status. Please try again."),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Review Application", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 25),
            const Text("Applicant Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDetailTile(Icons.person, "Full Name", widget.applicationData['applicant']),
            _buildDetailTile(Icons.email, "Email Address", widget.applicationData['email_id'] ?? "N/A"),
            _buildDetailTile(
              Icons.calendar_today_rounded, 
              "Applied Date", 
              _formatDateTime(widget.applicationData['applied_on'], returnDate: true)
            ),

            _buildDetailTile(
              Icons.access_time_rounded, 
              "Applied Time", 
              _formatDateTime(widget.applicationData['applied_on'], returnDate: false)
            ),
            _buildDetailTile(Icons.start, "Status",widget.applicationData['astatus'] ?? "Pending"),
            const SizedBox(height: 30),
            if (isProcessing)
              const Center(child: CircularProgressIndicator())
            else
              _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.indigo,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 15),
          Text(
            widget.applicationData['job_title'] ?? "Job Title",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildStatusSection(),
        ],
      ),
    );
  }

  // Helper method to get color based on status string
  Color _getStatusColor(String? status) {
    switch (status) {
      case "Approved":
      case "Open":
        return Colors.green;
      case "Rejected":
      case "Completed":
        return Colors.red;
      case "Pending":
      case "In Progress":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSingleBadge("Current Status", currentStatus, _getStatusColor(currentStatus)),
        const SizedBox(width: 12), // Gap between the two blocks
        _buildSingleBadge("Application", applicationStatus, _getStatusColor(applicationStatus)),
      ],
    );
  }

  Widget _buildSingleBadge(String label, String? status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: color.withOpacity(0.6),
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status ?? "Pending",
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo[50],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.indigo, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)
              ),
              const SizedBox(height: 2),
              Text(
                value, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus("Rejected",widget.applicationData['name']),
            icon: const Icon(Icons.close, color: Colors.white),
            label: const Text("REJECT", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus("Approved",widget.applicationData['name']),
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text("APPROVE", style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatDateTime(String? rawDateTime, {required bool returnDate}) {
  if (rawDateTime == null || rawDateTime.isEmpty) return "N/A";
  try {
    DateTime dt = DateTime.parse(rawDateTime);
    if (returnDate) {
      // Returns: 07 Feb 2026
      return "${dt.day.toString().padLeft(2, '0')} ${_getMonthName(dt.month)} ${dt.year}";
    } else {
      // Returns: 12:30 PM
      int hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      String period = dt.hour >= 12 ? "PM" : "AM";
      return "${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period";
    }
  } catch (e) {
    return "Invalid Format";
  }
}

String _getMonthName(int month) {
  const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  return months[month - 1];
}