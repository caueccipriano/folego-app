import 'package:flutter/widgets.dart';

class ProjectionNavigationScope extends InheritedWidget {
  const ProjectionNavigationScope({
    super.key,
    required this.onOpen,
    required super.child,
  });

  final VoidCallback onOpen;

  static ProjectionNavigationScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProjectionNavigationScope>();
  }

  void open() => onOpen();

  @override
  bool updateShouldNotify(ProjectionNavigationScope oldWidget) {
    return oldWidget.onOpen != onOpen;
  }
}
