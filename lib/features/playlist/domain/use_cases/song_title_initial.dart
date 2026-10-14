import 'package:lpinyin/lpinyin.dart';

/// 中文取拼音首字母，拉丁字母忽略大小写；数字、符号及其他文字归入 #。
/// 保留原标题和歌单顺序，只提供浏览提示。
String songTitleInitial(String title) {
  final trimmed = title.trimLeft();
  if (trimmed.isEmpty) return '#';
  final pinyin = PinyinHelper.getPinyinE(
    trimmed,
    separator: '',
    defPinyin: '#',
    format: PinyinFormat.WITHOUT_TONE,
  );
  if (pinyin.isEmpty) return '#';
  final first = pinyin[0].toUpperCase();
  return RegExp(r'^[A-Z]$').hasMatch(first) ? first : '#';
}
