enum SessionStatus { idle, active }

SessionStatus _sessionStatusFromString(String value) => switch (value) {
  'active' => SessionStatus.active,
  _ => SessionStatus.idle,
};

/// セッション状態(native → Flutter)。
class SessionState {
  const SessionState({
    required this.status,
    required this.targetDisplayId,
    required this.overlayActive,
  });

  factory SessionState.fromMap(Map<Object?, Object?> map) => SessionState(
    status: _sessionStatusFromString(map['status'] as String? ?? 'idle'),
    targetDisplayId: map['targetDisplayId'] as int?,
    overlayActive: map['overlayActive'] as bool? ?? false,
  );

  static const idleState = SessionState(
    status: SessionStatus.idle,
    targetDisplayId: null,
    overlayActive: false,
  );

  final SessionStatus status;
  final int? targetDisplayId;
  final bool overlayActive;
}
