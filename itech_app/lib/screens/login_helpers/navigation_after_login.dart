import 'package:flutter/material.dart';

import '../../screens/shell/admin_shell.dart';
import '../../screens/shell/student_shell.dart';

void navigateAfterStudentLogin(BuildContext context) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const StudentShell()),
  );
}

void navigateAfterAdminLogin(BuildContext context) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const AdminShell()),
  );
}
