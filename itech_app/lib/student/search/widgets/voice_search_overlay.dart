import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as st;
import 'dart:math' as math;

import '../../../theme/design_tokens.dart';
import '../../../app/language_controller.dart';
import 'voice_search_permission.dart';

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

  /// Tracks the microphone-permission pre-flight separately from
  /// `_available`, which is the recognizer's "I can listen" flag. On
  /// web we want the user to tap "Allow microphone" first so the
  /// browser shows its real prompt (the Web Speech API prompt is easy
  /// to miss on a phone), and only then hand off to the recognizer.
  MicrophonePermissionStatus? _permission;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _speech = st.SpeechToText();
    _bootstrap();
  }

  /// Runs the full startup sequence:
  ///   1. Ask the OS / browser for microphone permission via the
  ///      cross-platform helper. The web path goes through
  ///      `getUserMedia` (the JS bridge in `web/index.html`) because
  ///      its permission prompt is much more visible on mobile than
  ///      the Web Speech API's own prompt.
  ///   2. If permission was granted, hand off to the recognizer to
  ///      confirm the speech engine is actually available and start
  ///      listening.
  ///   3. Otherwise, leave the overlay in a "needs your tap" state
  ///      with a clear next step ("Allow microphone" button).
  Future<void> _bootstrap() async {
    final status = await MicrophonePermission.request();
    if (!mounted) return;
    setState(() => _permission = status);
    if (status != MicrophonePermissionStatus.granted) {
      setState(() => _error = _messageForPermission(status));
      return;
    }
    await _initRecognizer();
  }

  Future<void> _initRecognizer() async {
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

  /// Triggered by the explicit "Allow microphone" button. The first
  /// call from `initState` already passed through the helper; this
  /// re-asks so the user gets a second chance to grant (or correct a
  /// previous denial) without having to dig into browser settings.
  Future<void> _askForPermission() async {
    if (_requestingPermission) return;
    setState(() {
      _requestingPermission = true;
      _error = null;
    });
    final status = await MicrophonePermission.request();
    if (!mounted) return;
    setState(() {
      _permission = status;
      _requestingPermission = false;
      if (status != MicrophonePermissionStatus.granted) {
        _error = _messageForPermission(status);
      }
    });
    if (status == MicrophonePermissionStatus.granted) {
      await _initRecognizer();
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

  /// Maps the cross-platform permission enum to a single, mobile-
  /// friendly instruction. Each message tells the user the *next*
  /// step instead of leaving them to figure it out.
  String _messageForPermission(MicrophonePermissionStatus status) {
    switch (status) {
      case MicrophonePermissionStatus.granted:
        return '';
      case MicrophonePermissionStatus.denied:
        // On mobile web the address-bar lock icon is the only way to
        // undo a denial — calling `getUserMedia` again won't re-prompt
        // until the user clears the block.
        return 'Microphone access is blocked. Tap the lock icon beside the website address, allow Microphone, then tap Allow microphone again.';
      case MicrophonePermissionStatus.insecure:
        return 'This page is not served over HTTPS, so the browser blocks microphone access. Reopen the app using the secure link.';
      case MicrophonePermissionStatus.noMicrophone:
        return 'No microphone was found on this device. Use the search bar to type your query instead.';
      case MicrophonePermissionStatus.unsupported:
        return 'This device or browser does not support voice search. Use the search bar to type your query instead.';
    }
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
    // Once the recognizer is listening, we show the live transcript UI.
    // Before that — i.e. while we're waiting for permission, waiting for
    // the recognizer to come up, or sitting on a non-recoverable error —
    // we show a focused "needs your tap" gate so the user always knows
    // exactly what to do next.
    final waitingForTap = !_listening && (
      _permission != MicrophonePermissionStatus.granted ||
      !_available
    );
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
                                    : (_permission == null
                                          ? 'Preparing microphone…'
                                          : (_permission ==
                                                      MicrophonePermissionStatus
                                                          .granted
                                                  ? copy.microphoneUnavailable
                                                  : 'Microphone access needed'))),
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

                  if (waitingForTap) ...[
                    _PermissionGate(
                      isDark: isDark,
                      requesting: _requestingPermission,
                      canAskAgain: _permission == null ||
                          _permission == MicrophonePermissionStatus.denied,
                      onAllow: _askForPermission,
                    ),
                  ] else ...[
                    // Animated waveform (only while the recognizer is live)
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
                  ],
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
                      // While we're waiting for the user to grant
                      // permission, the primary action becomes
                      // "Allow microphone" instead of "Search" — the
                      // recognizer can't submit anything yet, and a
                      // disabled "Search" button next to "Cancel"
                      // looks broken.
                      if (waitingForTap)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _requestingPermission
                                ? null
                                : _askForPermission,
                            icon: _requestingPermission
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1B1B1B),
                                    ),
                                  )
                                : const Icon(Icons.mic_rounded, size: 18),
                            label: const Text('Allow microphone'),
                            style: FilledButton.styleFrom(
                              backgroundColor: PupColors.cyberAmber,
                              foregroundColor: const Color(0xFF1B1B1B),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: FilledButton(
                            onPressed: _lastWords.trim().isEmpty
                                ? null
                                : _submitAndClose,
                            style: FilledButton.styleFrom(
                              backgroundColor: PupColors.cyberAmber,
                              foregroundColor: const Color(0xFF1B1B1B),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
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

/// "We need your microphone" card. Shown in place of the waveform
/// while we're still waiting on a permission decision. The big amber
/// "Allow microphone" button is the same one the parent renders as
/// the primary action — this card just gives the user a single,
/// obvious place to tap that re-triggers the browser / OS prompt.
class _PermissionGate extends StatelessWidget {
  const _PermissionGate({
    required this.isDark,
    required this.requesting,
    required this.canAskAgain,
    required this.onAllow,
  });

  final bool isDark;
  final bool requesting;
  final bool canAskAgain;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : PupColors.slateGray;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: PupColors.cyberAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: PupColors.cyberAmber.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Voice search needs your microphone',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: textColor,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canAskAgain
                ? 'Tap “Allow microphone” so your browser can ask for permission. On a phone the prompt usually appears at the top of the screen.'
                : 'Microphone access is currently blocked. Use the lock icon beside the website address, allow Microphone, then come back and tap “Allow microphone”.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: textColor.withValues(alpha: 0.78),
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: requesting ? null : onAllow,
              icon: requesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1B1B1B),
                      ),
                    )
                  : const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Allow microphone'),
              style: FilledButton.styleFrom(
                backgroundColor: PupColors.cyberAmber,
                foregroundColor: const Color(0xFF1B1B1B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
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
