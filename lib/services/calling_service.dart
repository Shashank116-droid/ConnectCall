import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../models/call_model.dart';

const Map<String, dynamic> _iceServers = {
  'iceServers': [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ],
};

class CallingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  MediaStream? _localStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  
  // Mesh Network Maps
  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, RTCVideoRenderer> remoteRenderers = {};
  final Set<String> connectedPeers = {};  // Tracks all connected peers (audio + video)
  bool _isVideoCall = false;
  Timer? _statsTimer;

  // Callbacks
  Function(String uid)? onRemoteStreamAdded;
  Function(String uid)? onRemoteStreamRemoved;
  VoidCallback? onConnectionDisconnected; 
  Function(String quality)? onNetworkQualityUpdate; // 'Good', 'Fair', 'Poor'

  final List<StreamSubscription> _subs = [];

  // ---------------------------------------------------------------------------
  // Firestore Signaling
  // ---------------------------------------------------------------------------

  Future<CallModel> initiateCall({
    required String callerId,
    required String callerName,
    required List<String> calleeIds,
    required List<String> calleeNames,
    required bool isVideo,
  }) async {
    final callId = _uuid.v4();
    final channelId = 'channel_$callId';

    final call = CallModel(
      id: callId,
      callerId: callerId,
      callerName: callerName,
      calleeIds: calleeIds,
      calleeNames: calleeNames,
      joinedIds: [callerId], // Caller is in the room automatically
      isVideo: isVideo,
      status: 'ringing',
      channelId: channelId,
      timestamp: DateTime.now(),
    );

    await _firestore.collection('calls').doc(callId).set(call.toJson());
    return call;
  }
  
  Future<void> inviteToCall(String callId, String newUserId, String newUserName) async {
    await _firestore.collection('calls').doc(callId).update({
      'calleeIds': FieldValue.arrayUnion([newUserId]),
      'calleeNames': FieldValue.arrayUnion([newUserName]),
      'status': 'ringing'
    });
  }

  Future<void> updateCallStatus(String callId, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'connected') {
      updates['connectedAt'] = DateTime.now().toIso8601String();
    } else if (status == 'ended' || status == 'rejected' || status == 'missed') {
      updates['endedAt'] = DateTime.now().toIso8601String();
    }
    await _firestore.collection('calls').doc(callId).update(updates);
  }

  Future<void> joinCall(String callId, String myUid) async {
    await _firestore.collection('calls').doc(callId).update({
      'joinedIds': FieldValue.arrayUnion([myUid]),
      'status': 'connected',
    });
  }

  Stream<List<CallModel>> getIncomingCalls(String userId) {
    return _firestore
        .collection('calls')
        .where('calleeIds', arrayContains: userId)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => CallModel.fromJson(doc.data())).toList());
  }

  Stream<CallModel?> getCallStatusStream(String callId) {
    return _firestore.collection('calls').doc(callId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CallModel.fromJson(doc.data()!);
      }
      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // WebRTC Setup & Mesh Logic
  // ---------------------------------------------------------------------------

  Future<void> initWebRTC(bool isVideo) async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      if (isVideo) Permission.camera,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }
    if (isVideo && statuses[Permission.camera] != PermissionStatus.granted) {
      throw Exception('Camera permission denied');
    }

    await localRenderer.initialize();

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': isVideo ? {'facingMode': 'user', 'width': 640, 'height': 480} : false,
    });

    localRenderer.srcObject = _localStream;
    _isVideoCall = isVideo;
  }

  void listenToParticipants(String callId, String myUid) {
    final sub = _firestore.collection('calls').doc(callId).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final joinedIds = List<String>.from(data['joinedIds'] ?? []);
      
      // Mark the call connection process started
      // Start polling stats
      _startStatsTimer();
      
      for (final uid in joinedIds) {
        if (uid != myUid && !_peerConnections.containsKey(uid)) {
           _connectToUser(callId, uid, myUid);
        }
      }
    });
    _subs.add(sub);
  }

  Future<void> _connectToUser(String callId, String remoteUid, String myUid) async {
    final isInitiator = myUid.compareTo(remoteUid) < 0;
    final connectionId = isInitiator ? '${myUid}_$remoteUid' : '${remoteUid}_$myUid';

    debugPrint('[ConnectCall Mesh] Connecting to $remoteUid as ${isInitiator ? 'Offerer' : 'Answerer'}');

    final pc = await createPeerConnection(_iceServers);
    _peerConnections[remoteUid] = pc;
    
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onTrack = (event) async {
      debugPrint('[ConnectCall Mesh] ✅ Received track from $remoteUid (kind: ${event.track.kind})');
      if (event.track.kind == 'video' && event.streams.isNotEmpty) {
        // Only create renderers for video tracks
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = event.streams[0];
        remoteRenderers[remoteUid] = renderer;
        onRemoteStreamAdded?.call(remoteUid);
      } else if (event.track.kind == 'audio') {
        // Audio tracks work automatically through PeerConnection — no renderer needed
        debugPrint('[ConnectCall Mesh] 🔊 Audio track connected for $remoteUid');
      }
    };

    pc.onConnectionState = (state) {
      debugPrint('[ConnectCall Mesh] Connection to $remoteUid is $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        connectedPeers.add(remoteUid);
        onRemoteStreamAdded?.call(remoteUid);  // Notify UI that a peer is connected
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed || 
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _removeRemoteUser(remoteUid);
      }
    };

    final connDoc = _firestore.collection('calls').doc(callId).collection('connections').doc(connectionId);

    pc.onIceCandidate = (candidate) {
      debugPrint('[ConnectCall Mesh] 🧊 Sending ICE to $remoteUid');
      connDoc.collection(isInitiator ? 'callerCandidates' : 'calleeCandidates').add({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    if (isInitiator) {
      // I am the initiator, I create the offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await connDoc.set({'offer': {'sdp': offer.sdp, 'type': offer.type}}, SetOptions(merge: true));

      _subs.add(connDoc.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data['answer'] != null && await pc.getRemoteDescription() == null) {
          debugPrint('[ConnectCall Mesh] 📥 Received Answer from $remoteUid');
          final answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
          await pc.setRemoteDescription(answer);
        }
      }));

      _subs.add(connDoc.collection('calleeCandidates').snapshots().listen((snap) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            pc.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        }
      }));
    } else {
      // I am the receiver, I wait for the offer
      _subs.add(connDoc.snapshots().listen((snap) async {
        final data = snap.data();
        if (data != null && data['offer'] != null && await pc.getRemoteDescription() == null) {
          debugPrint('[ConnectCall Mesh] 📥 Received Offer from $remoteUid');
          final offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
          await pc.setRemoteDescription(offer);
          
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await connDoc.update({'answer': {'sdp': answer.sdp, 'type': answer.type}});
          debugPrint('[ConnectCall Mesh] 📤 Sent Answer to $remoteUid');
        }
      }));

      _subs.add(connDoc.collection('callerCandidates').snapshots().listen((snap) {
        for (var change in snap.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data()!;
            pc.addCandidate(RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLineIndex']));
          }
        }
      }));
    }
  }

  void _removeRemoteUser(String uid) {
    _peerConnections[uid]?.close();
    _peerConnections.remove(uid);
    
    remoteRenderers[uid]?.srcObject = null;
    remoteRenderers[uid]?.dispose();
    remoteRenderers.remove(uid);
    connectedPeers.remove(uid);
    
    onRemoteStreamRemoved?.call(uid);
    
    if (_peerConnections.isEmpty) {
      _statsTimer?.cancel();
      onConnectionDisconnected?.call();
    }
  }

  // ---------------------------------------------------------------------------
  // Network Stats Polling
  // ---------------------------------------------------------------------------
  void _startStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_peerConnections.isEmpty) return;

      double maxRtt = 0.0;
      for (var pc in _peerConnections.values) {
        try {
          final stats = await pc.getStats();
          for (var report in stats) {
            // 'candidate-pair' contains RTT info in WebRTC
            if (report.type == 'candidate-pair') {
              final values = report.values;
              // Check if it's the active pair (sometimes 'state' == 'succeeded' or 'nominated' is true)
              if (values.containsKey('currentRoundTripTime')) {
                final rttVal = values['currentRoundTripTime'];
                if (rttVal != null) {
                  final rtt = (rttVal is num) ? rttVal.toDouble() : double.tryParse(rttVal.toString()) ?? 0.0;
                  if (rtt > maxRtt) maxRtt = rtt;
                }
              }
            }
          }
        } catch (e) {
          debugPrint('[ConnectCall] ⚠️ Error getting stats: $e');
        }
      }

      String quality = 'Good';
      if (maxRtt == 0.0) {
        quality = 'Good'; // Default if not found yet
      } else if (maxRtt > 0.3) {
        quality = 'Poor'; // > 300ms RTT
      } else if (maxRtt > 0.15) {
        quality = 'Fair'; // > 150ms RTT
      }

      onNetworkQualityUpdate?.call(quality);
    });
  }

  // ---------------------------------------------------------------------------
  // Media Controls
  // ---------------------------------------------------------------------------

  Future<void> toggleMute(bool isMuted) async {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      audioTracks[0].enabled = !isMuted;
    }
  }

  Future<void> switchCamera() async {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      await Helper.switchCamera(videoTracks[0]);
    }
  }

  Future<void> toggleCamera(bool isEnabled) async {
    final videoTracks = _localStream?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      videoTracks[0].enabled = isEnabled;
    }
  }

  Future<void> setSpeakerphone(bool enabled) async {
    final audioTracks = _localStream?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      audioTracks[0].enableSpeakerphone(enabled);
    }
  }

  // ---------------------------------------------------------------------------
  // Screen Sharing
  // ---------------------------------------------------------------------------

  MediaStream? _screenStream;
  bool _isScreenSharing = false;
  bool get isScreenSharing => _isScreenSharing;

  static const MethodChannel _screenShareChannel = MethodChannel('com.example.connectcall/screenshare');

  Future<bool> startScreenShare() async {
    try {
      if (Platform.isAndroid) {
        // Step 1: Request permission first!
        // Android 14+ requires the user to grant permission BEFORE we start a 
        // foreground service with type "mediaProjection".
        final hasPermission = await Helper.requestCapturePermission();
        if (!hasPermission) {
          debugPrint('[ConnectCall] ⚠️ Screen share permission denied by user');
          return false;
        }

        // Step 2: Now that permission is granted, start the foreground service.
        final bool? serviceReady =
            await _screenShareChannel.invokeMethod<bool>('startForegroundService');
        if (serviceReady != true) {
          debugPrint('[ConnectCall] ⚠️ Foreground service failed to start');
          return false;
        }
      }

      // Step 3: Get the display media stream. 
      // Because we already requested permission, this will proceed immediately.
      _screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false, // System audio capture not reliable on all devices
      });

      if (_screenStream == null || _screenStream!.getVideoTracks().isEmpty) {
        if (Platform.isAndroid) {
          await _screenShareChannel.invokeMethod('stopForegroundService');
        }
        return false;
      }

      final screenTrack = _screenStream!.getVideoTracks()[0];

      // Listen for the user stopping screen share via the system UI notification
      screenTrack.onEnded = () {
        stopScreenShare();
      };

      // Replace the camera video track with screen track in ALL peer connections
      for (final pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(screenTrack);
          }
        }
      }

      // Update local renderer to show screen preview
      localRenderer.srcObject = _screenStream;
      _isScreenSharing = true;
      return true;
    } catch (e) {
      debugPrint('[ConnectCall] ⚠️ Screen share error: $e');
      // Clean up the foreground service if screen share failed
      if (Platform.isAndroid) {
        try {
          await _screenShareChannel.invokeMethod('stopForegroundService');
        } catch (_) {}
      }
      return false;
    }
  }

  Future<void> stopScreenShare() async {
    if (!_isScreenSharing || _localStream == null) return;

    // Restore the camera video track in ALL peer connections
    final cameraVideoTracks = _localStream!.getVideoTracks();
    if (cameraVideoTracks.isNotEmpty) {
      final cameraTrack = cameraVideoTracks[0];
      for (final pc in _peerConnections.values) {
        final senders = await pc.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(cameraTrack);
          }
        }
      }
    }

    // Restore local renderer to camera
    localRenderer.srcObject = _localStream;

    // Dispose the screen stream
    if (_screenStream != null) {
      for (final track in _screenStream!.getTracks()) {
        await track.stop();
      }
      await _screenStream!.dispose();
      _screenStream = null;
    }

    _isScreenSharing = false;

    if (Platform.isAndroid) {
      await _screenShareChannel.invokeMethod('stopForegroundService');
    }
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> hangUp(String? callId, String myUid) async {
    _statsTimer?.cancel();
    _statsTimer = null;

    for (var sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();

    for (var pc in _peerConnections.values) {
      await pc.close();
    }
    _peerConnections.clear();

    for (var renderer in remoteRenderers.values) {
      renderer.srcObject = null;
      await renderer.dispose();
    }
    remoteRenderers.clear();

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await track.stop();
      }
      await _localStream!.dispose();
      _localStream = null;
    }

    // Clean up screen share stream if active
    if (_screenStream != null) {
      for (final track in _screenStream!.getTracks()) {
        await track.stop();
      }
      await _screenStream!.dispose();
      _screenStream = null;
      _isScreenSharing = false;

      if (Platform.isAndroid) {
        await _screenShareChannel.invokeMethod('stopForegroundService');
      }
    }
    
    localRenderer.srcObject = null;

    if (callId != null) {
      // Remove myself from joinedIds
      try {
        await _firestore.collection('calls').doc(callId).update({
          'joinedIds': FieldValue.arrayRemove([myUid])
        });
      } catch (e) {
        debugPrint('[ConnectCall Mesh] Error removing from joinedIds: $e');
      }
    }
    
    connectedPeers.clear();
  }

  Future<void> disposeRenderers() async {
    await localRenderer.dispose();
    for (var r in remoteRenderers.values) {
      await r.dispose();
    }
  }

  bool get hasLocalStream => _localStream != null;
}
