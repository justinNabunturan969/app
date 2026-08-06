import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as st;
import 'dart:math' as math;

import '../../../theme/design_tokens.dart';
import '../../../app/language_controller.dart';

class VoiceSearchOverlay extends StatefulWidget {
  const VoiceSearchOverlay({
    super.key,
    required this.onTranscribed,
    required this.onPartialTranscribed,
    required this.onCancel,
    required this.language,
  });

  final ValueChanged<String> onTranscribed;
  final ValueChanged<String> onPartialTranscribed;
  final VoidCallback onCancel;
  final AppLanguage language;

  @override
  State<VoiceSearchOverlay> createState() => _VoiceSearchOverlayState();
}

class _VoiceSearchOverlayState extends State<VoiceSearchOverlay> {
  late final st.SpeechToText _speech;
  bool _available = false;
  bool _listening = false;
  String _lastWords = '';
  String? _error;
  String? _resolvedLocaleId;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _speech = st.SpeechToText();
    _init();
  }

  Future<void> _init() async {
    final copy = AppCopy(widget.language);
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _listening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _error = _messageForError(error.errorMsg);
        });
      },
    );

    if (!mounted) return;
    setState(() {
      _available = available;
      _error = available ? null : copy.microphoneOrSpeechUnavailable();
    });

    if (available) {
      // On web, Android, and iOS the recognizer itself is the authority on
      // supported languages. Asking the plugin for exact locale names can
      // reject a valid device locale (for example `tl_PH` vs `fil-PH`) before
      // recognition starts. Let the platform attempt the selected locale and
      // surface its error if it truly is unavailable.
      _resolvedLocaleId = widget.language.speechLocaleId;
      _listen();
    }
  }

  Future<void> _listen() async {
    if (_listening || !_available || _resolvedLocaleId == null) return;
    setState(() => _listening = true);

    try {
      await _speech.listen(
        listenOptions: st.SpeechListenOptions(
          localeId: _resolvedLocaleId,
          listenMode: st.ListenMode.dictation,
          // 700ms made normal human pauses look like a speech timeout on
          // Android and the web. Give the user time to start speaking and to
          // finish a short equipment name.
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          partialResults: true,
          cancelOnError: false,
        ),
        onResult: (result) {
          final words = result.recognizedWords.trim();
          setState(() {
            _lastWords = words;
          });
          if (words.isNotEmpty) widget.onPartialTranscribed(words);

          if (result.finalResult) {
            _submitAndClose();
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _error =
            'Microphone access could not start. Allow Microphone in your browser settings, then try again.';
      });
    }
  }

  String _messageForError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('not-allowed') ||
        normalized.contains('permission') ||
        normalized.contains('denied')) {
      return 'Microphone access is blocked. Click the lock icon beside the website address, allow Microphone, then try again.';
    }
    if (normalized.contains('no-speech')) {
      return 'No speech was detected. Check your microphone and try again.';
    }
    if (normalized.contains('timeout')) {
      return 'Voice search timed out before it heard words. Tap Try again, then speak normally.';
    }
    return message;
  }

  Future<void> _retryListening() async {
    await _speech.cancel();
    if (!mounted) return;
    setState(() {
      _listening = false;
      _lastWords = '';
      _error = null;
      _closing = false;
    });
    await _listen();
  }

  Future<void> _stopAndClose() async {
    await _speech.stop();
    if (!mounted) return;
    widget.onCancel();
  }

  Future<void> _submitAndClose() async {
    if (_closing) return;
    _closing = true;
    final words = _lastWords.trim();
    await _speech.stop();
    if (!mounted) return;
    if (words.isNotEmpty) widget.onTranscribed(words);
    widget.onCancel();
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = AppCopy(widget.language);
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
                              ? copy.listening
                              : (_available
                                    ? copy.readyFor(widget.language.label)
                                    : copy.microphoneUnavailable),
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
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: PupColors.signalRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    if (_available) ...[
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _retryListening,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Try again'),
                      ),
                    ],
                  ],
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
                          child: Text(copy.cancel),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _lastWords.trim().isEmpty
                              ? null
                              : _submitAndClose,
                          style: FilledButton.styleFrom(
                            backgroundColor: PupColors.cyberAmber,
                            foregroundColor: const Color(0xFF1B1B1B),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(copy.search),
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
