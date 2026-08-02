import 'package:flutter/material.dart';

/// Shown instead of crashing when the app is launched without backend config.
class ConfigurationRequiredApp extends StatelessWidget {
  const ConfigurationRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PUP-ITech Borrowing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B1E2B)),
        useMaterial3: true,
      ),
      home: const _ConfigurationRequiredScreen(),
    );
  }
}

class _ConfigurationRequiredScreen extends StatelessWidget {
  const _ConfigurationRequiredScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.settings_suggest_outlined, size: 48),
                  SizedBox(height: 20),
                  Text(
                    'Backend setup required',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This copy of PUP-ITech has not been given its Supabase '
                    'project credentials yet. Add the values below to the run '
                    'configuration, then restart the app.',
                  ),
                  SizedBox(height: 20),
                  SelectableText(
                    'flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co '
                    '--dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
                    style: TextStyle(fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Get both values from Supabase: Project Settings → API.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
