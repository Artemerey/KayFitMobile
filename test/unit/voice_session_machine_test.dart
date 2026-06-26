// Unit tests for the continuous voice dictation state machine.
//
// Guards the behaviour fixed in "voice input no longer stops on pause":
// one logical recording is a chain of native sessions auto-restarted on pause,
// finalized text accumulated in a buffer instead of overwritten. These tests
// exercise the pure decision logic without a device or the speech plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:kayfit/features/chat/voice/voice_session_machine.dart';

void main() {
  group('VoiceSessionMachine — accumulation', () {
    test('combines committed buffer with live words, never overwriting', () {
      final m = VoiceSessionMachine();
      m.start();
      m.beginSession();

      expect(m.onWords('hello'), 'hello');
      expect(m.onWords('hello world'), 'hello world');

      // Session ends on a pause → words are committed, not lost.
      expect(m.onSessionEnded(), VoiceEndAction.restart);
      expect(m.committedTranscript, 'hello world');
      expect(m.currentWords, '');

      // Restarted session appends rather than clobbering earlier speech.
      m.beginSession();
      expect(m.onWords('how are you'), 'hello world how are you');
      expect(m.onSessionEnded(), VoiceEndAction.restart);
      expect(m.committedTranscript, 'hello world how are you');
    });

    test('start() clears the buffer for a fresh recording', () {
      final m = VoiceSessionMachine();
      m.start();
      m.beginSession();
      m.onWords('leftover');
      m.onSessionEnded();
      expect(m.committedTranscript, 'leftover');

      m.start();
      expect(m.committedTranscript, '');
      expect(m.currentWords, '');
      expect(m.emptySessions, 0);
      expect(m.userStopped, isFalse);
    });
  });

  group('VoiceSessionMachine — session end dedupe', () {
    test('a second end (done + notListening) is ignored', () {
      final m = VoiceSessionMachine();
      m.start();
      m.beginSession();
      m.onWords('hi');

      expect(m.onSessionEnded(), VoiceEndAction.restart);
      // The duplicate callback must not re-commit or re-decide.
      expect(m.onSessionEnded(), isNull);
      expect(m.committedTranscript, 'hi');
    });
  });

  group('VoiceSessionMachine — stop intent', () {
    test('requestStop makes the next end resolve to idle, not restart', () {
      final m = VoiceSessionMachine();
      m.start();
      m.beginSession();
      m.onWords('final words');

      m.requestStop();
      // requestStop clears sessionActive, so the in-flight end is a no-op...
      expect(m.onSessionEnded(), isNull);
      expect(m.userStopped, isTrue);
    });

    test('user stop while a session is active ends as idle', () {
      final m = VoiceSessionMachine();
      m.start();
      m.beginSession();
      m.onWords('text');
      // Simulate the user-stop flag being set without clearing sessionActive
      // (e.g. an error path) — the end must still go idle.
      m.userStopped = true;
      expect(m.onSessionEnded(), VoiceEndAction.idle);
    });
  });

  group('VoiceSessionMachine — empty-session soft cap', () {
    test('soft-stops after maxEmptySessions consecutive silent sessions', () {
      final m = VoiceSessionMachine(maxEmptySessions: 3);
      m.start();

      // Two silent sessions → keep restarting.
      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.restart);
      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.restart);
      // Third silent session hits the cap → soft stop.
      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.softStop);
      expect(m.userStopped, isTrue);
    });

    test('any speech resets the empty-session counter', () {
      final m = VoiceSessionMachine(maxEmptySessions: 3);
      m.start();

      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.restart); // empty=1
      m.beginSession();
      m.onWords('something'); // resets empty counter
      expect(m.onSessionEnded(), VoiceEndAction.restart); // empty=0
      expect(m.emptySessions, 0);

      // Two more silent sessions should NOT yet hit the cap of 3.
      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.restart); // empty=1
      m.beginSession();
      expect(m.onSessionEnded(), VoiceEndAction.restart); // empty=2
    });
  });

  group('VoiceSessionMachine — restart scheduling', () {
    test('tryScheduleRestart reserves a single slot', () {
      final m = VoiceSessionMachine();
      m.start();
      expect(m.tryScheduleRestart(), isTrue);
      // Already queued → no second schedule.
      expect(m.tryScheduleRestart(), isFalse);
    });

    test('tryScheduleRestart refuses once the user stopped', () {
      final m = VoiceSessionMachine();
      m.start();
      m.requestStop();
      expect(m.tryScheduleRestart(), isFalse);
    });

    test('onRestartFired clears the slot and reports whether to begin', () {
      final m = VoiceSessionMachine();
      m.start();
      m.tryScheduleRestart();

      expect(m.onRestartFired(), isTrue);
      expect(m.restartScheduled, isFalse);

      // If the user stopped during the delay, the restart is abandoned.
      m.tryScheduleRestart();
      m.userStopped = true;
      expect(m.onRestartFired(), isFalse);
    });
  });
}
