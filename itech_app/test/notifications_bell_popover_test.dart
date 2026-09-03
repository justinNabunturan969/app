import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:itech_app/data/repositories/repository_bundle.dart';
import 'package:itech_app/student/student_dashboard_controller.dart';
import 'package:itech_app/widgets/notifications_bell_button.dart';

void main() {
  testWidgets('bell opens the notifications popover and toggles closed', (
    tester,
  ) async {
    final controller = StudentDashboardController(
      bundle: RepositoryBundle.mock(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<StudentDashboardController>.value(
          value: controller,
          child: const Scaffold(
            body: Center(child: NotificationsBellButton()),
          ),
        ),
      ),
    );

    // Opening must not throw. The popover lives in an OverlayEntry, which
    // is parented above the ChangeNotifierProvider, so this is the
    // regression guard for the ProviderNotFoundException crash.
    await tester.tap(find.byType(NotificationsBellButton));
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsOneWidget);

    // Tapping the bell again (through the dismiss barrier) closes it.
    await tester.tap(
      find.byType(NotificationsBellButton),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Notifications'), findsNothing);

    controller.dispose();
  });
}
