import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itech_app/app/theme_controller.dart';
import 'package:itech_app/data/repositories/repository_bundle.dart';
import 'package:itech_app/screens/shell/admin_shell.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('admin scan tab builds without crashing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<RepositoryBundle>.value(value: RepositoryBundle.mock()),
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(),
          ),
        ],
        child: const MaterialApp(home: AdminShell()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Scan'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    final exception = tester.takeException();
    // A build crash on this tab surfaces here (web users see the
    // error panel / blank screen instead of the scanner UI).
    expect(
      exception,
      isNull,
      reason: 'Scan tab threw during build: $exception',
    );
    expect(find.text('Scan Student ID'), findsWidgets);
  });
}
