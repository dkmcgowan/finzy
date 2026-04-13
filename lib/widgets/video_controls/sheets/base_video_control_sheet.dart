import 'package:flutter/material.dart';

import '../../../focus/key_event_utils.dart';
import '../../../focus/dpad_navigator.dart';
import '../../../widgets/overlay_sheet.dart';
import 'video_sheet_header.dart';

/// Base class for video control bottom sheets providing common UI structure
class BaseVideoControlSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? iconColor;
  final VoidCallback? onBack;

  const BaseVideoControlSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.iconColor,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      children: [
        VideoSheetHeader(title: title, icon: icon, iconColor: iconColor, onBack: onBack),
        const Divider(color: Colors.white24, height: 1),
        Expanded(child: child),
      ],
    );

    // Intercept Back/Escape here: [OverlaySheetHost] ignores those keys for single-page
    // sheets so inner UIs can handle them first. Default closes the overlay when [onBack]
    // is null (e.g. track list); otherwise run the sheet's sub-navigation callback.
    final backAction = onBack ?? () => OverlaySheetController.of(context).close();
    content = Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey.isBackKey) {
          return handleBackKeyAction(event, backAction);
        }
        return KeyEventResult.ignored;
      },
      child: content,
    );

    return SizedBox(height: MediaQuery.of(context).size.height * 0.75, child: content);
  }
}
