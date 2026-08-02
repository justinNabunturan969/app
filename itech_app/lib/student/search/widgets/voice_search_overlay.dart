import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as st;
import 'dart:math' as math;

import '../../../theme/design_tokens.dart';

class VoiceSearchOverlay extends StatefulWidget {
  const VoiceSearchOverlay({
    super.key,
    required this.onTranscribed,
    required this.onCancel,
  });

  final ValueChanged<String> onTranscribed;
  final VoidCallback onCancel;

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay> {
  late final st.SpeechToText _speech;
  bool _available = false;
  bool _listening = false;
  String _lastWords = '';

  @override
  void initState() {
    super.initState();
    _speech = st.SpeechToText();
    _init();
  }

  Future<void> _init() async {
    final available = await _speech.initialize(
      onStatus: (s) {},
      onError: (e) {},
    );

    if (!mounted) return;
    setState(() {
      _available = available;
    });

    if (available) {
      _listen();
    }
  }

  Future<void> _listen() async {
    if (_listening) return;
    setState(() => _listening = true);

    await _speech.listen(
      listenOptions: st.SpeechListenOptions(
        listenMode: st.ListenMode.dictation,
        pauseFor: const Duration(milliseconds: 700),
      ),
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });

        if (result.finalResult) {
          widget.onTranscribed(_lastWords.trim());
          _stopAndClose();
        }
      },
    );
  }

  Future<void> _stopAndClose() async {
    await _speech.stop();
    if (!mounted) return;
    widget.onCancel();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.5)
            : Colors.black.withValues(alpha: 0.12),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: isDark ? PupColors.darkCard : Colors.white,
            elevation: 10,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: PupColors.cyberAmber.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mic_rounded,
                          color: PupColors.cyberAmber,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _listening
                              ? 'Listening…'
                              : (_available ? 'Ready' : 'Mic unavailable'),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDark ? Colors.white : PupColors.slateGray,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Animated waveform
                  const _Waveform(),
                  const SizedBox(height: 14),

                  Text(
                    _lastWords.isEmpty ? ' ' : '"$_lastWords"',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : PupColors.slateGray,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _stopAndClose,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: PupColors.signalRed,
                            side: BorderSide(
                              color: PupColors.signalRed.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _stopAndClose,
                          style: FilledButton.styleFrom(
                            backgroundColor: PupColors.cyberAmber,
                            foregroundColor: const Color(0xFF1B1B1B),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Search'),
                        ),
                      ),
                    ],
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

class _Waveform extends StatefulWidget {
  const _Waveform();

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(10, (i) {
              final t = (i / 9);
              final phase = (t * 3.1415);
              final h =
                  6 + (10 + (math.sin(phase + _c.value * 6.28) * 8)).abs();

              return Container(
                width: 6,
                height: h,
                decoration: BoxDecoration(
                  color: PupColors.cyberAmber,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
