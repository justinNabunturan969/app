import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void navigateAfterStudentLogin(BuildContext context) {
  context.go('/student/shell');
}

void navigateAfterAdminLogin(BuildContext context) {
  context.go('/admin/shell');
}
