import 'package:flutter/material.dart';

/// Built-in seed tokens. Widgets use the resulting Material ColorScheme.
enum BuiltInPalette {
  blue(Color(0xFF415F91)),
  teal(Color(0xFF006A6A)),
  forest(Color(0xFF386A20)),
  rose(Color(0xFF984061)),
  amber(Color(0xFF895100)),
  violet(Color(0xFF7351A1));

  final Color seedColor;
  const BuiltInPalette(this.seedColor);

  static BuiltInPalette fromName(String? name) =>
      values.firstWhere((value) => value.name == name, orElse: () => blue);
}
