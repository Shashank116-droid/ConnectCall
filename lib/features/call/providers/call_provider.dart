import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../../models/call_model.dart';
import '../../../../services/calling_service.dart';

class CallProvider extends ChangeNotifier {
  final CallingService _callingService;

  CallModel? _currentCall;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _isSpeakerOn = false;
  bool _isLocalUserJoined = false;
  String _networkQuality = 'Good';

  String? _endReason;
  Timer? _ringTimer;
  
  // Current user's ID to pass to service
  String? _currentUserId;

  CallModel? get currentCall => _currentCall;
  String? get endReason => _endReason;
  bool get isMuted => _isMuted;
  bool get isCameraOn => _isCameraOn;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isLocalUserJoined => _isLocalUserJoined;
  String get networkQuality => _networkQuality;
  
  bool get remoteConnected => _callingService.connectedPeers.isNotEmpty;

  RTCVideoRenderer get localRenderer => _callingService.localRenderer;
  Map<String, RTCVideoRenderer> get remoteRenderers => _callingService.remoteRenderers;

  CallProvider(this._callingService) {
    _callingService.onNetworkQualityUpdate = (quality) {
      if (_networkQuality != quality) {
        _networkQuality = quality;
        notifyListeners();
      }
    };
  }

  // ---------------------------------------------------------------------------
  // Call Lifecycle
  // ---------------------------------------------------------------------------

  Future<String?> initiateCall({
    required String callerId,
    required String callerName,
    required List<String> calleeIds,
    required List<String> calleeNames,
    required bool isVideo,
  }) async {
    _currentUserId = callerId;
    _currentCall = await _callingService.initiateCall(
      callerId: callerId,
      callerName: callerName,
      calleeIds: calleeIds,
      calleeNames: calleeNames,
      isVideo: isVideo,
    );
    _endReason = null;
    notifyListeners();

    _ringTimer = Timer(const Duration(seconds: 30), () {
      if (_currentCall != null && _currentCall!.status == 'ringing' && _currentCall!.joinedIds.length == 1) {
        endCall(finalStatus: 'missed');
      }
    });

    try {
      await _setupWebRTCAndConnect(isVideo: isVideo);
      _callingService.listenToParticipants(_currentCall!.id, callerId);
      _listenToCallStatus();
      return null;
    } catch (e) {
      debugPrint('[ConnectCall] ⚠️ Error initiating call: $e');
      endCall(); 
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> acceptCall(CallModel call, String currentUserId) async {
    _currentUserId = currentUserId;
    _currentCall = call;
    _endReason = null;
    notifyListeners();

    try {
      await _callingService.joinCall(call.id, currentUserId);
      await _setupWebRTCAndConnect(isVideo: call.isVideo);
      _callingService.listenToParticipants(call.id, currentUserId);
      _listenToCallStatus();
      return null;
    } catch (e) {
      debugPrint('[ConnectCall] ⚠️ Error accepting call: $e');
      endCall(finalStatus: 'failed');
      return e.toString().replaceAll('Exception: ', '');
    }
  }
  
  Future<void> inviteToCall(String targetUid, String targetName) async {
    if (_currentCall != null) {
      await _callingService.inviteToCall(_currentCall!.id, targetUid, targetName);
    }
  }

  Future<void> rejectCall(CallModel call) async {
    await _callingService.updateCallStatus(call.id, 'rejected');
    _currentCall = null;
    notifyListeners();
  }

  void endCall({String finalStatus = 'ended'}) {
    _ringTimer?.cancel();
    if (_currentCall != null) {
      final callId = _currentCall!.id;
      _endReason = finalStatus;
      
      _callingService.updateCallStatus(callId, finalStatus).catchError((e) {
        debugPrint('[ConnectCall] ⚠️ Failed to update call status: $e');
      });

      _cleanUpCall();
    }
  }

  // ---------------------------------------------------------------------------
  // WebRTC Setup
  // ---------------------------------------------------------------------------

  Future<void> _setupWebRTCAndConnect({required bool isVideo}) async {
    if (_currentCall == null) return;

    _isCameraOn = isVideo;
    _isMuted = false;
    _isSpeakerOn = false;

    _callingService.onRemoteStreamAdded = (uid) {
      notifyListeners();
    };

    _callingService.onRemoteStreamRemoved = (uid) {
      notifyListeners();
    };

    _callingService.onConnectionDisconnected = () {
      // In a mesh network, one disconnection shouldn't end the entire call
      // unless we are the only ones left (length == 1).
      // We will handle this gracefully.
    };

    await _callingService.initWebRTC(isVideo);
    _isLocalUserJoined = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Call Status Listener
  // ---------------------------------------------------------------------------

  void _listenToCallStatus() {
    if (_currentCall == null) return;

    _callingService.getCallStatusStream(_currentCall!.id).listen((callUpdate) {
      if (callUpdate == null) return;
      _currentCall = callUpdate;

      if (callUpdate.status == 'ended' ||
          callUpdate.status == 'rejected' ||
          callUpdate.status == 'missed' ||
          callUpdate.status == 'failed') {
        _endReason = callUpdate.status;
        _cleanUpCall();
      } else if (callUpdate.status == 'connected') {
        _ringTimer?.cancel();
      }
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  Future<void> _cleanUpCall() async {
    final callId = _currentCall?.id;
    final myUid = _currentUserId;
    
    _currentCall = null;
    _isLocalUserJoined = false;
    notifyListeners();

    if (myUid != null) {
      await _callingService.hangUp(callId, myUid);
    }
  }

  // ---------------------------------------------------------------------------
  // Media Controls
  // ---------------------------------------------------------------------------

  void toggleMute() {
    _isMuted = !_isMuted;
    _callingService.toggleMute(_isMuted);
    notifyListeners();
  }

  void toggleCamera() {
    _isCameraOn = !_isCameraOn;
    _callingService.toggleCamera(_isCameraOn);
    notifyListeners();
  }

  void switchCamera() {
    _callingService.switchCamera();
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _callingService.setSpeakerphone(_isSpeakerOn);
    notifyListeners();
  }

  bool get isScreenSharing => _callingService.isScreenSharing;

  Future<void> toggleScreenShare() async {
    try {
      if (_callingService.isScreenSharing) {
        await _callingService.stopScreenShare();
      } else {
        final success = await _callingService.startScreenShare();
        if (!success) {
          debugPrint('[ConnectCall] Screen share was not started (user cancelled or service error)');
        }
      }
    } catch (e) {
      debugPrint('[ConnectCall] ⚠️ toggleScreenShare error: $e');
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _callingService.disposeRenderers();
    super.dispose();
  }
}
