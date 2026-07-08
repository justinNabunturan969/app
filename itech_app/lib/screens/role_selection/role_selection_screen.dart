import 'package:flutter/material.dart';

import '../../auth/login/admin_login_screen.dart';
import '../../auth/login/student_login_screen.dart';
import '../../theme/design_tokens.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PupColors.pupMaroon, PupColors.deepMahogany],
          ),
        ),
        child: SafeArea(
          top: true,
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(top: topPad + 16, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Text(
                  'PUP-ITech',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Innovation at Your Fingertips.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFBFD8FF),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 26),
                const Text(
                  'Choose your access',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _RoleCard(role: 'Student', icon: Icons.school),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _RoleCard(
                        role: 'Faculty/Admin',
                        icon: Icons.admin_panel_settings,
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),
                Center(
                  child: Text(
                    'v1.0 (prototype)',
                    style: TextStyle(
                      fontSize: 12,
                      color: PupColors.coolSteel.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  const _RoleCard({required this.role, required this.icon});

  final String role;
  final IconData icon;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _selected = false;

  void _goStudent() {
    // ignore: use_build_context_synchronously
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StudentLoginScreen()));
  }

  void _goAdmin() {
    // ignore: use_build_context_synchronously
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AdminLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _selected ? PupColors.cyberAmber : Colors.white24;
    final shadowColor = _selected
        ? PupColors.cyberAmber.withValues(alpha: 0.35)
        : Colors.black26;

    return GestureDetector(
      onTap: () {
        setState(() => _selected = true);

        if (widget.role == 'Student') {
          _goStudent();
        } else {
          _goAdmin();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 32, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              widget.role,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.role == 'Student'
                  ? 'Borrow & Request Tools'
                  : 'Manage Inventory & Approvals',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
