import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/layout/app_breakpoints.dart';

void main() {
  group('AppBreakpoints', () {
    test('classifies compact widths', () {
      expect(AppBreakpoints.fromWidth(0), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(599), AppLayoutSize.compact);
    });

    test('classifies medium widths', () {
      expect(AppBreakpoints.fromWidth(600), AppLayoutSize.medium);
      expect(AppBreakpoints.fromWidth(1023), AppLayoutSize.medium);
    });

    test('classifies expanded widths', () {
      expect(AppBreakpoints.fromWidth(1024), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1439), AppLayoutSize.expanded);
    });

    test('classifies wide widths', () {
      expect(AppBreakpoints.fromWidth(1440), AppLayoutSize.wide);
      expect(AppBreakpoints.fromWidth(1920), AppLayoutSize.wide);
    });
  });

  group('AppResponsiveSpacing', () {
    test('uses 16 px on compact', () {
      expect(AppResponsiveSpacing.horizontalForWidth(390), 16);
    });

    test('uses 24 px on medium', () {
      expect(AppResponsiveSpacing.horizontalForWidth(768), 24);
    });

    test('uses 32 px on expanded and wide', () {
      expect(AppResponsiveSpacing.horizontalForWidth(1200), 32);
      expect(AppResponsiveSpacing.horizontalForWidth(1600), 32);
    });
  });

  test('content width presets remain content-specific', () {
    expect(AppContentWidths.auth, 520);
    expect(AppContentWidths.form, 640);
    expect(AppContentWidths.list, 900);
    expect(AppContentWidths.dashboard, 1200);
  });
}
