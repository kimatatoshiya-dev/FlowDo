import 'package:flutter_test/flutter_test.dart';

import 'package:flowdo/firebase_options.dart';

void main() {
  test('firebase_options は flowdo-fdb67 の設定を参照する', () {
    expect(DefaultFirebaseOptions.android.projectId, 'flowdo-fdb67');
    expect(DefaultFirebaseOptions.ios.projectId, 'flowdo-fdb67');
    expect(DefaultFirebaseOptions.android.messagingSenderId, '87292835485');
    expect(DefaultFirebaseOptions.ios.messagingSenderId, '87292835485');
    expect(DefaultFirebaseOptions.ios.iosBundleId, 'com.kimata.flowdo');
    expect(
      DefaultFirebaseOptions.android.appId,
      '1:87292835485:android:80a5bd5cbc0a570783c674',
    );
    expect(
      DefaultFirebaseOptions.ios.appId,
      '1:87292835485:ios:eb2cbb311c5072d083c674',
    );
    expect(DefaultFirebaseOptions.macos.projectId, 'flowdo-fdb67');
    expect(
      DefaultFirebaseOptions.macos.appId,
      '1:87292835485:ios:d21e934deb9f940f83c674',
    );
  });
}
