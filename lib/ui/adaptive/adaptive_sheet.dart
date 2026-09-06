import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import 'desktop_layout.dart';
import 'television_layout.dart';

/// Desktop options are bounded, keyboard-dismissable dialogs, not mobile sheets.
/// The body keeps its own scrolling and state when the host window is resized.
Future<T?> showAdaptiveSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  double maxWidth = 640,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = true,
}) {
  if (!DesktopLayout.isActive(context) && !TelevisionLayout.isActive(context)) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      showDragHandle: showDragHandle,
    );
  }

  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      constraints: BoxConstraints(maxWidth: maxWidth),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const ValueKey('desktop-options-dialog'),
        width: maxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                title == null ? 4 : 20,
                4,
                4,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: title == null
                        ? const SizedBox.shrink()
                        : Semantics(
                            header: true,
                            child: Text(
                              title,
                              key: const ValueKey('desktop-options-title'),
                              style: Theme.of(
                                dialogContext,
                              ).textTheme.titleLarge,
                            ),
                          ),
                  ),
                  IconButton(
                    key: const ValueKey('desktop-options-close'),
                    tooltip: MaterialLocalizations.of(
                      dialogContext,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const AppIcon(AppIconAssets.systemClose),
                  ),
                ],
              ),
            ),
            Flexible(child: Builder(builder: builder)),
          ],
        ),
      ),
    ),
  );
}
