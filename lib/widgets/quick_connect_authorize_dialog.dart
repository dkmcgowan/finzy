import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../focus/dpad_navigator.dart';
import '../i18n/strings.g.dart';
import '../providers/multi_server_provider.dart';
import '../utils/provider_extensions.dart';

const _buttonPadding = EdgeInsets.symmetric(horizontal: 18, vertical: 14);
const _buttonShape = StadiumBorder();

class QuickConnectAuthorizeDialog extends StatefulWidget {
  const QuickConnectAuthorizeDialog({super.key});

  @override
  State<QuickConnectAuthorizeDialog> createState() => _QuickConnectAuthorizeDialogState();
}

class _QuickConnectAuthorizeDialogState extends State<QuickConnectAuthorizeDialog> {
  final _codeController = TextEditingController();
  final _textFieldFocusNode = FocusNode();
  late final FocusNode _cancelFocusNode;
  bool _isAuthorizing = false;

  @override
  void initState() {
    super.initState();
    _cancelFocusNode = FocusNode(
      debugLabel: 'QuickConnect_cancel',
      onKeyEvent: (_, event) {
        if (!event.isActionable || event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          _textFieldFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _textFieldFocusNode.dispose();
    _cancelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _authorize() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isAuthorizing = true);

    try {
      final client = context.getFirstAvailableClient();
      final success = await client.authorizeQuickConnect(code);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.common.quickConnectSuccess)),
        );
      } else {
        setState(() => _isAuthorizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.common.quickConnectError)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAuthorizing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.common.quickConnectError)),
      );
    }
  }

  KeyEventResult _handleTextFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _cancelFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final hasServer = context.read<MultiServerProvider>().hasConnectedServers;
    final buttonStyle = TextButton.styleFrom(padding: _buttonPadding, shape: _buttonShape);

    return AlertDialog(
      title: Text(t.common.quickConnect),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.common.quickConnectDescription),
          const SizedBox(height: 24),
          Focus(
            onKeyEvent: _handleTextFieldKey,
            child: TextField(
              controller: _codeController,
              focusNode: _textFieldFocusNode,
              enabled: hasServer && !_isAuthorizing,
              decoration: InputDecoration(
                labelText: t.common.quickConnectCode,
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _authorize(),
              autofocus: true,
            ),
          ),
        ],
      ),
      actions: [
        FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FocusTraversalOrder(
                  order: const NumericFocusOrder(0),
                  child: TextButton(
                    focusNode: _cancelFocusNode,
                    onPressed: _isAuthorizing ? null : () => Navigator.of(context).pop(),
                    style: buttonStyle,
                    child: Text(t.common.cancel),
                  ),
                ),
                const SizedBox(width: 8),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: TextButton(
                    onPressed: _isAuthorizing ? null : _authorize,
                    style: buttonStyle,
                    child: _isAuthorizing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(t.common.authorize),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
