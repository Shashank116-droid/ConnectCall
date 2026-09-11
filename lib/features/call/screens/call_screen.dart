import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';

import '../providers/call_provider.dart';
import '../../contacts/providers/contacts_provider.dart';
import '../../auth/providers/auth_provider.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({Key? key}) : super(key: key);

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    final callProvider = context.watch<CallProvider>();
    final call = callProvider.currentCall;
    final endReason = callProvider.endReason;

    if (call == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (endReason != null && endReason != 'ended') {
          String message = 'Call ended';
          if (endReason == 'busy') message = 'User is currently busy in another call';
          else if (endReason == 'missed') message = 'Call unanswered';
          else if (endReason == 'rejected') message = 'Call declined';
          else if (endReason == 'failed') message = 'Call failed due to an error';
          
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }

        if (GoRouter.of(context).canPop()) {
          context.pop();
        } else {
          context.goNamed('home');
        }
      });
      return const Scaffold(body: Center(child: Text('Call Ended')));
    }

    final remoteRenderers = callProvider.remoteRenderers.values.toList();
    final isGroup = remoteRenderers.length > 1;

    final authUser = context.watch<AuthProvider>().user;
    final isCaller = authUser?.uid == call.callerId;
    
    String displayName = 'Unknown';
    if (isGroup) {
      displayName = 'Group Call';
    } else {
      if (isCaller) {
        // I am calling them, show their name
        displayName = call.calleeNames.isNotEmpty ? call.calleeNames.first : 'Unknown';
      } else {
        // They are calling me, show their name
        displayName = call.callerName;
      }
    }

    String displayInitial = '?';
    if (isGroup) {
      displayInitial = 'G';
    } else if (displayName.isNotEmpty && displayName != 'Unknown') {
      displayInitial = displayName[0].toUpperCase();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        callProvider.setMinimized(true);
        context.goNamed('home');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000A1F),
        body: Container(
          decoration: BoxDecoration(
            color: call.isVideo ? Colors.black : null,
            gradient: call.isVideo ? null : const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF001F3F), Color(0xFF000A1F)], 
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                // Remote Video Grid
                if (call.isVideo && callProvider.remoteConnected)
                  Positioned.fill(child: _buildVideoGrid(remoteRenderers))
                else if (callProvider.remoteConnected && call.isVideo)
                  const Positioned.fill(child: Center(
                    child: Icon(Icons.person, size: 120, color: Colors.white54),
                  ))
                else if (call.isVideo)
                  const Positioned.fill(child: Center(
                    child: Text(
                      'Waiting for others to join...',
                      style: TextStyle(color: Colors.white),
                    ),
                  )),

                // Top Left Back Button (Minimize)
                Positioned(
                  top: 10,
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                    onPressed: () {
                      callProvider.setMinimized(true);
                      context.goNamed('home');
                    },
                  ),
                ),

                // Local Video (floating picture-in-picture)
                if (call.isVideo && callProvider.isLocalUserJoined && (callProvider.isCameraOn || callProvider.isScreenSharing))
                  Positioned(
                    top: 20,
                    right: 20,
                    width: 120,
                    height: 170,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RTCVideoView(
                            callProvider.localRenderer,
                            mirror: !callProvider.isScreenSharing, // Don't mirror screen share
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                        if (callProvider.isScreenSharing)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Sharing Screen',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Network Quality Indicator
                if (callProvider.remoteConnected)
                  Positioned(
                    top: 60, // Moved down to avoid overlapping the back button
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            callProvider.networkQuality == 'Poor'
                                ? Icons.signal_cellular_0_bar
                                : callProvider.networkQuality == 'Fair'
                                    ? Icons.signal_cellular_alt
                                    : Icons.signal_cellular_4_bar,
                            color: callProvider.networkQuality == 'Poor'
                                ? Colors.red
                                : callProvider.networkQuality == 'Fair'
                                    ? Colors.amber
                                    : Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            callProvider.networkQuality,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Audio is handled by the PeerConnection directly — no RTCVideoView needed

                // Caller Info Overlay (audio-only calls)
                if (!call.isVideo)
                  Positioned(
                    top: 80,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 70,
                          backgroundColor: Colors.blue.withOpacity(0.2),
                          child: Text(
                            displayInitial,
                            style: TextStyle(fontSize: 40, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          call.status == 'connected' ? '${call.joinedIds.length} connected' : 'Calling...',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.6), fontSize: 18),
                        ),
                      ],
                    ),
                  ),

              // Controls
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Add Person Button
                    GestureDetector(
                      onTap: () => _showAddPersonDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white24)
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.person_add, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text('Add Person', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: callProvider.isMuted ? Icons.mic_off : Icons.mic,
                          color: callProvider.isMuted ? Colors.white : Colors.white24,
                          iconColor: callProvider.isMuted ? Colors.black : Colors.white,
                          onPressed: callProvider.toggleMute,
                        ),
                        if (call.isVideo) ...[
                          _buildControlButton(
                            icon: callProvider.isCameraOn ? Icons.videocam : Icons.videocam_off,
                            color: callProvider.isCameraOn ? Colors.white24 : Colors.white,
                            iconColor: callProvider.isCameraOn ? Colors.white : Colors.black,
                            onPressed: callProvider.toggleCamera,
                          ),
                          if (callProvider.isCameraOn)
                            _buildControlButton(
                              icon: Icons.flip_camera_ios,
                              color: Colors.white24,
                              iconColor: Colors.white,
                              onPressed: callProvider.switchCamera,
                            ),
                          _buildControlButton(
                            icon: callProvider.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                            color: callProvider.isScreenSharing ? Colors.amber : Colors.white24,
                            iconColor: callProvider.isScreenSharing ? Colors.black : Colors.white,
                            onPressed: callProvider.toggleScreenShare,
                          ),
                        ] else ...[
                          _buildControlButton(
                            icon: callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                            color: callProvider.isSpeakerOn ? Colors.white : Colors.white24,
                            iconColor: callProvider.isSpeakerOn ? Colors.black : Colors.white,
                            onPressed: callProvider.toggleSpeaker,
                          ),
                        ],
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          iconColor: Colors.white,
                          onPressed: () => callProvider.endCall(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
     )
      );
  }

  Widget _buildVideoGrid(List<RTCVideoRenderer> renderers) {
    if (renderers.isEmpty) return const SizedBox();
    
    // Calculate layout based on number of participants
    int crossAxisCount = renderers.length == 1 ? 1 : 2;
    double childAspectRatio = renderers.length <= 2 ? 0.7 : 1.0;

    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: renderers.length,
      itemBuilder: (context, index) {
        return Stack(
          fit: StackFit.expand,
          children: [
            RTCVideoView(
              renderers[index],
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
            // Gradient overlay for name
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  )
                ),
                child: const Text('Participant', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Consumer2<ContactsProvider, CallProvider>(
          builder: (context, contactsProvider, callProvider, _) {
            final authUser = context.read<AuthProvider>().user;
            final currentCall = callProvider.currentCall;
            if (currentCall == null || authUser == null) return const SizedBox();

            // Filter out people already in the call
            final availableUsers = contactsProvider.users.where(
              (u) => !currentCall.calleeIds.contains(u.uid) && !currentCall.joinedIds.contains(u.uid) && u.uid != authUser.uid
            ).toList();

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Invite to Call', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (availableUsers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No more contacts available to invite.'),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableUsers.length,
                        itemBuilder: (context, index) {
                          final user = availableUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withOpacity(0.1),
                              child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?', style: TextStyle(color: Colors.blue.shade700)),
                            ),
                            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            trailing: IconButton(
                              icon: const Icon(Icons.add_circle, color: Colors.green),
                              onPressed: () {
                                callProvider.inviteToCall(user.uid, user.name);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invited ${user.name}')));
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }
}
