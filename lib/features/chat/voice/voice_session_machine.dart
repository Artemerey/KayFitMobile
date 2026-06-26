/// Pure state machine for continuous voice dictation (restart + accumulate).
///
/// The native `SFSpeechRecognizer` (iOS) ends a session on silence and has its
/// own ~60s ceiling. To let the user dictate freely with pauses and stop only
/// by tapping, one logical recording is treated as a chain of native sessions
/// that we restart ourselves, accumulating finalized text in a buffer.
///
/// This class owns ONLY the data and decisions — no Flutter, no `BuildContext`,
/// no speech plugin. The chat screen drives the side effects (calling
/// `listen()`, `setState`, scheduling the restart delay) and consults the
/// machine for what to do. Keeping it pure makes the dedup / accumulation /
/// soft-cap logic unit-testable without a device.
library;

/// What the UI should do after a native session ends.
enum VoiceEndAction {
  /// Recording is over (user stop / dispose / background) — go idle.
  idle,

  /// Too many empty sessions (prolonged silence / repeated instant failures) —
  /// stop the engine and go idle.
  softStop,

  /// A pause or the native session limit — keep recording, restart the engine.
  restart,
}

class VoiceSessionMachine {
  VoiceSessionMachine({this.maxEmptySessions = 6});

  /// Soft cap on consecutive empty sessions before the loop gives up.
  final int maxEmptySessions;

  /// True only when the user (tap / dispose / background) intentionally ended
  /// the recording. A native session ending on silence does NOT set this.
  bool userStopped = false;

  /// Text finalized from previous sessions in the current recording.
  String committedTranscript = '';

  /// Words recognized in the currently running native session (not yet
  /// committed). Reset to '' each time a session ends.
  String currentWords = '';

  /// Guards against handling the same session end twice (`done` and
  /// `notListening` both fire) and against acting on stray callbacks.
  bool sessionActive = false;

  /// True while a restart is already queued, to avoid double restarts.
  bool restartScheduled = false;

  /// Consecutive native sessions that produced no speech.
  int emptySessions = 0;

  /// Begins a fresh logical recording — clears the buffer and bookkeeping.
  void start() {
    userStopped = false;
    committedTranscript = '';
    currentWords = '';
    emptySessions = 0;
    restartScheduled = false;
  }

  /// Marks a native session as started.
  void beginSession() {
    sessionActive = true;
  }

  /// Records new (partial or final) words for the current session and returns
  /// the combined text to show in the field — committed buffer plus the live
  /// session, so a restart never clobbers earlier speech.
  String onWords(String words) {
    currentWords = words;
    if (words.isNotEmpty) emptySessions = 0;
    return '$committedTranscript $words'.trim();
  }

  /// Marks an intentional stop (user tap / dispose / background). Any in-flight
  /// session end will then resolve to [VoiceEndAction.idle], not a restart.
  void requestStop() {
    userStopped = true;
    restartScheduled = false;
    sessionActive = false;
  }

  /// Handles a native session end (status done/notListening, or a silence
  /// error). Commits the session's words, then returns the action the UI should
  /// take — or `null` if this is a duplicate end that was already handled.
  VoiceEndAction? onSessionEnded() {
    // Dedupe: done + notListening (and a trailing error) can all fire once.
    if (!sessionActive) return null;
    sessionActive = false;

    if (currentWords.isNotEmpty) {
      committedTranscript = '$committedTranscript $currentWords'.trim();
      currentWords = '';
      emptySessions = 0;
    } else {
      emptySessions++;
    }

    if (userStopped) return VoiceEndAction.idle;

    if (emptySessions >= maxEmptySessions) {
      userStopped = true;
      return VoiceEndAction.softStop;
    }

    return VoiceEndAction.restart;
  }

  /// Reserves a restart slot. Returns true if the caller should schedule the
  /// restart delay; false if a restart is already queued or the user stopped.
  bool tryScheduleRestart() {
    if (restartScheduled || userStopped) return false;
    restartScheduled = true;
    return true;
  }

  /// Called when the scheduled restart delay fires. Clears the queued flag and
  /// returns true if a new native session should actually begin.
  bool onRestartFired() {
    restartScheduled = false;
    return !userStopped;
  }
}
