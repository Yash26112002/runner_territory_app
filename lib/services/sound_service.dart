import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundService {
  static final SoundService _instance = SoundService._internal();
  factory SoundService() => _instance;
  SoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> playStartWhistle() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/whistle.mp3'));
    } catch (e) {
      debugPrint('Error playing start sound: $e');
    }
  }

  Future<void> playCheer() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/cheer.mp3'));
    } catch (e) {
      debugPrint('Error playing cheer sound: $e');
    }
  }

  void dispose() {
    _player.dispose();
  }
}
