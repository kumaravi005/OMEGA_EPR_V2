import 'package:flutter/material.dart';

abstract final class AppShadows {
  /// `0 1px 2px rgba(16,24,40,.06), 0 10px 24px rgba(16,24,40,.10)` from the
  /// redesign brief - the elevation used by every redesigned card.
  static const card = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x1A101828), blurRadius: 24, offset: Offset(0, 10)),
  ];
}
