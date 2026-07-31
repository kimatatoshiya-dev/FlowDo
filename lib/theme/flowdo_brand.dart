import 'package:flutter/material.dart';

import '../models/category_item.dart';

/// FlowDo ロゴ・カテゴリーパレットと共通のブランドカラー
List<Color> get flowdoBrandColors =>
    categoryColorPalette.map((value) => Color(value)).toList();
