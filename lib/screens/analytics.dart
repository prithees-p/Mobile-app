import 'package:flutter/material.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("Performance Analytics", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Hiring Efficiency"),
            const SizedBox(height: 15),
            _buildVelocityCard(),
            const SizedBox(height: 25),
            _buildSectionTitle("Demand by Designation"),
            const SizedBox(height: 15),
            _buildDistributionChart(),
            const SizedBox(height: 25),
            _buildSectionTitle("Top Performing Locations"),
            _buildLocationRankings(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo));
  }

  // --- FEATURE 1: VELOCITY CARD ---
  Widget _buildVelocityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.indigo, Colors.blueAccent]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric("Avg. Time to Fill", "4.2 Days", Icons.speed),
              _buildMetric("Success Rate", "88%", Icons.trending_up),
            ],
          ),
          const Divider(color: Colors.white24, height: 30),
          const Text(
            "You are hiring 15% faster than last month!",
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w300),
          )
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  // --- FEATURE 2: DISTRIBUTION (MOCK CHART) ---
  Widget _buildDistributionChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildProgressBar("Sales", 0.8, Colors.orange),
          _buildProgressBar("Engineering", 0.5, Colors.blue),
          _buildProgressBar("Marketing", 0.3, Colors.green),
          _buildProgressBar("Operations", 0.9, Colors.purple),
        ],
      ),
    );
  }

  Widget _buildProgressBar(String label, double percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text("${(percent * 100).toInt()}%"),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: percent,
            backgroundColor: color.withOpacity(0.1),
            color: color,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRankings() {
    final locations = [
      {"name": "Mumbai", "jobs": "45"},
      {"name": "Bangalore", "jobs": "32"},
      {"name": "Delhi", "jobs": "28"},
    ];

    return Column(
      children: locations.map((loc) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: const Icon(Icons.location_on, color: Colors.indigo, size: 18)),
        title: Text(loc['name']!, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text("${loc['jobs']} Posts", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
      )).toList(),
    );
  }
}