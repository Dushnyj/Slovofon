/// Raw-enough playback interruptions to distinguish short notification tones
/// from an actual request for exclusive audio.
enum AudioFocusEvent { canDuck, transientLoss, loss, gain, becomingNoisy }

abstract interface class AudioInterruptionSource {
  Stream<AudioFocusEvent> get audioFocusEvents;
}

abstract interface class AudioPlaybackFocus implements AudioInterruptionSource {
  Future<bool> request();

  Future<void> release();
}
