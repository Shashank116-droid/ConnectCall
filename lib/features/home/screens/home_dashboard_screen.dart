import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../auth/providers/auth_provider.dart';
import '../../history/providers/history_provider.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        context.read<HistoryProvider>().fetchHistory(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final historyProvider = context.watch<HistoryProvider>();
    final currentUser = authProvider.user;

    if (currentUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // Take only the top 4 recent calls
    final recentCalls = historyProvider.history.take(4).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Profile Section
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ]
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    backgroundImage: currentUser.profileImageUrl != null
                        ? CachedNetworkImageProvider(currentUser.profileImageUrl!)
                        : null,
                    child: currentUser.profileImageUrl == null
                        ? Icon(Icons.person, size: 36, color: Colors.blue.shade700)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${currentUser.name}!',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser.email,
                          style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: -0.1, duration: 400.ms, curve: Curves.easeOutQuad),
          
          const SizedBox(height: 24),
          
          // Recent Calls Section
          const Text(
            'Recent Calls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Expanded(
            child: historyProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : recentCalls.isEmpty
                    ? const Center(child: Text('No recent calls found'))
                    : ListView.separated(
                        itemCount: recentCalls.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final call = recentCalls[index];
                          final isOutgoing = call.callerId == currentUser.uid;
                          final otherName = isOutgoing ? (call.calleeNames.isNotEmpty ? call.calleeNames.first : 'Unknown') : call.callerName;

                          IconData callIcon;
                          Color iconColor;

                          if (call.status == 'missed') {
                            callIcon = Icons.call_missed;
                            iconColor = Colors.red;
                          } else if (call.status == 'rejected') {
                            callIcon = Icons.call_missed;
                            iconColor = Colors.orange;
                          } else {
                            callIcon = isOutgoing ? Icons.call_made : Icons.call_received;
                            iconColor = Colors.green;
                          }

                          String durationStr = '';
                          if (call.connectedAt != null && call.endedAt != null) {
                            final diff = call.endedAt!.difference(call.connectedAt!);
                            durationStr = ' • ${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}';
                          }

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              child: Text(otherName.isNotEmpty ? otherName[0].toUpperCase() : '?', 
                                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                              ),
                            ),
                            title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            subtitle: Row(
                              children: [
                                Icon(callIcon, color: iconColor, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  '${DateFormat('MMM d, h:mm a').format(call.timestamp)}$durationStr',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(call.isVideo ? Icons.videocam : Icons.call, color: Theme.of(context).primaryColor),
                              onPressed: () {},
                            ),
                          ).animate().fade(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.1, curve: Curves.easeOutQuad);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
