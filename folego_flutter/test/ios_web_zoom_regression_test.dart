import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS web zoom guard is loaded before Flutter bootstrap', () {
    final index = File('web/index.html').readAsStringSync();

    final zoomFix = index.indexOf('folego_ios_zoom_fix.js');
    final flutterBootstrap = index.indexOf('flutter_bootstrap.js');

    expect(zoomFix, greaterThanOrEqualTo(0));
    expect(flutterBootstrap, greaterThan(zoomFix));
  });

  test('iOS zoom guard keeps editable DOM font at 16px', () {
    final script = File('web/folego_ios_zoom_fix.js').readAsStringSync();

    expect(script, contains('font-size: 16px !important'));
    expect(script, contains("style.setProperty('font-size', '16px', 'important')"));
    expect(script, contains('shadowRoot'));
    expect(script, contains('MutationObserver'));
  });
}
