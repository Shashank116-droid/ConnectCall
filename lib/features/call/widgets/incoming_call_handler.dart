import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../models/call_model.dart';
import '../../../services/calling_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/call_provider.dart';

class IncomingCallHandler extends StatefulWidget {
  final Widget child;
  const IncomingCallHandler({Key? key, required this.child}) : super(key: key);

  @override
  State<IncomingCallHandler> createState() => _IncomingCallHandlerState();
}

class _IncomingCallHandlerState extends State<IncomingCallHandler> {
  CallModel? _activeIncomingCall;

  @override
  void initState() {
    super.initState();
    // Start listening when widget mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenForIncomingCalls();
    });
  }

  void _listenForIncomingCalls() {
    final authUser = context.read<AuthProvider>().user;
    if (authUser == null) return;

    final callingService = CallingService();
    callingService.getIncomingCalls(authUser.uid).listen((calls) {
      if (!mounted) return;

      final callProvider = context.read<CallProvider>();
      final isEngagedInActiveCall = callProvider.currentCall != null;

      if (calls.isNotEmpty) {
        if (_activeIncomingCall == null) {
          final call = calls.first;
          final isBlocked = authUser.blockedUsers.contains(call.callerId);

          if (isBlocked) {
            // Silently reject the call if the caller is blocked
            callingService.updateCallStatus(call.id, 'rejected');
          } else if (isEngagedInActiveCall) {
            // User is already in an active call, mark this incoming call as busy
            callingService.updateCallStatus(call.id, 'busy');
          } else {
            // User is free and caller is not blocked, show dialog
            setState(() => _activeIncomingCall = call);
            _showIncomingCallDialog(call);
          }
        } else {
          // We are already showing an incoming call dialog for someone else
          for (var call in calls) {
            if (call.id != _activeIncomingCall!.id) {
              callingService.updateCallStatus(call.id, 'busy');
            }
          }
        }
      } else if (calls.isEmpty && _activeIncomingCall != null) {
        // Call was cancelled or answered elsewhere
        setState(() => _activeIncomingCall = null);
        if (Navigator.of(context, rootNavigator: true).canPop()) {
           Navigator.of(context, rootNavigator: true).pop(); // Close dialog
        }
      }
    });
  }

  void _showIncomingCallDialog(CallModel call) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.9),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF001F3F), Color(0xFF000A1F)], // Deep premium Truecaller dark blue
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(height: 40),
                  Text(
                    'Incoming ${call.isVideo ? 'Video' : 'Audio'} Call',
                    style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8), letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 20),
                  // Huge Profile Picture
                  CircleAvatar(
                    radius: 80,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                    child: Text(
                      call.callerName.isNotEmpty ? call.callerName[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 70, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Caller Name
                  Text(
                    call.callerName,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'ConnectCall',
                    style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.6)),
                  ),
                  const Spacer(),
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Decline Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () {
                                setState(() => _activeIncomingCall = null);
                                context.read<CallProvider>().rejectCall(call);
                                Navigator.of(dialogContext, rootNavigator: true).pop();
                              },
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                                  ],
                                ),
                                child: const Icon(Icons.call_end, color: Colors.white, size: 36),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Decline', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        // Accept Button
                        Column(
                          children: [
                            GestureDetector(
                              onTap: () async {
                                setState(() => _activeIncomingCall = null);
                                Navigator.of(dialogContext, rootNavigator: true).pop();
                                
                                final currentUserId = context.read<AuthProvider>().user!.uid;
                                try {
                                  // Accept the call first so CallProvider has data before we navigate
                                  final error = await context.read<CallProvider>().acceptCall(call, currentUserId);
                                  if (error != null && mounted) {
                                    _showPermissionError(context, error);
                                  } else if (mounted) {
                                    context.pushNamed('call');
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to accept: $e')));
                                  }
                                }
                              },
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
                                  ],
                                ),
                                child: const Icon(Icons.call, color: Colors.white, size: 36),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Accept', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
