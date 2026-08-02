import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';

class SearchBarHero extends StatefulWidget {
  const SearchBarHero({
    super.key,
    required this.controller,
    required this.onClear,
    required this.onVoice,
  });

  final TextEditingController controller;
  final VoidCallback onClear;
  final VoidCallback onVoice;

  @override
  State<SearchBarHero> createState() => _SearchBarHeroState();
}

class _SearchBarHeroState extends State<SearchBarHero> {
  final _focus = FocusNode();
  bool _hadText = false;
  int _dot = 0;

  final _placeholders = const [
    'Search for equipment...',
    'Find a multimeter...',
    'Need a wrench?',
    'Search by ID...',
    'Looking for tools?',
  ];

  @override
  void initState() {
    super.initState();
    // Placeholder rotation via implicit animation not needed; keep simple with timer.
    // Use post-frame to start focus behavior.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // no auto focus to avoid stealing focus on tab switch.
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark
        ? PupGlass.darkFill(PupColors.techCyan)
        : PupColors.lightCard;
    final textColor = isDark
        ? theme.colorScheme.onSurface
        : PupColors.slateGray;
    final hintColor = isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.6)
        : PupColors.ashGray.withValues(alpha: 0.7);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? PupGlass.darkShadow(PupColors.cyberAmber, blur: 16, offsetY: 6)
            : [
                BoxShadow(
                  color: PupColors.cyberAmber.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: TextField(
        focusNode: _focus,
        controller: widget.controller,
        onChanged: (_) {
          if (widget.controller.text.isNotEmpty && !_hadText) {
            setState(() {
              _hadText = true;
              _dot = 1;
            });
          }
          if (widget.controller.text.isEmpty) {
            setState(() {
              _hadText = false;
              _dot = 0;
            });
          }
        },
        onSubmitted: (_) {
          FocusScope.of(context).unfocus();
        },
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: _placeholders[_dot % _placeholders.length],
          hintStyle: TextStyle(color: hintColor, fontSize: 16),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: isDark ? Colors.grey : PupColors.ashGray,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Voice search',
                icon: const Icon(
                  Icons.mic_rounded,
                  color: PupColors.cyberAmber,
                ),
                onPressed: widget.onVoice,
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(scale: anim, child: child),
                ),
                child: hasText
                    ? IconButton(
                        key: const ValueKey('clear'),
                        icon: const Icon(
                          Icons.clear_rounded,
                          color: PupColors.signalRed,
                        ),
                        onPressed: widget.onClear,
                      )
                    : const SizedBox.shrink(key: ValueKey('no_clear')),
              ),
            ],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
