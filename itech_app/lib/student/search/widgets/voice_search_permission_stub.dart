library;

/// Native (non-web) stub for the microphone permission request.
///
/// On Android / iOS / desktop the OS-level permission dialog is raised by
/// `speech_to_text.initialize()` in the main
/// `voice_search_permission.dart` file, so the web JS bridge is not used
/// here. This no-op keeps the conditional import happy so the file compiles
/// on every target.

/// No-op on native platforms (see [webRequestMic]).
Future<String> webRequestMic() async => 'unsupported';
