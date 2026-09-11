import 'package:connectcall/features/call/providers/call_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/contacts_provider.dart';
import '../widgets/user_tile.dart';
import '../../auth/providers/auth_provider.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final contactsProvider = context.watch<ContactsProvider>();
    final currentUser = context.read<AuthProvider>().user;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              labelText: 'Search people...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => contactsProvider.search(value),
          ),
        ),
        Expanded(
          child: contactsProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : contactsProvider.users.isEmpty
                  ? const Center(child: Text('No contacts found'))
                  : ListView.separated(
                      itemCount: contactsProvider.users.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final user = contactsProvider.users[index];
                        return UserTile(
                          user: user,
                          currentUserId: currentUser?.uid ?? '',
                          isOnline: contactsProvider.isUserOnline(user.uid),
                          isBlocked: currentUser?.blockedUsers.contains(user.uid) ?? false,
                          onToggleBlock: () async {
                            if (currentUser != null) {
                              final isBlocked = currentUser.blockedUsers.contains(user.uid);
                              await contactsProvider.toggleBlockUser(currentUser.uid, user.uid, isBlocked);
                              
                              // Update local user model
                              final updatedBlockedUsers = List<String>.from(currentUser.blockedUsers);
                              if (isBlocked) {
                                updatedBlockedUsers.remove(user.uid);
                              } else {
                                updatedBlockedUsers.add(user.uid);
                              }
                              context.read<AuthProvider>().updateUser(
                                currentUser.copyWith(blockedUsers: updatedBlockedUsers)
                              );
                            }
                          },
                          onAudioCall: () async {
                            final isBlocked = currentUser?.blockedUsers.contains(user.uid) ?? false;
                            if (isBlocked) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unblock this user to make a call.')));
                              return;
                            }
                            final isOnline = contactsProvider.isUserOnline(user.uid);
                            if (!await _canInitiateCall(context, isOnline, user.name)) return;

                            if (!context.mounted) return;
                            final authUser = context.read<AuthProvider>().user!;
                            final error = await context.read<CallProvider>().initiateCall(
                              callerId: authUser.uid,
                              callerName: authUser.name,
                              calleeIds: [user.uid],
                              calleeNames: [user.name],
                              isVideo: false,
                            );
                            if (context.mounted) {
                              if (error != null) {
                                _showPermissionError(context, error);
                              } else {
                                context.pushNamed('call');
                              }
                            }
                          },
                          onVideoCall: () async {
                            final isBlocked = currentUser?.blockedUsers.contains(user.uid) ?? false;
                            if (isBlocked) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unblock this user to make a call.')));
                              return;
                            }
                            final isOnline = contactsProvider.isUserOnline(user.uid);
                            if (!await _canInitiateCall(context, isOnline, user.name)) return;

                            if (!context.mounted) return;
                            final authUser = context.read<AuthProvider>().user!;
                            final error = await context.read<CallProvider>().initiateCall(
                              callerId: authUser.uid,
                              callerName: authUser.name,
                              calleeIds: [user.uid],
                              calleeNames: [user.name],
                              isVideo: true,
                            );
                            if (context.mounted) {
                              if (error != null) {
                                _showPermissionError(context, error);
                              } else {
                                context.pushNamed('call');
                              }
                            }
                          },
                        ).animate().fade(duration: 300.ms, delay: (50 * index).ms).slideX(begin: 0.1, curve: Curves.easeOutQuad);
                      },
                    ),
        ),
      ],
    );
  }

  Future<bool> _canInitiateCall(BuildContext context, bool isOnline, String userName) async {
    if (!isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot call $userName because they are currently offline.')),
      );
      return false;
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection available.')),
        );
      }
      return false;
    }

    return true;
  }

  void _showPermissionError(BuildContext context, String error) {
    final isPermanent = error.toLowerCase().contains('permanently');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        action: isPermanent
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => openAppSettings(),
              )
            : null,
      ),
    );
  }
}
