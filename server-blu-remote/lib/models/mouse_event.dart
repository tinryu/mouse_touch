/// Represents different types of mouse events
enum MouseEventType {
  move,
  leftClick,
  rightClick,
  doubleClick,
  scroll,
  leftDown,
  leftUp,
  rightDown,
  rightUp,
}

/// Model for mouse events received from the Flutter app
class MouseEvent {
  final MouseEventType type;
  final double? deltaX;
  final double? deltaY;
  final double? scrollAmount;

  MouseEvent({
    required this.type,
    this.deltaX,
    this.deltaY,
    this.scrollAmount,
  });

  /// Create MouseEvent from JSON
  factory MouseEvent.fromJson(Map<String, dynamic> json) {
    return MouseEvent(
      type: MouseEventType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MouseEventType.move,
      ),
      deltaX: json['deltaX']?.toDouble(),
      deltaY: json['deltaY']?.toDouble(),
      scrollAmount: json['scrollAmount']?.toDouble(),
    );
  }

  /// Convert MouseEvent to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'deltaX': deltaX,
      'deltaY': deltaY,
      'scrollAmount': scrollAmount,
    };
  }

  @override
  String toString() {
    return 'MouseEvent(type: $type, deltaX: $deltaX, deltaY: $deltaY, scrollAmount: $scrollAmount)';
  }
}
