import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../focus/focus_utils.dart';
import '../../services/update_service.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../../i18n/strings.g.dart';
import 'licenses_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

enum _UpdateStatus { idle, checking, upToDate, updateAvailable, failed }

class _AboutScreenState extends State<AboutScreen> {
  String _appName = '';
  String _appVersion = '';
  final _contentKey = GlobalKey();

  _UpdateStatus _updateStatus = _UpdateStatus.idle;
  String? _latestVersion;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkForUpdates();
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
    if (_updateStatus == _UpdateStatus.checking) return;
    setState(() {
      _updateStatus = _UpdateStatus.checking;
    });
    final result = await UpdateService.checkForUpdates();
    if (!mounted) return;
    setState(() {
      if (result == null) {
        _updateStatus = _UpdateStatus.failed;
        _latestVersion = null;
      } else if (result.hasUpdate) {
        _updateStatus = _UpdateStatus.updateAvailable;
        _latestVersion = result.latestVersion;
      } else {
        _updateStatus = _UpdateStatus.upToDate;
        _latestVersion = result.latestVersion;
      }
    });
  }

  String? _updateSubtitleText() {
    switch (_updateStatus) {
      case _UpdateStatus.idle:
        return null;
      case _UpdateStatus.checking:
        return t.update.checking;
      case _UpdateStatus.upToDate:
        return t.update.latestVersion;
      case _UpdateStatus.updateAvailable:
        return t.update.newVersionAvailable(version: _latestVersion ?? '');
      case _UpdateStatus.failed:
        return t.update.checkFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appName = _appName;
    final appVersion = _appVersion;
    final isChecking = _updateStatus == _UpdateStatus.checking;
    final updateSubtitle = _updateSubtitleText();
    final hasUpdate = _updateStatus == _UpdateStatus.updateAvailable;

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
                    if (hasUpdate) ...[
                      const SizedBox(height: 8),
                      Text(
                        t.update.newVersionAvailable(version: _latestVersion ?? ''),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

              const SizedBox(height: 8),

              Card(
                child: ListTile(
                  leading: const AppIcon(Symbols.system_update_rounded, fill: 1),
                  title: Text(t.update.checkForUpdatesButton),
                  subtitle: updateSubtitle != null ? Text(updateSubtitle) : null,
                  trailing: isChecking
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const AppIcon(Symbols.refresh_rounded, fill: 1),
                  onTap: _checkForUpdates,
                ),
              ),

              const SizedBox(height: 24),
            ]),
          ),
        ),
      ],
    );
  }
}
