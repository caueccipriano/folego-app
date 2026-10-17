{{flutter_js}}
{{flutter_build_config}}

// Fôlego owns its service worker because Web Push on installed iOS PWAs needs
// a stable worker with push/notificationclick handlers. Flutter's generated
// service worker is intentionally not registered here (it is deprecated and
// would compete for the same scope).
_flutter.loader.load();
