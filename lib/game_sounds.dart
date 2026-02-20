import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

/// Generates short WAV beeps and plays game sounds without external asset files.
class GameSounds {
  GameSounds._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _muted = false;

  static void setMuted(bool muted) => _muted = muted;

  /// Build 8-bit mono WAV bytes (8 kHz) with a short tone.
  static Uint8List _wavBytes(int numSamples, {double freqHz = 440}) {
    const sampleRate = 8000;
    final dataSize = numSamples;
    final byteRate = sampleRate * 1 * 1;
    final blockAlign = 1;
    final chunkSize = 36 + dataSize;

    final out = ByteData(44 + dataSize);
    int i = 0;

    void writeStr(String s) {
      for (var k = 0; k < s.length; k++) out.setUint8(i++, s.codeUnitAt(k));
    }

    void writeU32(int v) {
      out.setUint32(i, v, Endian.little);
      i += 4;
    }

    void writeU16(int v) {
      out.setUint16(i, v, Endian.little);
      i += 2;
    }

    writeStr('RIFF');
    writeU32(chunkSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16);
    writeU16(1); // PCM
    writeU16(1); // mono
    writeU32(sampleRate);
    writeU32(byteRate);
    writeU16(blockAlign);
    writeU16(8);
    writeStr('data');
    writeU32(dataSize);

    final amp = 80.0;
    for (var t = 0; t < numSamples; t++) {
      final sample = 128 + amp * math.sin(2 * math.pi * freqHz * t / sampleRate);
      out.setUint8(44 + t, sample.clamp(0, 255).round());
    }
    return out.buffer.asUint8List();
  }

  static Future<void> _play(Uint8List wav) async {
    if (_muted) return;
    try {
      await _player.stop();
      await _player.setSource(BytesSource(wav, mimeType: 'audio/wav'));
      await _player.resume();
    } catch (_) {}
  }

  static void paddleHit() => _play(_wavBytes(400, freqHz: 220));
  static void brickHit() => _play(_wavBytes(200, freqHz: 880));
  static void gameOver() => _play(_wavBytes(1200, freqHz: 180));
  static void levelComplete() => _play(_wavBytes(800, freqHz: 523));
}
