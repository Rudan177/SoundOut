import 'package:flutter_test/flutter_test.dart';
import 'package:soundout/src/models.dart';

void main() {
  test('formats durations', () {
    expect(formatDuration(0), '--:--');
    expect(formatDuration(9000), '0:09');
    expect(formatDuration(65000), '1:05');
    expect(formatDuration(3661000), '1:01:01');
  });

  test('parses audio item from native map', () {
    final audio = AudioItem.fromMap({
      'id': 'abc',
      'title': '提示音',
      'artist': null,
      'durationMs': 12000,
      'path': '/tmp/a.mp3',
      'coverPath': null,
      'sizeBytes': 2048,
      'addedAt': 1,
    });
    expect(audio.title, '提示音');
    expect(audio.durationLabel, '0:12');
  });

  test('playback labels infinite and counted', () {
    const infinite = PlaybackSnapshot(
      audioId: 'a',
      title: 'a',
      playing: true,
      repeatTotal: 0,
    );
    expect(infinite.repeatLabel, '循环播放');
    const counted = PlaybackSnapshot(
      audioId: 'a',
      title: 'a',
      playing: true,
      repeatIndex: 2,
      repeatTotal: 3,
    );
    expect(counted.repeatLabel, '第 2/3 次');
  });
}
