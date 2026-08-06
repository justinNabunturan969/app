import 'package:flutter_test/flutter_test.dart';
import 'package:itech_app/app/pup_iitech_app.dart';
import 'package:itech_app/auth/session/auth_session_storage.dart';
import 'package:itech_app/auth/validators/auth_validators.dart';
import 'package:itech_app/screens/onboarding/configuration_required_screen.dart';
import 'package:itech_app/screens/role_selection/role_selection_screen.dart';

void main() {
  testWidgets('shows role selection screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PupItechApp(home: RoleSelectionScreen()));

    expect(find.text('PUP-ITech'), findsOneWidget);
    expect(find.text('Choose your access'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Faculty/Admin'), findsOneWidget);
  });

  testWidgets('shows setup instructions when backend is unconfigured', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ConfigurationRequiredApp());

    expect(find.text('Backend setup required'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });

  test('accepts PUP email student logins without rewriting the email', () {
    expect(AuthValidators.validateStudentLogin('student1@pup.edu.ph'), isNull);
    expect(
      AuthSessionStorage.studentAuthEmailFor('student1@pup.edu.ph'),
      'student1@pup.edu.ph',
    );
  });

  test('accepts Supabase default six-character passwords', () {
    expect(AuthValidators.validatePassword('admin1'), isNull);
  });
}
