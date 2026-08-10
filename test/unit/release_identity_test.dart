import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sermonary/app/app_config.dart';

void main() {
  test('macOS release identity matches the permanent application identity', () {
    const permanentBundleIdentifier = 'app.sermonary.sermonary';
    const permanentDatabaseFileName = 'sermonary.sqlite';

    expect(AppConfig.bundleIdentifier, permanentBundleIdentifier);
    expect(AppConfig.databaseFileName, permanentDatabaseFileName);

    final macosConfig = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    expect(
      macosConfig,
      contains('PRODUCT_BUNDLE_IDENTIFIER = $permanentBundleIdentifier'),
    );
    expect(macosConfig, contains('PRODUCT_NAME = Sermonary'));
  });
}
