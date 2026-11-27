import 'dart:async';

import 'package:audio_session/audio_session.dart';

import 'audio_focus.dart';

/// Android keeps the semantic SPEECH audio attributes for audiobooks. With
/// willPauseWhenDucked disabled, audio_session preserves MAY_DUCK as a separate
/// event rather than flattening it into a real transient loss.
class AndroidAudioSessionFocus implements AudioPlaybackFocus {
  AndroidAudioSessionFocus(this._session);

  final AudioSession _session;
  bool _ownsFocus = false;
  bool _temporarilyLost = false;
  int _focusLossGeneration = 0;

  static AudioSessionConfiguration get configuration =>
      const AudioSessionConfiguration.speech().copyWith(
        androidWillPauseWhenDucked: false,
      );

  @override
  Stream<AudioFocusEvent> get audioFocusEvents => Stream.multi((events) {
    var upstreams = 2;
    void onDone() {
      if (--upstreams == 0) unawaited(events.close());
    }

    final interruptions = _session.interruptionEventStream.listen(
      (interruption) {
        final event = mapInterruption(interruption);
        if (event != null) events.add(_observeFocus(event));
      },
      onError: events.addError,
      onDone: onDone,
    );
    final noisy = _session.becomingNoisyEventStream.listen(
      (_) => events.add(AudioFocusEvent.becomingNoisy),
      onError: events.addError,
      onDone: onDone,
    );
    events.onCancel = () async {
      await Future.wait([interruptions.cancel(), noisy.cancel()]);
    };
  });

  AudioFocusEvent _observeFocus(AudioFocusEvent event) {
    switch (event) {
      case AudioFocusEvent.transientLoss:
        _temporarilyLost = true;
      case AudioFocusEvent.gain:
        _temporarilyLost = false;
      case AudioFocusEvent.loss:
        _focusLossGeneration++;
        _ownsFocus = false;
        _temporarilyLost = false;
      case AudioFocusEvent.canDuck:
      case AudioFocusEvent.becomingNoisy:
        break;
    }
    return event;
  }

  static AudioFocusEvent? mapInterruption(AudioInterruptionEvent interruption) {
    if (!interruption.begin) {
      // Android reports regain as either the end of a duck or of a pause.
      return interruption.type == AudioInterruptionType.unknown
          ? null
          : AudioFocusEvent.gain;
    }
    return switch (interruption.type) {
      AudioInterruptionType.duck => AudioFocusEvent.canDuck,
      AudioInterruptionType.pause => AudioFocusEvent.transientLoss,
      AudioInterruptionType.unknown => AudioFocusEvent.loss,
    };
  }

  @override
  Future<bool> request() async {
    // audio_session caches the native request object, not the status after a
    // temporary loss; in that window another setActive(true) can say yes even
    // though the app has not regained focus. Wait for the OS callback instead.
    if (_temporarilyLost) return false;
    if (_ownsFocus) return true;
    final lossGeneration = _focusLossGeneration;
    final granted = await _session.setActive(true);
    if (!granted) {
      // The 0.2.3 plug-in retains its cached AudioFocusRequest even on an
      // unsuccessful request. Clear it so a manual retry really asks Android.
      await release();
      return false;
    }
    _ownsFocus = _focusLossGeneration == lossGeneration;
    return _ownsFocus && !_temporarilyLost;
  }

  @override
  Future<void> release() async {
    _focusLossGeneration++;
    _ownsFocus = false;
    _temporarilyLost = false;
    await _session.setActive(false);
  }
}
