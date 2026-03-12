import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../focus/dpad_navigator.dart';
import '../i18n/strings.g.dart';
import '../utils/platform_detector.dart';

/// Utility functions for showing common dialogs

const _buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
const _buttonShape = StadiumBorder();

ButtonStyle get _dialogButtonStyle => TextButton.styleFrom(padding: _buttonPadding, shape: _buttonShape);

/// A row of dialog buttons that supports arrow-key navigation.
class _DialogActions extends StatelessWidget {
  final List<Widget> children;
  const _DialogActions({required this.children});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            FocusTraversalOrder(
              order: NumericFocusOrder(i.toDouble()),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a confirmation dialog with consistent button sizing and autofocus.
/// Returns true if user confirmed, false if cancelled.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  String? cancelText,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          _DialogActions(
            children: [
              TextButton(
                autofocus: true,
                onPressed: () => Navigator.pop(dialogContext, false),
                style: _dialogButtonStyle,
                child: Text(cancelText ?? t.common.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: _dialogButtonStyle,
                child: Text(confirmText),
              ),
            ],
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}

/// Shows a confirmation dialog with an optional checkbox (e.g. "Don't ask again").
/// Returns a record with [confirmed] and [checked] booleans.
Future<({bool confirmed, bool checked})> showConfirmDialogWithCheckbox(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmText,
  required String checkboxLabel,
  String? cancelText,
}) async {
  var checked = false;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: checked,
                  onChanged: (v) => setDialogState(() => checked = v ?? false),
                  title: Text(checkboxLabel),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              ],
            ),
            actions: [
              _DialogActions(
                children: [
                  TextButton(
                    autofocus: true,
                    onPressed: () => Navigator.pop(dialogContext, false),
                    style: _dialogButtonStyle,
                    child: Text(cancelText ?? t.common.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: _dialogButtonStyle,
                    child: Text(confirmText),
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );

  return (confirmed: confirmed ?? false, checked: checked);
}

/// Shows a delete confirmation dialog.
/// Convenience wrapper around [showConfirmDialog] with destructive styling.
Future<bool> showDeleteConfirmation(BuildContext context, {required String title, required String message}) {
  return showConfirmDialog(context, title: title, message: message, confirmText: t.common.delete, isDestructive: true);
}

/// Shows a text input dialog for creating/naming items
/// Returns the entered text, or null if cancelled
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String labelText,
  required String hintText,
  String? initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) =>
        _TextInputDialog(title: title, labelText: labelText, hintText: hintText, initialValue: initialValue),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String labelText;
  final String hintText;
  final String? initialValue;

  const _TextInputDialog({required this.title, required this.labelText, required this.hintText, this.initialValue});

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller;
  late final FocusNode _textFocusNode;
  late final FocusNode _cancelFocusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _textFocusNode = FocusNode(debugLabel: 'TextInputDialog_text');
    _cancelFocusNode = FocusNode(
      debugLabel: 'TextInputDialog_cancel',
      onKeyEvent: (node, event) {
        if (!event.isActionable || event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _textFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _textFocusNode.dispose();
    _cancelFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.isNotEmpty) {
      Navigator.pop(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTV = PlatformDetector.isTV();

    final textField = TextField(
      controller: _controller,
      focusNode: _textFocusNode,
      autofocus: true,
      decoration: InputDecoration(labelText: widget.labelText, hintText: widget.hintText),
      onSubmitted: (_) => _submit(),
    );

    final content = isTV
        ? Focus(
            onKeyEvent: (node, event) {
              if (!event.isActionable || event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                _cancelFocusNode.requestFocus();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: textField,
          )
        : textField;

    return AlertDialog(
      title: Text(widget.title),
      content: content,
      actions: [
        TextButton(
          focusNode: _cancelFocusNode,
          onPressed: () => Navigator.pop(context),
          child: Text(t.common.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(t.common.save)),
      ],
    );
  }
}
