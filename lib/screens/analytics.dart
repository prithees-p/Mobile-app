import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool isLoading = true;
  Map<String, dynamic> stats = {};
  List<dynamic> distribution = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await ApiService().dio.get(
        "/api/method/great_indian.great_indian.utils.api.get_hiring_analytics",
        queryParameters: {"username": prefs.getString('savedEmail')},
      );

      if (response.statusCode == 200) {
        setState(() {
          stats = response.data["message"];
          distribution = stats["distribution"] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: isLoading 
              ? SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: const Center(child: CircularProgressIndicator()))
              : Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainStatsGrid(),
                      const SizedBox(height: 25),
                      _buildInsightSection(),
                      const SizedBox(height: 25),
                      _buildInteractiveDistribution(),
                    ],
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF1A237E),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text("Hiring Insights", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white)),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF311B92)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _fetchAnalytics),
      ],
    );
  }

  Widget _buildMainStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 15,
      mainAxisSpacing: 15,
      childAspectRatio: 1.4,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildGlassStatCard("Open Jobs", "${stats['open']}", Icons.rocket_launch, Colors.blue),
        _buildGlassStatCard("Avg. Days", "${stats['avg_days']}", Icons.bolt, Colors.amber),
        _buildGlassStatCard("Completed", "${stats['completed']}", Icons.verified, Colors.green),
        _buildGlassStatCard("Total", "${stats['total']}", Icons.pie_chart, Colors.purple),
      ],
    );
  }

  Widget _buildGlassStatCard(String title, String value, IconData icon, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(right: -10, top: -10, child: Icon(icon, size: 60, color: accent.withOpacity(0.05))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, size: 16, color: accent),
                ),
                const SizedBox(height: 10),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(
          image: const NetworkImage("https://www.transparenttextures.com/patterns/carbon-fibre.png"),
          opacity: 0.1,
          repeat: ImageRepeat.repeat,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Efficiency Score", style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 5),
          Row(
            children: [
              const Text("94.2%", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text("+2.4%", style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Text("You are performing better than 85% of company recruiters.", style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildInteractiveDistribution() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Role Demand Distribution", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
        const SizedBox(height: 15),
        ...distribution.map((item) => _buildAnimatedBar(item['designation'], item['total'])).toList(),
      ],
    );
  }

  Widget _buildAnimatedBar(String label, int count) {
    int maxCount = distribution.isNotEmpty ? distribution[0]['total'] : 1;
    double progress = count / maxCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey[100],
                    color: const Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Text("$count", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
        ],
      ),
    );
  }
}