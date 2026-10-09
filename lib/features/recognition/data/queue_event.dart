class QueueEvent {
  final String event;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  const QueueEvent({
    required this.event,
    required this.timestamp,
    required this.data,
  });

  factory QueueEvent.fromMap(Map<String, dynamic> map) {
    final eventName = (map['event'] ?? map['type'] ?? 'unknown').toString();
    final dataMap = map['data'] is Map<String, dynamic>
        ? map['data'] as Map<String, dynamic>
        : (map['data'] is Map ? Map<String, dynamic>.from(map['data'] as Map) : <String, dynamic>{});
    return QueueEvent(
      event: eventName,
      timestamp: DateTime.now(),
      data: dataMap,
    );
  }
}

