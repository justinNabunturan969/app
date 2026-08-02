import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class PupItechApp extends StatelessWidget {
  const PupItechApp({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUP-ITech Borrowing',
      theme: PupTheme.light(),
      darkTheme: PupTheme.dark(),
      themeMode: ThemeMode.system,
      home: home,
    );
  }
}
