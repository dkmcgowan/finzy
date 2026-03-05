import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/settings_service.dart';
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
  SettingsService? _settingsService;
  bool _hideSupportDevelopment = false;
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      PackageInfo.fromPlatform(),
      SettingsService.getInstance(),
    ]);
    if (!mounted) return;
    final packageInfo = results[0] as PackageInfo;
    final settingsService = results[1] as SettingsService;
    setState(() {
      _appName = t.app.title;
      _appVersion = packageInfo.version;
      _settingsService = settingsService;
      _hideSupportDevelopment = settingsService.getHideSupportDevelopment();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final contentContext = _contentKey.currentContext;
      if (contentContext == null) return;
      final scope = FocusScope.of(contentContext);
      final firstChild = scope.traversalDescendants.cast<FocusNode?>().firstWhere(
        (node) => node!.canRequestFocus && node.context != null,
        orElse: () => null,
      );
      firstChild?.requestFocus();
    });
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

              if (!Platform.isAndroid && !Platform.isIOS) ...[
                const SizedBox(height: 8),

                Card(
                  child: SwitchListTile(
                    secondary: const AppIcon(Symbols.volunteer_activism_rounded, fill: 1),
                    title: Text(t.settings.hideSupportDevelopment),
                    subtitle: Text(t.settings.hideSupportDevelopmentDescription),
                    value: _hideSupportDevelopment,
                    onChanged: (value) async {
                      setState(() => _hideSupportDevelopment = value);
                      await _settingsService?.setHideSupportDevelopment(value);
                    },
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
