import 'notification_service.dart';

class NotificationRuntimeController {
  NotificationRuntimeController(this.service);

  final NotificationService service;
  String? _spaceId;
  bool _disposed = false;

  String? get activeSpaceId => _spaceId;

  Future<void> activateSpace(String spaceId) async {
    if (_disposed) return;
    final previous = _spaceId;
    if (previous == spaceId) {
      await service.syncUpcoming(spaceId);
      return;
    }
    if (previous != null) {
      await service.clearForSpaceChange(previous);
    }
    if (_disposed) return;
    _spaceId = spaceId;
    await service.syncUpcoming(spaceId);
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    final spaceId = _spaceId;
    if (spaceId != null) await service.syncUpcoming(spaceId);
  }

  Future<void> onSignedOut() async {
    if (_disposed) return;
    _spaceId = null;
    await service.clearForLogout();
  }

  void dispose() {
    _disposed = true;
    _spaceId = null;
  }
}

abstract final class NotificationServiceRegistry {
  static NotificationService? _service;

  static NotificationService? get current => _service;

  static void attach(NotificationService service) {
    _service = service;
  }

  static void detach(NotificationService service) {
    if (identical(_service, service)) _service = null;
  }
}
