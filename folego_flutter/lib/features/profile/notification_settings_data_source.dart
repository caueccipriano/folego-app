import '../../core/notifications/notification_models.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';

abstract interface class NotificationSettingsDataSource {
  Future<NotificationPreferences> load(String spaceId);

  Future<NotificationPreferences> save(NotificationPreferences preferences);
}

class RepositoryNotificationSettingsDataSource
    implements NotificationSettingsDataSource {
  RepositoryNotificationSettingsDataSource(this.repository);

  final FolegoRepository repository;

  @override
  Future<NotificationPreferences> load(String spaceId) =>
      repository.getNotificationPreferences(spaceId);

  @override
  Future<NotificationPreferences> save(NotificationPreferences preferences) =>
      repository.saveNotificationPreferences(preferences);
}
