import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme_controller.dart';
import '../theme/design_tokens.dart';

class RouterApp extends StatelessWidget {
  const RouterApp({
    super.key,
    required this.router,
    required this.themeController,
  });

  final GoRouter router;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThemeController>.value(
      value: themeController,
      child: Consumer<ThemeController>(
        builder: (context, controller, _) {
          return MaterialApp.router(
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            title: 'PUP-ITech Borrowing',
            theme: PupTheme.light(),
            darkTheme: PupTheme.dark(),
            themeMode: controller.mode,
          );
        },
      ),
    );
  }
}
