import AppKit

/// Hands dictation to macOS instead of doing it in-process.
///
/// Beacon used to run its own `AVAudioEngine` and speech analyzer. That was a
/// mistake, for three reasons that all showed up in practice:
///
///   * The tap closure was formed in a `@MainActor` type, so Swift compiled an
///     isolation assertion into it, and the realtime audio thread trapped on the
///     first buffer.
///   * The engine negotiated a format against a device already running at a
///     different sample rate, which reconfigured the shared audio device and
///     degraded playback for everything else on the machine.
///   * It never actually worked: the graph reported running and delivered zero
///     buffers.
///
/// System dictation has none of those failure modes. The audio never enters this
/// process, so Beacon cannot seize a device, cannot crash on an audio thread,
/// and needs no microphone or speech-recognition permission of its own. It is
/// also the same recognizer Apple ships, so accuracy is not the trade.
enum SystemDictation {

    /// Asks macOS to start dictating into whatever field has focus.
    ///
    /// `startDictation:` is the action behind the Start Dictation item macOS
    /// puts in the Edit menu, so it travels the ordinary responder chain.
    /// Returns false when nothing handles it — dictation turned off in System
    /// Settings, for instance — so the caller can say so rather than appear to
    /// do nothing.
    @discardableResult
    @MainActor
    static func start() -> Bool {
        NSApp.sendAction(Selector(("startDictation:")), to: nil, from: nil)
    }

    static let hint = "Turn on Dictation in System Settings > Keyboard, then press the Fn key twice."
}
