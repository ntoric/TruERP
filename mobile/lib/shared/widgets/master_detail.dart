import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'common.dart';

/// List beside detail when there's room (tablets), list only on phones.
///
/// Screens call [MasterDetail.isSplit] on tap: when split, they select the
/// row in place; otherwise they push the detail route.
class MasterDetail extends StatelessWidget {
  const MasterDetail({super.key, required this.list, this.detail, this.placeholderIcon = Icons.touch_app_outlined});

  final Widget list;
  final Widget? detail;
  final IconData placeholderIcon;

  static const splitWidth = 840.0;

  static bool isSplit(BuildContext context) => MediaQuery.sizeOf(context).width >= splitWidth + 80;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < splitWidth) return list;
      final listWidth = (c.maxWidth * 0.4).clamp(340.0, 460.0);
      return Row(
        children: [
          SizedBox(width: listWidth, child: list),
          VerticalDivider(width: 1, color: context.colors.outlineVariant),
          Expanded(
            child: detail ??
                EmptyState(icon: placeholderIcon, title: 'Select an item', message: 'Details appear here.'),
          ),
        ],
      );
    });
  }
}
