import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../providers/history_provider.dart';
import '../../auth/providers/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
    final historyProvider = context.watch<HistoryProvider>();
    final currentUserId = context.read<AuthProvider>().user?.uid;

    if (historyProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (historyProvider.history.isEmpty) {
      return const Center(child: Text('No call history found'));
    }

    return ListView.separated(
      itemCount: historyProvider.history.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final call = historyProvider.history[index];
        final isOutgoing = call.callerId == currentUserId;
        final otherName = isOutgoing ? (call.calleeNames.isNotEmpty ? call.calleeNames.first : 'Unknown') : call.callerName;
        
        IconData callIcon;
        Color iconColor;
        
        if (call.status == 'missed') {
          callIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
          iconColor = Colors.red;
        } else if (call.status == 'rejected') {
          callIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
          iconColor = Colors.orange;
        } else if (call.status == 'busy') {
          callIcon = Icons.phone_in_talk;
          iconColor = Colors.orange;
        } else if (call.status == 'failed' || call.status == 'disconnected') {
          callIcon = Icons.error_outline;
          iconColor = Colors.red;
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            child: Icon(call.isVideo ? Icons.videocam : Icons.call, color: Theme.of(context).colorScheme.primary),
          ),
          title: Text(otherName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Row(
            children: [
              Icon(callIcon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Text(
                '${DateFormat('MMM d, h:mm a').format(call.timestamp)}$durationStr',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ],
          ),
          trailing: Text(call.status.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
        ).animate().fade(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.1, curve: Curves.easeOutQuad);
      },
    );
  }
}
