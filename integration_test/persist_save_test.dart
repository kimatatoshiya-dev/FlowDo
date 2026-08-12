import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flowdo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch: storageReady and save verification', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 90));

    expect(find.textContaining('PersistDiag storageReady=true'), findsOneWidget);
    expect(find.textContaining('setStringResult=true'), findsOneWidget);
    expect(find.textContaining('verified=true'), findsOneWidget);
  });
}
