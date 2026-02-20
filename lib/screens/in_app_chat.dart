import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart'; 
import 'chat_details.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List users = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  int start = 0;
  final int limit = 20;
  bool hasMore = true;
  String searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  String? currentUserEmail;

  @override
  void initState() {
    super.initState();
    _loaduserData();
  }

  Future<void> _loaduserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserEmail = prefs.getString('userEmail');
    });
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool isRefresh = true}) async {
    if (isRefresh) {
      setState(() {
        isLoading = true;
        start = 0;
        users.clear();
        hasMore = true;
      });
    } else {
      setState(() => isLoadingMore = true);
    }

    try {
      // 1. Set up filters for the User list
      List<dynamic> filters = [
        ["name", "!=", currentUserEmail],
        ["enabled", "=", 1]
      ];

      if (searchQuery.isNotEmpty) {
        filters.add(["full_name", "like", "%$searchQuery%"]);
      }

      // 2. Fetch Users
      final response = await ApiService().dio.get(
        "/api/resource/User",
        queryParameters: {
          "fields": '["name", "full_name", "user_image"]',
          "filters": jsonEncode(filters), 
          "limit_start": start,
          "limit_page_length": limit,
          "order_by": "full_name asc"
        },
      );

      final List newData = response.data["data"] ?? [];

      // 3. Fetch Unseen Count for each user from the In-app Chat Doctype
      for (var user in newData) {
        try {
          final countResponse = await ApiService().dio.get(
            "/api/method/frappe.client.get_count",
            queryParameters: {
              "doctype": "In-app Chat",
              "filters": jsonEncode([
                ["from_user", "=", user['name']],
                ["to_user", "=", currentUserEmail],
                ["seen", "=", 0]
              ])
            },
          );
          user['unseen_count'] = countResponse.data["message"] ?? 0;
        } catch (e) {
          user['unseen_count'] = 0;
        }
      }

      setState(() {
        users.addAll(newData);
        isLoading = false;
        isLoadingMore = false;
        if (newData.length < limit) {
          hasMore = false;
        } else {
          start += limit;
        }
      });
    } catch (e) {
      debugPrint("Error fetching users: $e");
      setState(() {
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Messages", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                filled: true,
                fillColor: Colors.grey[100],
                suffixIcon: searchQuery.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      setState(() => searchQuery = "");
                      _fetchUsers();
                    }) 
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                setState(() => searchQuery = value);
                _fetchUsers();
              },
            ),
          ),

          // User List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _fetchUsers(isRefresh: true),
              child: isLoading 
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty 
                  ? const Center(child: Text("No users found"))
                  : ListView.builder(
                      itemCount: users.length + (hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == users.length) {
                          return _buildLoadMoreButton();
                        }

                        final user = users[index];
                        final int unseenCount = user['unseen_count'] ?? 0;

                        return Column(
                          children: [
                            ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.indigo[50],
                                child: Text(
                                  user['full_name']?[0]?.toUpperCase() ?? "U",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                                ),
                              ),
                              title: Text(
                                user['full_name'] ?? "No Name",
                                style: TextStyle(
                                  fontWeight: unseenCount > 0 ? FontWeight.bold : FontWeight.w500,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                user['name'] ?? "",
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (unseenCount > 0)
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: const BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unseenCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                              onTap: () async {
                                // Navigate and refresh when returning
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(
                                      toUserEmail: user['name'],
                                      toUserName: user['full_name'],
                                    ),
                                  ),
                                );
                                // Refresh list to update unseen counts
                                _fetchUsers(isRefresh: true);
                              },
                            ),
                            const Divider(height: 1, indent: 70, endIndent: 20),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: isLoadingMore
          ? const Center(child: CircularProgressIndicator())
          : TextButton(
              onPressed: () => _fetchUsers(isRefresh: false),
              child: const Text("Load More Users", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            ),
    );
  }
}