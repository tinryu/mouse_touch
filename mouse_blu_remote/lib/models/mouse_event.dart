import 'dart:convert';

/// Base class for all mouse events
abstract class MouseEvent {
  final String type;

  MouseEvent(this.type);

  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());
}

/// Mouse movement event
class MoveEvent extends MouseEvent {
  final double deltaX;
  final double deltaY;

  MoveEvent({required this.deltaX, required this.deltaY}) : super('move');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'deltaX': deltaX,
        'deltaY': deltaY,
      };
}

/// Left click event
class LeftClickEvent extends MouseEvent {
  LeftClickEvent() : super('leftClick');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Right click event
class RightClickEvent extends MouseEvent {
  RightClickEvent() : super('rightClick');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Double click event
class DoubleClickEvent extends MouseEvent {
  DoubleClickEvent() : super('doubleClick');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Scroll event
class ScrollEvent extends MouseEvent {
  final double scrollAmount;

  ScrollEvent({required this.scrollAmount}) : super('scroll');

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'scrollAmount': scrollAmount,
      };
}

/// Left button down event
class LeftDownEvent extends MouseEvent {
  LeftDownEvent() : super('leftDown');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Left button up event
class LeftUpEvent extends MouseEvent {
  LeftUpEvent() : super('leftUp');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Right button down event
class RightDownEvent extends MouseEvent {
  RightDownEvent() : super('rightDown');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}

/// Right button up event
class RightUpEvent extends MouseEvent {
  RightUpEvent() : super('rightUp');

  @override
  Map<String, dynamic> toJson() => {'type': type};
}
