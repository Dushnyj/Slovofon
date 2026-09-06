import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slovofon/app/theme/app_text_scaler.dart';

class _NonlinearScaler extends TextScaler {
  const _NonlinearScaler();
  @override
  double scale(double fontSize) =>
      fontSize < 20 ? fontSize * 2 : fontSize * 1.5;
  @override
  double get textScaleFactor => 2;
}

void main() {
  test('default app preference preserves platform text scale', () {
    const scaler = AppTextScaler(TextScaler.linear(2), 1);
    expect(scaler.scale(16), 32);
  });
  test('app preference composes with nonlinear accessibility scaling', () {
    const scaler = AppTextScaler(_NonlinearScaler(), 1.3);
    expect(scaler.scale(16), closeTo(41.6, 0.001));
    expect(scaler.scale(24), closeTo(46.8, 0.001));
  });
  test(
    'equal scale parameters do not signal unnecessary inherited updates',
    () {
      expect(
        const AppTextScaler(TextScaler.linear(2), 1.2),
        const AppTextScaler(TextScaler.linear(2), 1.2),
      );
    },
  );
}
