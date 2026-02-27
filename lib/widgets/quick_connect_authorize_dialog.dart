import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../providers/multi_server_provider.dart';
import '../utils/provider_extensions.dart';

class QuickConnectAuthorizeDialog extends StatefulWidget {
  const QuickConnectAuthorizeDialog({super.key});

  @override
  State<QuickConnectAuthorizeDialog> createState() => _QuickConnectAuthorizeDialogState();
}

class _QuickConnectAuthorizeDialogState extends State<QuickConnectAuthorizeDialog> {
  final _codeController = TextEditingController();
  bool _isAuthorizing = false;

  @override
  void dispose() {
    _codeController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final hasServer = context.read<MultiServerProvider>().hasConnectedServers;

    return AlertDialog(
      title: Text(t.common.quickConnect),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.common.quickConnectDescription),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            enabled: hasServer && !_isAuthorizing,
            decoration: InputDecoration(
              labelText: t.common.quickConnectCode,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _authorize(),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isAuthorizing ? null : () => Navigator.of(context).pop(),
          child: Text(t.common.cancel),
        ),
        FilledButton(
          onPressed: _isAuthorizing ? null : _authorize,
          child: _isAuthorizing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.common.authorize),
        ),
      ],
    );
  }
}
