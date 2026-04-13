import 'dart:io';

import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../focus/focus_utils.dart';
import '../../services/update_service.dart';
import '../../utils/snackbar_helper.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../../i18n/strings.g.dart';
import 'licenses_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _appName = '';
  String _appVersion = '';
  bool _isCheckingForUpdate = false;
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _appName = t.app.title;
      _appVersion = packageInfo.version;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contentContext = _contentKey.currentContext;
      if (contentContext != null) {
        FocusUtils.focusFirstInSubtree(contentContext);
      }
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() => _isCheckingForUpdate = true);
    try {
      final updateInfo = await UpdateService.checkForUpdates();
      if (!mounted) return;
      setState(() => _isCheckingForUpdate = false);
      if (updateInfo != null && updateInfo['hasUpdate'] == true) {
        _showUpdateDialog(updateInfo);
      } else {
        showAppSnackBar(context, t.update.latestVersion);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingForUpdate = false);
        showErrorSnackBar(context, t.update.checkFailed);
      }
    }
  }

  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(t.update.available),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.update.versionAvailable(version: updateInfo['latestVersion']),
                style: Theme.of(dialogContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t.update.currentVersion(version: updateInfo['currentVersion']),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              autofocus: true,
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(t.common.later),
            ),
            TextButton(
              onPressed: () async {
                await UpdateService.skipVersion(updateInfo['latestVersion']);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: const StadiumBorder(),
              ),
              child: Text(t.update.skipVersion),
            ),
            FilledButton(
              onPressed: () async {
                final url = Uri.parse(
                    updateInfo['updateUrl'] as String? ?? updateInfo['releaseUrl'] as String);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                  (updateInfo['isStoreUpdate'] as bool? ?? false)
                      ? t.update.updateInStore
                      : t.update.viewRelease),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = _appName;
    final appVersion = _appVersion;

    return FocusedScrollScaffold(
      title: Text(t.about.title),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    Image.asset('assets/finzy.png', width: 80, height: 80),
                    const SizedBox(height: 16),
                    Text(
                      appName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.about.versionLabel(version: appVersion),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.about.appDescription,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              Card(
                key: _contentKey,
                child: ListTile(
                  leading: const AppIcon(Symbols.description_rounded, fill: 1),
                  title: Text(t.about.openSourceLicenses),
                  subtitle: Text(t.about.viewLicensesDescription),
                  trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const LicensesScreen()));
                  },
                ),
              ),

              if (UpdateService.isUpdateCheckEnabled &&
                  (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) ...[
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const AppIcon(Symbols.system_update_rounded, fill: 1),
                    title: Text(t.settings.checkForUpdates),
                    trailing: _isCheckingForUpdate
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                    onTap: _isCheckingForUpdate ? null : _checkForUpdates,
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
}
