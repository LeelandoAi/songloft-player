import 'package:flutter_test/flutter_test.dart';
import 'package:songloft_flutter/features/playlist/domain/use_cases/song_title_initial.dart';

void main() {
  test('中文、繁体与词组多音字取拼音首字母', () {
    expect(songTitleInitial('夜曲'), 'Y');
    expect(songTitleInitial('別讓愛凋落'), 'B');
    expect(songTitleInitial('重庆森林'), 'C');
    expect(songTitleInitial('  月亮代表我的心'), 'Y');
  });

  test('英文忽略大小写，数字、符号和其他文字归入 #', () {
    expect(songTitleInitial('hello'), 'H');
    expect(songTitleInitial('Yesterday'), 'Y');
    for (final title in ['', '   ', '123', '(Live)', '🎵夜曲', '별빛', 'あい']) {
      expect(songTitleInitial(title), '#', reason: title);
    }
  });
}
