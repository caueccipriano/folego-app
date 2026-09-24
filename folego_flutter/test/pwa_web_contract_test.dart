import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PWA web contract', () {
    test('index keeps install metadata, safe-area viewport and script order', () {
      final index = File('web/index.html').readAsStringSync();

      expect(index, contains('viewport-fit=cover'));
      expect(index, contains('apple-mobile-web-app-capable'));
      expect(index, contains('apple-mobile-web-app-status-bar-style'));
      expect(
        index,
        contains('apple-mobile-web-app-status-bar-style" content="black"'),
      );
      expect(index, isNot(contains('black-translucent')));
      expect(index, contains('rel="manifest" href="manifest.json"'));
      expect(index, contains('(prefers-color-scheme: light)'));
      expect(index, contains('(prefers-color-scheme: dark)'));
      expect(index, isNot(contains('position: fixed !important')));
      expect(index, isNot(contains('height: 100dvh !important')));
      expect(index, contains('Do not size or position flutter-view here.'));
      expect(index, contains('__FOLEGO_BUILD_VERSION__'));
      expect(index, contains('folego-pwa-repair-version'));
      expect(index, contains('folego-shell-'));
      expect(index, isNot(contains(r'</script>\n')));

      final zoomFix = index.indexOf('folego_ios_zoom_fix.js');
      final pushBridge = index.indexOf('folego_push_bridge.js');
      final flutterBootstrap = index.indexOf('flutter_bootstrap.js');

      expect(zoomFix, greaterThanOrEqualTo(0));
      expect(pushBridge, greaterThan(zoomFix));
      expect(flutterBootstrap, greaterThan(pushBridge));
    });

    test('approved piggy bank stays canonical across app branding', () {
      final logo = File('web/icons/folego-logo.svg').readAsStringSync();
      final index = File('web/index.html').readAsStringSync();
      final auth = File(
        'lib/features/auth/auth_widgets.dart',
      ).readAsStringSync();
      final workflow = File(
        '../.github/workflows/deploy-web.yml',
      ).readAsStringSync();

      expect(logo, contains('Fôlego — porquinho'));
      expect(logo, contains('data:image/png;base64,'));
      expect(index, contains('icons/Icon-512.png?v=__FOLEGO_BUILD_VERSION__'));
      expect(index, contains('icons/Icon-192.png?v=__FOLEGO_BUILD_VERSION__'));
      expect(auth, contains("'web/icons/Icon-512.png'"));
      expect(workflow, contains('web/icons/folego-logo.svg'));
    });

    test('manifest is installable inside the GitHub Pages app scope', () {
      final manifest =
          jsonDecode(File('web/manifest.json').readAsStringSync())
              as Map<String, dynamic>;

      expect(manifest['id'], './');
      expect(manifest['start_url'], './');
      expect(manifest['scope'], './');
      expect(manifest['display'], 'standalone');
      expect(manifest['lang'], 'pt-BR');

      final icons = (manifest['icons'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        icons.any(
          (icon) =>
              icon['sizes'] == '192x192' &&
              icon['purpose'] == 'any',
        ),
        isTrue,
      );
      expect(
        icons.any(
          (icon) =>
              icon['sizes'] == '512x512' &&
              icon['purpose'] == 'maskable',
        ),
        isTrue,
      );
    });

    test('custom worker owns push but never caches the Flutter bundle', () {
      final worker = File('web/folego_push_sw.js').readAsStringSync();
      final bridge = File('web/folego_push_bridge.js').readAsStringSync();
      final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

      expect(worker, contains("addEventListener('push'"));
      expect(worker, contains("addEventListener('notificationclick'"));
      expect(worker, contains('self.clients.openWindow'));
      expect(worker, contains('__FOLEGO_CACHE_VERSION__'));
      expect(worker, isNot(contains("addEventListener('fetch'")));
      expect(worker, isNot(contains("addEventListener('fetch'")));
      expect(worker, isNot(contains("cache.add('main.dart.js')")));
      expect(worker, isNot(contains('caches.match(request)')));
      expect(bridge, contains('updateViaCache'));
      expect(bridge, contains('DOMContentLoaded'));
      expect(bridge, contains('registration.update()'));
      expect(bootstrap, contains('_flutter.loader.load();'));
      expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    });

    test('Pages workflow configures and deploys the PWA artifact', () {
      final workflow =
          File('../.github/workflows/deploy-web.yml').readAsStringSync();

      expect(workflow, contains('actions/configure-pages@v5'));
      expect(workflow, contains('actions/upload-pages-artifact@v4'));
      expect(workflow, contains('actions/deploy-pages@v4'));
      expect(workflow, contains('name: github-pages-preview'));
      expect(workflow, contains('--base-href "/folego-app/"'));
      expect(workflow, contains('Version PWA cache'));
      expect(workflow, contains('Verify PWA artifact'));
    });
  });
}
