import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../app/theme_controller.dart';
import '../app/language_controller.dart';
import '../theme/design_tokens.dart';

class RouterApp extends StatelessWidget {
  const RouterApp({
    super.key,
    required this.router,
    required this.themeController,
    required this.languageController,
  });

  final GoRouter router;
  final ThemeController themeController;
  final LanguageController languageController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: themeController),
        ChangeNotifierProvider<LanguageController>.value(
          value: languageController,
        ),
      ],
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
