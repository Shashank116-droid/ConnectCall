import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/user_model.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onAudioCall;
  final VoidCallback onVideoCall;
  final String currentUserId;
  final bool isOnline;
  final bool isBlocked;
  final VoidCallback onToggleBlock;

  const UserTile({
    Key? key,
    required this.user,
    required this.onAudioCall,
    required this.onVideoCall,
    required this.currentUserId,
    required this.isOnline,
    required this.isBlocked,
    required this.onToggleBlock,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (user.uid == currentUserId) return const SizedBox.shrink(); // Don't show self

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(user.profileImageUrl!)
                : null,
            child: (user.profileImageUrl == null || user.profileImageUrl!.isEmpty)
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          if (!isBlocked && isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
              ),
            )
        ],
      ),
      title: Text(user.name, style: TextStyle(
        fontWeight: FontWeight.w600, 
        fontSize: 18,
        decoration: isBlocked ? TextDecoration.lineThrough : null,
      )),
      subtitle: Text(
        isBlocked ? 'Blocked' : (isOnline ? 'Online' : 'Offline'), 
        style: TextStyle(
          color: isBlocked ? Colors.red : (isOnline ? Colors.green : Colors.grey.shade500), 
          fontSize: 13,
          fontWeight: isBlocked ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isBlocked) ...[
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.call, 
                  color: Theme.of(context).colorScheme.primary, 
                  size: 22),
                onPressed: onAudioCall,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.videocam, 
                  color: Theme.of(context).colorScheme.secondary, 
                  size: 22),
                onPressed: onVideoCall,
              ),
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle_block') {
                onToggleBlock();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'toggle_block',
                child: Text(isBlocked ? 'Unblock User' : 'Block User', style: TextStyle(color: isBlocked ? Colors.green : Colors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
