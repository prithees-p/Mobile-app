import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:dio/dio.dart';
import '../api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

class SearchJobScreen extends StatefulWidget {
  const SearchJobScreen({super.key});

  @override
  State<SearchJobScreen> createState() => _SearchJobScreenState();
}

class _SearchJobScreenState extends State<SearchJobScreen> {
  List<dynamic> allJobs = [];
  List<dynamic> filteredJobs = [];
  bool isLoading = true;
  String searchQuery = "";
  String? userCity;
  bool isLocationFilterOn = false;

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _getUserLocation();
  }


  Future<void> _fetchJobs() async {
    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_job_list",
      );
      if (response.statusCode == 200) {
        setState(() {
          allJobs = response.data["message"] ?? [];
          filteredJobs = allJobs;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>> fetchOwnerDetails(String jobId) async {
    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_user_details",
        queryParameters: {"job_id": jobId},
      );
      return response.data["message"] ?? {"full_name": "N/A", "mobile_no": "N/A"};
    } catch (e) {
      return {"full_name": "Error", "mobile_no": "Error"};
    }
  }

  // --- LOCATION LOGIC ---

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          setState(() => userCity = placemarks[0].locality);
        }
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    }
  }

  void _applyFilters() {
    setState(() {
      filteredJobs = allJobs.where((job) {
        final matchesSearch = job['job_title'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
            job['designation'].toString().toLowerCase().contains(searchQuery.toLowerCase());
        final matchesLocation = !isLocationFilterOn ||
            (userCity != null && job['location'].toString().toLowerCase() == userCity!.toLowerCase());
        return matchesSearch && matchesLocation;
      }).toList();
    });
  }

  // --- UI BUILDERS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Find Your Job", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredJobs.isEmpty
                    ? const Center(child: Text("No jobs found"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: filteredJobs.length,
                        itemBuilder: (context, index) => _buildJobCard(filteredJobs[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        color: Colors.indigo,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (val) {
              searchQuery = val;
              _applyFilters();
            },
            decoration: InputDecoration(
              hintText: "Search job title or role...",
              prefixIcon: const Icon(Icons.search, color: Colors.indigo),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          ActionChip(
            label: Text(isLocationFilterOn ? "Filtering: $userCity" : "Near Me"),
            avatar: Icon(Icons.my_location, size: 16, color: isLocationFilterOn ? Colors.white : Colors.indigo),
            backgroundColor: isLocationFilterOn ? Colors.orange : Colors.white,
            onPressed: () {
              setState(() => isLocationFilterOn = !isLocationFilterOn);
              _applyFilters();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildJobCard(dynamic job) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: ExpansionTile(
        leading: const CircleAvatar(backgroundColor: Colors.indigo, child: Icon(Icons.work, color: Colors.white)),
        title: Text(job['job_title'] ?? "No Title", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${job['location']} • ₹${job['salary']}"),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                const Divider(),
                // FETCHING CONTACT DETAILS LIVE
                FutureBuilder<Map<String, dynamic>>(
                  future: fetchOwnerDetails(job['name']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }
                    final data = snapshot.data;
                    return Column(
                      children: [
                        _infoRow(Icons.person_pin, "Posted By", data?['full_name']),
                        _infoRow(Icons.phone_android, "Mobile", data?['mobile_no']),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: job['name']))),
                    child: const Text("VIEW FULL DETAILS", style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.indigo),
          const SizedBox(width: 8),
          Text("$label: ", style: const TextStyle(color: Colors.grey)),
          Text(value ?? "N/A", style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// --- DETAIL SCREEN ---

class JobDetailScreen extends StatefulWidget {
  final String jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  Map<String, dynamic>? jobDetails;
  bool isLoading = true;
  String username = "";
  String userEmail = "";
  String userRole = "";
  @override
  void initState() {
    super.initState();
    _fetchJobDetails();
    _loadUserData();
  }
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('savedEmail') ?? "";
    setState(() {
      username = prefs.getString('full_name') ?? "ERP User";
      userEmail = email;
      userRole = prefs.getString('userRole') ?? "User";
    });
  }
  Future<void> _fetchJobDetails() async {
    try {
      final response = await ApiService().dio.get(
        "/api/method/application.application.utils.py.api.get_job_details",
        queryParameters: {"job_id": widget.jobId},
      );
      setState(() {
        print("REPOSENE ----------------");
        print(response.data);
        jobDetails = response.data["message"];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }
  Future<void> applyforjob(String jobId) async {
    try {
      final response = await ApiService().dio.post(
        "/api/method/application.application.utils.py.api.apply_for_job",
        data: {
          "job_id": jobId,
          "user": username,
          "email": userEmail
        },
      );

      print("Response data: ${response.data}");

      String message = response.data?['message']?.toString() ?? "";

      if (message.contains("Traceback")) {
        throw Exception(
          message.split("Exception:").last.trim(),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Applied successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }

    } on DioException catch (e) {
      String errorMsg = "Something went wrong";

      if (e.response != null) {
        final data = e.response!.data;

        if (data is Map) {
          if (data['message'] != null) {
            errorMsg = data['message'].toString();
          } else if (data['exception'] != null) {
            errorMsg =
                data['exception'].toString().split(':').last.trim();
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (jobDetails == null) return const Scaffold(body: Center(child: Text("Error loading")));

    return Scaffold(
      backgroundColor: Colors.grey[50], // Soft background to make cards pop
      appBar: AppBar(
        title: const Text("Job Details", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jobDetails!['job_title'],
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(height: 20),

                 _buildSectionTitle("Job Overview"),
                  const SizedBox(height: 10),
                  _buildOverviewGrid(),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Full Address"), 
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                jobDetails!['location'] ?? "City Not Specified",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                jobDetails!['location_details'] ?? "Full address not available",
                                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.4),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final String lat = jobDetails!['latitude']?.toString() ?? '0';
                                  final String lng = jobDetails!['longitude']?.toString() ?? '0';

                                  final Uri url = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");

                                  try {
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(
                                        url, 
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } else {
                                      debugPrint("Could not launch maps for: $lat, $lng");
                                    }
                                  } catch (e) {
                                    debugPrint("Error launching maps: $e");
                                  }
                                },
                                child: Row(
                                  children: const [
                                    Icon(Icons.map_outlined, size: 18, color: Colors.blue),
                                    SizedBox(width: 4),
                                    Text(
                                      "View on Map",
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),
                  _buildSectionTitle("Posting Details"),
                  const SizedBox(height: 10),
                  _buildContactCard(),
                  const SizedBox(height: 25),

                  _buildSectionTitle("Description"),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Text(
                      jobDetails!['description'] ?? "No description available.",
                      style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ... Description Container ...
const SizedBox(height: 20),

ListTile(
  onTap: _handleCalendarSync,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: BorderSide(color: Colors.indigo.withOpacity(0.2)),
  ),
  tileColor: Colors.indigo.withOpacity(0.05),
  leading: const Icon(Icons.event_available, color: Colors.indigo),
  title: const Text(
    "Mark to Calendar",
    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
  ),
  subtitle: const Text("Sync this job to your phone calendar"),
  trailing: const Icon(Icons.add, color: Colors.indigo),
),

const SizedBox(height: 20),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildApplyButton(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
    );
  }

  Widget _buildOverviewGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 15,
        children: [
          _buildGridItem(Icons.location_on, "Location", jobDetails!['location'], Colors.red),
          _buildGridItem(Icons.currency_rupee, "Salary", "₹${jobDetails!['salary']}", Colors.green),
          _buildGridItem(Icons.people, "Openings", "${jobDetails!['no_of_person']} Vacancies", Colors.orange),
          _buildGridItem(Icons.desktop_windows_outlined, 'Designation', jobDetails!['designation'], Colors.indigo)
        ],
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo[100]!),
      ),
      child: Column(
        children: [
          _buildAnimatedListTile(Icons.email_outlined, "Email", jobDetails!['owner'],1,canCopy: true),
          const Divider(color: Colors.indigo, thickness: 0.1),
          _buildAnimatedListTile(Icons.person_outline, "Contact Person", jobDetails!['name1'] ?? "Not Available",2,canCopy: false),
          const Divider(color: Colors.indigo, thickness: 0.1),
          _buildAnimatedListTile(Icons.phone_android_outlined, "Mobile Number",jobDetails!['mobile_number'] ?? "Not Available",3,canCopy: true),
          const Divider(color: Colors.indigo, thickness: 0.1),
          _buildAnimatedListTile(Icons.calendar_month_outlined, "Date", jobDetails!['date'],4,canCopy: false),
          const Divider(color: Colors.indigo, thickness: 0.1),
          _buildAnimatedListTile(Icons.access_time_rounded,"Time",formatToIndianTime(jobDetails!['time']),5,canCopy: false),
        ],
      ),
    );
  }

  // Helper: Grid Item for Overview
  Widget _buildGridItem(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 140,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper: ListTile for Contact Card
  Widget _buildListTile(IconData icon, String label, String value, {bool canCopy = true}) {
    print("Building ListTile for $label with value: $value");
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (canCopy) {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("$label copied!"), duration: const Duration(seconds: 1)),
            );
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: Colors.indigo),
              ),
              const SizedBox(width: 15),
              Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              const Spacer(),
              Row(
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.indigo, fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildAnimatedListTile(IconData icon, String label, String value, int index,{bool canCopy = false}) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(50 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: _buildListTile(icon, label, value, canCopy: canCopy),
    );
  }

  Widget _buildApplyButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: () {
            applyforjob(jobDetails!['name']);
          },
          child: const Text("APPLY FOR THIS JOB", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Future<void> _handleCalendarSync() async {
    final String dateStr = jobDetails!['date'] ?? DateTime.now().toString();
    final DateTime startTime = DateTime.tryParse(dateStr) ?? DateTime.now();
    
    // Set a default end time (e.g., 2 hours later) if not provided by API
    final DateTime endTime = startTime.add(const Duration(hours: 2));

    // 2. Create the Event object
    final event = Event(
      title: jobDetails!['title'] ?? 'Job Appointment',
      description: jobDetails!['description'] ?? '',
      location: "${jobDetails!['location'] ?? ''}, ${jobDetails!['location_details'] ?? ''}",
      startDate: startTime,
      endDate: endTime,
      allDay: false,
    );

    // 3. Call your Add2Calendar class
    try {
      bool success = await Add2Calendar.addEvent2Cal(event);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Calendar app opened!")),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to add to calendar: ${e.message}");
    }
  }
}

String formatToIndianTime(String? timeString) {
  if (timeString == null || timeString.isEmpty) return "Not specified";

  try {
    DateTime utcTime = DateTime.parse(timeString);
    DateTime istTime = utcTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('hh:mm a').format(istTime);
  } catch (e) {
    try {
      final parts = timeString.split(":");
      final now = DateTime.now();
      final dt = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return timeString; 
    }
  }
}