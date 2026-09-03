import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:itech_app/data/repositories/repository_bundle.dart';
import 'package:itech_app/student/models.dart';
import 'package:itech_app/student/search/widgets/borrow_confirm_sheet.dart';
import 'package:itech_app/student/student_dashboard_controller.dart';

void main() {
  testWidgets('borrow sheet lets the student pick an iTech room', (
    tester,
  ) async {
    final controller = StudentDashboardController(
      bundle: RepositoryBundle.mock(),
    );

    const equipment = Equipment(
      id: 'eq-1',
      code: 'E-5222',
      name: 'DC Power Supply 0-30V / 0-5A',
      category: 'Electrical',
      location: 'Room 210 - Bench Supplies',
      available: 10,
      total: 10,
      description: 'Bench supply',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<StudentDashboardController>.value(
          value: controller,
          child: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      BorrowConfirmSheet.show(context, equipment: equipment),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Defaults to "No room".
    expect(find.text('No room'), findsOneWidget);

    // Opening the dropdown offers exactly the iTech room ranges. The menu
    // is a lazy list, so scroll it to probe the ends of each range.
    await tester.tap(find.text('No room'));
    await tester.pumpAndSettle();
    final menuScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    expect(find.text('Room 200'), findsOneWidget);
    expect(find.text('Room 215'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Room 314'),
      100,
      scrollable: menuScrollable,
    );
    expect(find.text('Room 314'), findsOneWidget);
    expect(find.text('Room 315'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Room 210'),
      -100,
      scrollable: menuScrollable,
    );
    await tester.tap(find.text('Room 210'));
    await tester.pumpAndSettle();
    expect(find.text('Room 210'), findsOneWidget);

    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();

    expect(controller.pendingBorrowings, hasLength(1));
    expect(controller.pendingBorrowings.first.room, 'Room 210');

    controller.dispose();
  });
}
