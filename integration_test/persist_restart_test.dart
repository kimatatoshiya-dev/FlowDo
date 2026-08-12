import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flowdo/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cold restart: reload persisted tasks', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 90));

    expect(find.textContaining('PersistDiag storageReady=true'), findsOneWidget);
    expect(find.textContaining('hadPersistedPayload=true'), findsOneWidget);
    expect(find.textContaining('taskCount=1'), findsOneWidget);
    expect(find.textContaining('PersistDiag passed=true'), findsOneWidget);
  });
}
