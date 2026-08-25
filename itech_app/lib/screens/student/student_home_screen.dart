import 'package:flutter/material.dart';

import '../../theme/design_tokens.dart';

class StudentHomeScreen extends StatelessWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning, Juan!'
        : hour < 18
        ? 'Good Afternoon, Juan!'
        : 'Good Evening, Juan!';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _QuickStatsRow(),
                    const SizedBox(height: 14),
                    _SearchBar(),
                    const SizedBox(height: 14),
                    _CategoryChips(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _EquipmentCard(
                    name: [
                      'Oscilloscope',
                      'Multimeter',
                      '3D Printer',
                      'Tool Kit',
                    ][i % 4],
                    available: i % 2 == 0,
                  ),
                  childCount: 8,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: const [
          _StatCard(label: 'Active: 2', tone: PupColors.techCyan),
          SizedBox(width: 12),
          _StatCard(label: 'Pending: 1', tone: PupColors.cyberAmber),
          SizedBox(width: 12),
          _StatCard(label: 'Overdue: 0', tone: PupColors.mintGreen),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
              color: tone.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.trending_up_rounded, color: tone),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _c = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Search equipment...',
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
        prefixIcon: const Icon(Icons.search_rounded, color: PupColors.techCyan),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: PupColors.cyberAmber.withValues(alpha: 0.8),
          ),
        ),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _c.clear()),
              ),
      ),
    );
  }
}

class _CategoryChips extends StatefulWidget {
  @override
  State<_CategoryChips> createState() => _CategoryChipsState();
}

class _CategoryChipsState extends State<_CategoryChips> {
  int selected = 0;
  final cats = const [
    'ALL',
    'Available Now',
    'Mechanical',
    'Electrical',
    'Tools',
    'Testers',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, i) => InkWell(
          onTap: () => setState(() => selected = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: selected == i ? PupColors.cyberAmber : Colors.transparent,
              border: Border.all(
                color: selected == i
                    ? PupColors.cyberAmber
                    : Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              cats[i],
              style: TextStyle(
                color: selected == i ? const Color(0xFF1B1B1B) : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemCount: cats.length,
      ),
    );
  }
}

class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.name, required this.available});

  final String name;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final ribbonColor = available ? PupColors.techCyan : PupColors.signalRed;
    return GestureDetector(
      onTap: () {},
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: ribbonColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        available
                            ? Icons.inventory_2_rounded
                            : Icons.block_rounded,
                        color: ribbonColor,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  available ? 'Available' : 'Borrowed',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 6,
            child: Transform.rotate(
              angle: -0.75,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: ribbonColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  available ? 'Available' : 'Borrowed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
