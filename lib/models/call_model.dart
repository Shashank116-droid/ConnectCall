class CallModel {
  final String id;
  final String callerId;
  final String callerName;
  final List<String> calleeIds;
  final List<String> calleeNames;
  final List<String> joinedIds;
  final bool isVideo;
  final String status; // 'ringing', 'connected', 'ended', 'rejected', 'missed', 'busy'
  final DateTime timestamp;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final String channelId;

  CallModel({
    required this.id,
    required this.callerId,
    required this.callerName,
    required this.calleeIds,
    required this.calleeNames,
    required this.joinedIds,
    required this.isVideo,
    required this.status,
    required this.timestamp,
    required this.channelId,
    this.connectedAt,
    this.endedAt,
  });

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] ?? '',
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? '',
      calleeIds: List<String>.from(json['calleeIds'] ?? []),
      calleeNames: List<String>.from(json['calleeNames'] ?? []),
      joinedIds: List<String>.from(json['joinedIds'] ?? []),
      isVideo: json['isVideo'] ?? false,
      status: json['status'] ?? 'ringing',
      channelId: json['channelId'] ?? '',
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
      connectedAt: json['connectedAt'] != null ? DateTime.parse(json['connectedAt']) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'callerId': callerId,
      'callerName': callerName,
      'calleeIds': calleeIds,
      'calleeNames': calleeNames,
      'joinedIds': joinedIds,
      'isVideo': isVideo,
      'status': status,
      'channelId': channelId,
      'timestamp': timestamp.toIso8601String(),
      'connectedAt': connectedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
    };
  }
}
