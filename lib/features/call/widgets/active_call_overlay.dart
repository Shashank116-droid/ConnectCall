import 'package:connectcall/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../providers/call_provider.dart';
import '../../../routes/app_router.dart';

class ActiveCallOverlay extends StatefulWidget {
  const ActiveCallOverlay({Key? key}) : super(key: key);

  @override
  State<ActiveCallOverlay> createState() => _ActiveCallOverlayState();
}

class _ActiveCallOverlayState extends State<ActiveCallOverlay> {
  Offset position = const Offset(20, 100);

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, _) {
        final call = callProvider.currentCall;
        
        // Only show if call exists and is minimized
        if (call == null || !callProvider.isMinimized) {
          return const SizedBox.shrink();
        }

        Widget content;
        
        if (call.isVideo && callProvider.isCameraOn) {
          content = RTCVideoView(
            callProvider.localRenderer,
            mirror: !callProvider.isScreenSharing,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        } else if (call.isVideo && callProvider.remoteConnected && callProvider.remoteRenderers.isNotEmpty) {
           content = RTCVideoView(
            callProvider.remoteRenderers.values.first,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          );
        } else {
           content = Container(
             color: const Color(0xFF001F3F),
             child: const Center(
               child: Icon(Icons.call, color: Colors.green, size: 40),
             ),
           );
        }

        return Positioned(
          left: position.dx,
          top: position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                position += details.delta;
              });
            },
            onTap: () {
              // Navigate back to call screen first
              AppRouter.router?.pushNamed('call');
              callProvider.setMinimized(false);
            },
            child: Material(
              color: Colors.transparent,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    border: Border.all(color: Colors.white24, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(child: content),
                      // Expand icon
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.open_in_full, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
