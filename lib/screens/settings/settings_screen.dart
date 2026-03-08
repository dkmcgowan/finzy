import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../models/hotkey_model.dart';
import 'package:provider/provider.dart';

import '../auth_screen.dart';
import '../profile/jellyfin_profile_switch_screen.dart';
import '../../constants/library_constants.dart';
import '../../focus/dpad_navigator.dart';
import '../../focus/focus_memory_tracker.dart';
import '../../focus/focus_theme.dart';
import '../../focus/focus_utils.dart';
import '../../focus/input_mode_tracker.dart';
import '../../i18n/strings.g.dart';
import '../../models/media_library.dart';
import '../main_screen.dart';
import '../../mixins/refreshable.dart';
import '../../providers/hidden_libraries_provider.dart';
import '../../providers/libraries_provider.dart';
import '../../providers/multi_server_provider.dart';
import '../../providers/playback_state_provider.dart';
import '../../providers/server_state_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/user_profile_provider.dart';
import '../../utils/app_logger.dart';
import '../../utils/provider_extensions.dart';

import '../../services/download_storage_service.dart';
import '../../services/saf_storage_service.dart';
import '../../services/keyboard_shortcuts_service.dart';
import '../../services/settings_service.dart' as settings;
import '../../utils/dialogs.dart';
import '../../utils/snackbar_helper.dart';
import '../../utils/platform_detector.dart';
import '../../widgets/desktop_app_bar.dart';
import '../../widgets/quick_connect_authorize_dialog.dart';
import '../../widgets/focused_scroll_scaffold.dart';
import '../../widgets/tv_number_spinner.dart';
import 'hotkey_recorder_widget.dart';
import 'about_screen.dart';
import 'logs_screen.dart';
import 'mpv_config_screen.dart';
import 'subtitle_styling_screen.dart';
import '../../constants/support_constants.dart';
import '../../services/support_service.dart';

/// Helper class for option selection dialog items
class _DialogOption<T> {
  final T value;
  final String title;
  final String? subtitle;

  const _DialogOption({required this.value, required this.title, this.subtitle});
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with FocusableTab {
  late settings.SettingsService _settingsService;
  late final FocusMemoryTracker _focusTracker;

  // Setting keys for focus tracking
  static const _kAppearance = 'appearance';
  static const _kVideoPlayback = 'video_playback';

  static const _kAdvanced = 'advanced';
  static const _kAbout = 'about';
  static const _kSwitchProfile = 'switch_profile';
  static const _kQuickConnect = 'quick_connect';
  static const _kLogout = 'logout';
  static const _kTheme = 'theme';
  static const _kLanguage = 'language';
  static const _kLibraryDensity = 'library_density';
  static const _kViewMode = 'view_mode';
  static const _kEpisodePosterMode = 'episode_poster_mode';
  static const _kTimeFormat = 'time_format';
  static const _kAnimations = 'animations';
  static const _kShowHeroSection = 'show_hero_section';
  static const _kUseGlobalHubs = 'use_global_hubs';
  static const _kShowServerNameOnHubs = 'show_server_name_on_hubs';
  static const _kShowJellyfinRecommendations = 'show_jellyfin_recommendations';
  static const _kAlwaysKeepSidebarOpen = 'always_keep_sidebar_open';
  static const _kShowUnwatchedCount = 'show_unwatched_count';
  static const _kConfirmExitOnBack = 'confirm_exit_on_back';
  static const _kPlayerBackend = 'player_backend';
  static const _kLiveTvPlayer = 'live_tv_player';
  static const _kHardwareDecoding = 'hardware_decoding';
  static const _kMatchContentFrameRate = 'match_content_frame_rate';
  static const _kBufferSize = 'buffer_size';
  static const _kSubtitleStyling = 'subtitle_styling';
  static const _kMpvConfig = 'mpv_config';
  static const _kSmallSkipDuration = 'small_skip_duration';
  static const _kLargeSkipDuration = 'large_skip_duration';
  static const _kDefaultSleepTimer = 'default_sleep_timer';
  static const _kMaxVolume = 'max_volume';

  static const _kRememberTrackSelections = 'remember_track_selections';
  static const _kClickVideoTogglesPlayback = 'click_video_toggles_playback';
  static const _kAutoSkipIntro = 'auto_skip_intro';
  static const _kAutoSkipOutro = 'auto_skip_outro';
  static const _kAutoSkipRecap = 'auto_skip_recap';
  static const _kAutoSkipPreview = 'auto_skip_preview';
  static const _kAutoSkipCommercial = 'auto_skip_commercial';
  static const _kEnableExternalSubtitles = 'enable_external_subtitles';
  static const _kEnableTrickplay = 'enable_trickplay';
  static const _kEnableChapterImages = 'enable_chapter_images';
  static const _kAutoSkipDelay = 'auto_skip_delay';
  static const _kShowDownloads = 'show_downloads';
  static const _kDownloadLocation = 'download_location';
  static const _kDownloadOnWifiOnly = 'download_on_wifi_only';
  static const _kVideoPlayerControls = 'video_player_controls';
  static const _kVideoPlayerNavigation = 'video_player_navigation';
  static const _kDebugLogging = 'debug_logging';
  static const _kViewLogs = 'view_logs';
  static const _kClearCache = 'clear_cache';
  static const _kResetSettings = 'reset_settings';
  static const _kSupportCoffee = 'support_coffee';
  static const _kSupportLunch = 'support_lunch';
  static const _kSupportDev = 'support_dev';
  static const _kLibrariesSection = 'libraries_section';

  static const _kImageQuality = 'image_quality';
  static const _kPosterSize = 'poster_size';
  static const _kGridPreload = 'grid_preload';
  KeyboardShortcutsService? _keyboardService;
  late final bool _keyboardShortcutsSupported = KeyboardShortcutsService.isPlatformSupported();
  bool _isLoading = true;
  bool _hasRequestedInitialFocus = false;

  bool _enableDebugLogging = false;
  bool _enableHardwareDecoding = true;
  int _bufferSize = 128;
  int _seekTimeSmall = 10;
  int _seekTimeLarge = 30;
  int _sleepTimerDuration = 30;
  bool _rememberTrackSelections = true;
  bool _clickVideoTogglesPlayback = false;
  bool _autoSkipIntro = false;
  bool _autoSkipOutro = false;
  bool _autoSkipRecap = false;
  bool _autoSkipPreview = false;
  bool _autoSkipCommercial = false;
  bool _enableExternalSubtitles = false;
  bool _enableTrickplay = false;
  bool _enableChapterImages = false;
  int _autoSkipDelay = 5;
  bool _downloadOnWifiOnly = false;
  bool _videoPlayerNavigationEnabled = false;
  int _maxVolume = 100;

  bool _matchContentFrameRate = false;
  bool _useExoPlayer = true; // Android only: ExoPlayer vs MPV
  bool _useExoPlayerForLiveTv = false; // Android only: Live TV player (default MPV)
  bool _confirmExitOnBack = true;
  bool _hideSupportDevelopment = false;

  final _sectionNotifier = ValueNotifier<int>(0);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _sectionNotifier.value++;
  }

  @override
  void initState() {
    super.initState();
    _focusTracker = FocusMemoryTracker(
      onFocusChanged: () {
        // ignore: no-empty-block - setState triggers rebuild to update focus styling
        if (mounted) setState(() {});
      },
      debugLabelPrefix: 'settings',
    );
    _loadSettings();
  }

  @override
  void dispose() {
    _sectionNotifier.dispose();
    _focusTracker.dispose();
    super.dispose();
  }

  bool get _showSupportDevelopment =>
      SupportService.instance.isAvailable &&
      !_hideSupportDevelopment &&
      !Platform.isAndroid &&
      !Platform.isIOS &&
      !PlatformDetector.isTV() &&
      !PlatformDetector.isAmazon();

  @override
  void focusActiveTabIfReady() {
    if (!InputModeTracker.isKeyboardMode(context)) return;
    // Always start at the top when returning to Settings (no focus memory)
    final firstKey = _showSupportDevelopment ? _kSupportCoffee : _kAppearance;
    _focusTracker.get(firstKey).requestFocus();
  }

  /// Navigate focus to the sidebar
  void _navigateToSidebar() {
    MainScreenFocusScope.of(context)?.focusSidebar();
  }

  /// Handle key events for LEFT arrow → sidebar navigation
  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _navigateToSidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadSettings() async {
    _settingsService = await settings.SettingsService.getInstance();
    if (_keyboardShortcutsSupported) {
      _keyboardService = await KeyboardShortcutsService.getInstance();
    }

    if (!mounted) return;
    setState(() {
      _enableDebugLogging = _settingsService.getEnableDebugLogging();
      _enableHardwareDecoding = _settingsService.getEnableHardwareDecoding();
      _bufferSize = _settingsService.getBufferSize();
      _seekTimeSmall = _settingsService.getSeekTimeSmall();
      _seekTimeLarge = _settingsService.getSeekTimeLarge();
      _sleepTimerDuration = _settingsService.getSleepTimerDuration();
      _rememberTrackSelections = _settingsService.getRememberTrackSelections();
      _clickVideoTogglesPlayback = _settingsService.getClickVideoTogglesPlayback();
      _autoSkipIntro = _settingsService.getAutoSkipIntro();
      _autoSkipOutro = _settingsService.getAutoSkipOutro();
      _autoSkipRecap = _settingsService.getAutoSkipRecap();
      _autoSkipPreview = _settingsService.getAutoSkipPreview();
      _autoSkipCommercial = _settingsService.getAutoSkipCommercial();
      _enableExternalSubtitles = _settingsService.getEnableExternalSubtitles();
      _enableTrickplay = _settingsService.getEnableTrickplay();
      _enableChapterImages = _settingsService.getEnableChapterImages();
      _autoSkipDelay = _settingsService.getAutoSkipDelay();
      _downloadOnWifiOnly = _settingsService.getDownloadOnWifiOnly();
      _videoPlayerNavigationEnabled = _settingsService.getVideoPlayerNavigationEnabled();
      _maxVolume = _settingsService.getMaxVolume();

      _matchContentFrameRate = _settingsService.getMatchContentFrameRate();
      _useExoPlayer = _settingsService.getUseExoPlayer();
      _useExoPlayerForLiveTv = _settingsService.getUseExoPlayerForLiveTv();
      _confirmExitOnBack = _settingsService.getConfirmExitOnBack();
      _hideSupportDevelopment = _settingsService.getHideSupportDevelopment();
      _isLoading = false;
    });
  }

  void _handleSwitchProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const JellyfinProfileSwitchScreen()));
  }

  void _handleQuickConnect() {
    showDialog(context: context, builder: (_) => const QuickConnectAuthorizeDialog()).then((_) {
      if (mounted) _restoreFocusTo(_kQuickConnect);
    });
  }

  void _restoreFocusTo(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FocusScope.of(context).requestFocus(_focusTracker.get(key));
    });
  }

  Future<void> _handleLogout() async {
    final confirm = await showConfirmDialog(
      context,
      title: t.common.logout,
      message: t.messages.logoutConfirm,
      confirmText: t.common.logout,
      isDestructive: true,
    );

    if (!confirm && mounted) {
      _restoreFocusTo(_kLogout);
      return;
    }

    if (confirm && mounted) {
      final userProfileProvider = Provider.of<UserProfileProvider>(context, listen: false);
      final multiServerProvider = context.read<MultiServerProvider>();
      final serverStateProvider = context.read<ServerStateProvider>();
      final hiddenLibrariesProvider = context.read<HiddenLibrariesProvider>();
      final playbackStateProvider = context.read<PlaybackStateProvider>();

      await userProfileProvider.logout();
      multiServerProvider.clearAllConnections();
      serverStateProvider.reset();
      await hiddenLibrariesProvider.refresh();
      playbackStateProvider.clearShuffle();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // First-focus when main settings list first appears (keyboard/dpad only)
    if (!_hasRequestedInitialFocus) {
      _hasRequestedInitialFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!InputModeTracker.isKeyboardMode(context)) return;
        final firstKey = _showSupportDevelopment ? _kSupportCoffee : _kAppearance;
        _focusTracker.get(firstKey).requestFocus();
      });
    }

    final listTileTheme = ListTileTheme.of(context).copyWith(
      titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontSize: 17,
      ),
    );

    return Scaffold(
      body: ListTileTheme(
        data: listTileTheme,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: _handleKeyEvent,
          child: CustomScrollView(
          slivers: [
            CustomAppBar(
              title: Text(t.settings.title),
              pinned: true,
              toolbarHeight: 72,
            ),
            SliverPadding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_showSupportDevelopment) ...[
                    _buildSupportDevelopmentSection(),
                  ],
                  _buildSectionNavTile(
                    _kAppearance,
                    t.settings.appearance,
                    Symbols.palette_rounded,
                    _buildAppearanceContent,
                    autofocus: !_showSupportDevelopment,
                    firstFocusNode: _focusTracker.get(_kTheme),
                  ),
                  _buildSectionNavTile(
                    _kLibrariesSection,
                    t.navigation.libraries,
                    Symbols.video_library_rounded,
                    _buildLibrariesContent,
                    firstFocusNode: _focusTracker.get(_kShowDownloads),
                  ),
                  _buildSectionNavTile(
                    _kVideoPlayback,
                    t.settings.videoPlayback,
                    Symbols.play_circle_rounded,
                    _buildVideoPlaybackContent,
                    firstFocusNode: _focusTracker.get(Platform.isAndroid ? _kPlayerBackend : _kHardwareDecoding),
                  ),
                  _buildSectionNavTile(
                    _kAdvanced,
                    t.settings.advanced,
                    Symbols.tune_rounded,
                    _buildAdvancedContent,
                    firstFocusNode: _focusTracker.get(_kImageQuality),
                  ),
                  ListTile(
                    focusNode: _focusTracker.get(_kSwitchProfile),
                    leading: const AppIcon(Symbols.switch_account_rounded, fill: 1),
                    title: Text(t.discover.switchProfile),
                    trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                    onTap: () => _handleSwitchProfile(),
                  ),
                  ListTile(
                    focusNode: _focusTracker.get(_kQuickConnect),
                    leading: const AppIcon(Symbols.qr_code_rounded, fill: 1),
                    title: Text(t.common.quickConnect),
                    onTap: () => _handleQuickConnect(),
                  ),
                  ListTile(
                    focusNode: _focusTracker.get(_kLogout),
                    leading: AppIcon(Symbols.logout_rounded, fill: 1, color: Theme.of(context).colorScheme.error),
                    title: Text(t.common.logout, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold)),
                    onTap: () => _handleLogout(),
                  ),
                  _buildSectionNavTile(_kAbout, t.settings.about, Symbols.info_rounded, null, directRoute: const AboutScreen()),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildSectionNavTile(
    String sectionKey,
    String title,
    IconData icon,
    Widget Function()? buildContent, {
    Widget? directRoute,
    bool autofocus = false,
    FocusNode? firstFocusNode,
  }) {
    return ListTile(
      autofocus: autofocus,
      focusNode: _focusTracker.get(sectionKey),
      leading: AppIcon(icon, fill: 1),
      title: Text(title),
      trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
      onTap: () async {
        if (directRoute != null) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => directRoute));
        } else if (buildContent != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _SettingsSectionPage(
                title: title,
                content: buildContent,
                rebuildNotifier: _sectionNotifier,
                firstFocusNode: firstFocusNode,
              ),
            ),
          );
        }
        if (mounted) _loadSettings();
      },
    );
  }

  Widget _buildSupportDevelopmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSupportTierTile(
          key: _kSupportCoffee,
          icon: Symbols.coffee_rounded,
          title: t.settings.supportTierCoffee,
          amount: '\$${SupportTier.coffee.amount.toStringAsFixed(2)}',
          tier: SupportTier.coffee,
        ),
        _buildSupportTierTile(
          key: _kSupportLunch,
          icon: Symbols.restaurant_rounded,
          title: t.settings.supportTierLunch,
          amount: '\$${SupportTier.lunch.amount.toStringAsFixed(2)}',
          tier: SupportTier.lunch,
        ),
        _buildSupportTierTile(
          key: _kSupportDev,
          icon: Symbols.rocket_launch_rounded,
          title: t.settings.supportTierSupport,
          amount: '\$${SupportTier.support.amount.toStringAsFixed(2)}',
          tier: SupportTier.support,
        ),
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildSupportTierTile({
    required String key,
    required IconData icon,
    required String title,
    required String amount,
    required SupportTier tier,
  }) {
    return ListTile(
      focusNode: _focusTracker.get(key),
      leading: AppIcon(icon, fill: 1),
      title: Text(title),
      subtitle: Text(amount),
      trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
      onTap: () => _handleSupportTierTap(tier),
    );
  }

  Future<void> _handleSupportTierTap(SupportTier tier) async {
    final success = await SupportService.instance.tip(tier);
    if (mounted) {
      if (success) {
        showSuccessSnackBar(context, t.settings.supportTipThankYou);
      }
    }
  }

  Widget _buildAppearanceContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                focusNode: _focusTracker.get(_kTheme),
                leading: AppIcon(themeProvider.themeModeIcon, fill: 1),
                title: Text(t.settings.theme),
                subtitle: Text(themeProvider.themeModeDisplayName),
                trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                onTap: () => _showThemeDialog(themeProvider),
              );
            },
          ),
          ListTile(
            focusNode: _focusTracker.get(_kLanguage),
            leading: const AppIcon(Symbols.language_rounded, fill: 1),
            title: Text(t.settings.language),
            subtitle: Text(_getLanguageDisplayName(LocaleSettings.currentLocale)),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showLanguageDialog(),
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return ListTile(
                focusNode: _focusTracker.get(_kLibraryDensity),
                leading: const AppIcon(Symbols.grid_view_rounded, fill: 1),
                title: Text(t.settings.libraryDensity),
                subtitle: Text(settingsProvider.libraryDensityDisplayName),
                trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                onTap: () => _showLibraryDensityDialog(),
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return ListTile(
                focusNode: _focusTracker.get(_kViewMode),
                leading: const AppIcon(Symbols.view_list_rounded, fill: 1),
                title: Text(t.settings.viewMode),
                subtitle: Text(
                  settingsProvider.viewMode == settings.ViewMode.grid ? t.settings.gridView : t.settings.listView,
                ),
                trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                onTap: () => _showViewModeDialog(),
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return ListTile(
                focusNode: _focusTracker.get(_kEpisodePosterMode),
                leading: const AppIcon(Symbols.image_rounded, fill: 1),
                title: Text(t.settings.episodePosterMode),
                subtitle: Text(settingsProvider.episodePosterModeDisplayName),
                trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                onTap: () => _showEpisodePosterModeDialog(),
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return ListTile(
                focusNode: _focusTracker.get(_kTimeFormat),
                leading: const AppIcon(Symbols.schedule_rounded, fill: 1),
                title: Text(t.settings.timeFormat),
                subtitle: Text(settingsProvider.timeFormatDisplayName),
                trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
                onTap: () => _showTimeFormatDialog(),
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kAnimations),
                secondary: const AppIcon(Symbols.animation_rounded, fill: 1),
                title: Text(t.settings.animations),
                subtitle: Text(t.settings.animationsDescription),
                value: settingsProvider.animationsEnabled,
                onChanged: (value) async {
                  await settingsProvider.setAnimationsEnabled(value);
                },
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kShowHeroSection),
                secondary: const AppIcon(Symbols.featured_play_list_rounded, fill: 1),
                title: Text(t.settings.showHeroSection),
                subtitle: Text(t.settings.showHeroSectionDescription),
                value: settingsProvider.showHeroSection,
                onChanged: (value) async {
                  await settingsProvider.setShowHeroSection(value);
                },
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kUseGlobalHubs),
                secondary: const AppIcon(Symbols.home_rounded, fill: 1),
                title: Text(t.settings.useGlobalHubs),
                subtitle: Text(t.settings.useGlobalHubsDescription),
                value: settingsProvider.useGlobalHubs,
                onChanged: (value) async {
                  await settingsProvider.setUseGlobalHubs(value);
                },
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kShowServerNameOnHubs),
                secondary: const AppIcon(Symbols.dns_rounded, fill: 1),
                title: Text(t.settings.showServerNameOnHubs),
                subtitle: Text(t.settings.showServerNameOnHubsDescription),
                value: settingsProvider.showServerNameOnHubs,
                onChanged: (value) async {
                  await settingsProvider.setShowServerNameOnHubs(value);
                },
              );
            },
          ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kShowJellyfinRecommendations),
                secondary: const AppIcon(Symbols.recommend_rounded, fill: 1),
                title: Text(t.settings.showJellyfinRecommendations),
                subtitle: Text(t.settings.showJellyfinRecommendationsDescription),
                value: settingsProvider.showJellyfinRecommendations,
                onChanged: (value) async {
                  await settingsProvider.setShowJellyfinRecommendations(value);
                },
              );
            },
          ),
          if (PlatformDetector.shouldUseSideNavigation(context))
            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, child) {
                return SwitchListTile(
                  focusNode: _focusTracker.get(_kAlwaysKeepSidebarOpen),
                  secondary: const AppIcon(Symbols.dock_to_left_rounded, fill: 1),
                  title: Text(t.settings.alwaysKeepSidebarOpen),
                  subtitle: Text(t.settings.alwaysKeepSidebarOpenDescription),
                  value: settingsProvider.alwaysKeepSidebarOpen,
                  onChanged: (value) async {
                    await settingsProvider.setAlwaysKeepSidebarOpen(value);
                  },
                );
              },
            ),
          Consumer<SettingsProvider>(
            builder: (context, settingsProvider, child) {
              return SwitchListTile(
                focusNode: _focusTracker.get(_kShowUnwatchedCount),
                secondary: const AppIcon(Symbols.counter_1_rounded, fill: 1),
                title: Text(t.settings.showUnwatchedCount),
                subtitle: Text(t.settings.showUnwatchedCountDescription),
                value: settingsProvider.showUnwatchedCount,
                onChanged: (value) async {
                  await settingsProvider.setShowUnwatchedCount(value);
                },
              );
            },
          ),
          if (PlatformDetector.isTV())
            SwitchListTile(
              focusNode: _focusTracker.get(_kConfirmExitOnBack),
              secondary: const AppIcon(Symbols.exit_to_app_rounded, fill: 1),
              title: Text(t.settings.confirmExitOnBack),
              subtitle: Text(t.settings.confirmExitOnBackDescription),
              value: _confirmExitOnBack,
              onChanged: (value) async {
                setState(() => _confirmExitOnBack = value);
                await _settingsService.setConfirmExitOnBack(value);
              },
            ),
      ],
    );
  }

  List<Widget> _buildPerformanceItems() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    return [
      ListTile(
        focusNode: _focusTracker.get(_kImageQuality),
        leading: const AppIcon(Symbols.image_rounded, fill: 1),
        title: Text(t.settings.performanceImageQuality),
        subtitle: Text(settingsProvider.imageQualityDisplayName),
        trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
        onTap: () => _showImageQualityDialog(settingsProvider),
      ),
      ListTile(
        focusNode: _focusTracker.get(_kPosterSize),
        leading: const AppIcon(Symbols.grid_view_rounded, fill: 1),
        title: Text(t.settings.performancePosterSize),
        subtitle: Text(settingsProvider.posterSizeDisplayName),
        trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
        onTap: () => _showPosterSizeDialog(settingsProvider),
      ),
      ListTile(
        focusNode: _focusTracker.get(_kGridPreload),
        leading: const AppIcon(Symbols.view_carousel_rounded, fill: 1),
        title: Text(t.settings.performanceGridPreload),
        subtitle: Text(settingsProvider.gridPreloadDisplayName),
        trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
        onTap: () => _showGridPreloadDialog(settingsProvider),
      ),
    ];
  }

  Future<void> _showImageQualityDialog(SettingsProvider settingsProvider) async {
    final selected = await showDialog<settings.PerformanceProfile>(
      context: context,
      builder: (context) => _PerformanceProfileDialog(
        title: t.settings.performanceImageQuality,
        value: settingsProvider.imageQuality,
        onSelected: (v) => Navigator.pop(context, v),
      ),
    );
    if (selected != null && mounted) {
      await settingsProvider.setImageQuality(selected);
    }
  }

  Future<void> _showPosterSizeDialog(SettingsProvider settingsProvider) async {
    final selected = await showDialog<settings.PerformanceProfile>(
      context: context,
      builder: (context) => _PerformanceProfileDialog(
        title: t.settings.performancePosterSize,
        value: settingsProvider.posterSize,
        onSelected: (v) => Navigator.pop(context, v),
      ),
    );
    if (selected != null && mounted) {
      await settingsProvider.setPosterSize(selected);
    }
  }

  Future<void> _showGridPreloadDialog(SettingsProvider settingsProvider) async {
    final selected = await showDialog<settings.GridPreloadLevel>(
      context: context,
      builder: (context) => _GridPreloadDialog(
        value: settingsProvider.gridPreload,
        onSelected: (v) => Navigator.pop(context, v),
      ),
    );
    if (selected != null && mounted) {
      await settingsProvider.setGridPreload(selected);
    }
  }

  Widget _buildLibrariesContent() {
    return Consumer2<LibrariesProvider, HiddenLibrariesProvider>(
      builder: (context, librariesProvider, hiddenProvider, child) {
        final allLibraries = _buildOrderedLibraries(librariesProvider);
        final hiddenKeys = hiddenProvider.hiddenLibraryKeys;
        final isTV = PlatformDetector.isTV();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ..._buildDownloadsItems(),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, right: 16, bottom: 4),
              child: Text(
                t.settings.libraryOrder,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (isTV)
              _buildLibrariesListTV(allLibraries, hiddenKeys, librariesProvider, hiddenProvider)
            else
              _buildLibrariesListNonTV(allLibraries, hiddenKeys, librariesProvider, hiddenProvider),
          ],
        );
      },
    );
  }

  List<Widget> _buildDownloadsItems() {
    final storageService = DownloadStorageService.instance;
    final isCustom = storageService.isUsingCustomPath();

    return [
      Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return SwitchListTile(
            focusNode: _focusTracker.get(_kShowDownloads),
            secondary: const AppIcon(Symbols.download_rounded, fill: 1),
            title: Text(t.settings.showDownloads),
            subtitle: Text(t.settings.showDownloadsDescription),
            value: settingsProvider.showDownloads,
            onChanged: (value) async {
              await settingsProvider.setShowDownloads(value);
            },
          );
        },
      ),
      if (!Platform.isIOS)
        FutureBuilder<String>(
          future: storageService.getCurrentDownloadPathDisplay(),
          builder: (context, snapshot) {
            final currentPath = snapshot.data ?? '...';
            return ListTile(
              focusNode: _focusTracker.get(_kDownloadLocation),
              leading: const AppIcon(Symbols.folder_rounded, fill: 1),
              title: Text(isCustom ? t.settings.downloadLocationCustom : t.settings.downloadsDefault),
              subtitle: Text(currentPath, maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
              onTap: () => _showDownloadLocationDialog(),
            );
          },
        ),
      SwitchListTile(
        focusNode: _focusTracker.get(_kDownloadOnWifiOnly),
        secondary: const AppIcon(Symbols.wifi_rounded, fill: 1),
        title: Text(t.settings.downloadOnWifiOnly),
        subtitle: Text(t.settings.downloadOnWifiOnlyDescription),
        value: _downloadOnWifiOnly,
        onChanged: (value) async {
          setState(() => _downloadOnWifiOnly = value);
          await _settingsService.setDownloadOnWifiOnly(value);
        },
      ),
    ];
  }

  Widget _buildLibrariesListTV(
    List<MediaLibrary> allLibraries,
    Set<String> hiddenKeys,
    LibrariesProvider librariesProvider,
    HiddenLibrariesProvider hiddenProvider,
  ) {
    return _buildLibrariesSectionTV(
      allLibraries,
      hiddenKeys,
      librariesProvider,
      hiddenProvider,
      sectionHeaderFocusNode: _focusTracker.get(_kDownloadOnWifiOnly),
    );
  }

  Widget _buildLibrariesListNonTV(
    List<MediaLibrary> allLibraries,
    Set<String> hiddenKeys,
    LibrariesProvider librariesProvider,
    HiddenLibrariesProvider hiddenProvider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allLibraries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  t.discover.noItemsFound,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: allLibraries.length,
                  // ignore: deprecated_member_use - onReorderItem not in CI's Flutter SDK yet
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex--;
                    final reordered = List<MediaLibrary>.from(allLibraries);
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    librariesProvider.updateLibraryOrder(reordered);
                  },
                  itemBuilder: (context, index) {
                    final library = allLibraries[index];
                    final isFavorites = library.globalKey == kJellyfinFavoritesKey;
                    final isHidden = hiddenKeys.contains(library.globalKey);

                    return ListTile(
                      key: ValueKey(library.globalKey),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle, size: 24),
                          ),
                          const SizedBox(width: 12),
                          AppIcon(_getLibraryIcon(library.type), fill: 1, size: 24),
                        ],
                      ),
                      title: Text(
                        library.title,
                        style: TextStyle(
                          color: isHidden ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isFavorites) ...[
                            Semantics(
                              label: t.libraries.scanLibraryFiles,
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                icon: const AppIcon(Symbols.refresh_rounded, fill: 1, size: 24),
                                tooltip: null,
                                onPressed: () => _scanLibrary(library),
                              ),
                            ),
                            Semantics(
                              label: t.libraries.refreshMetadata,
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                icon: const AppIcon(Symbols.sync_rounded, fill: 1, size: 24),
                                tooltip: null,
                                onPressed: () => _refreshLibraryMetadata(library),
                              ),
                            ),
                          ] else
                            const SizedBox(width: 96),
                          Semantics(
                            label: isHidden ? t.libraries.showLibrary : t.libraries.hideLibrary,
                            button: true,
                            excludeSemantics: true,
                            child: IconButton(
                              icon: AppIcon(
                                isHidden ? Symbols.visibility_off_rounded : Symbols.visibility_rounded,
                                fill: 1,
                                size: 24,
                              ),
                              tooltip: null,
                              onPressed: () => _toggleLibraryVisibility(library, hiddenProvider, librariesProvider),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
        );
  }

  Widget _buildLibrariesSectionTV(
    List<MediaLibrary> allLibraries,
    Set<String> hiddenKeys,
    LibrariesProvider librariesProvider,
    HiddenLibrariesProvider hiddenProvider, {
    FocusNode? sectionHeaderFocusNode,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (allLibraries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              t.discover.noItemsFound,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          _LibraryRowsTV(
            libraries: allLibraries,
            hiddenKeys: hiddenKeys,
            librariesProvider: librariesProvider,
            hiddenProvider: hiddenProvider,
            onScanLibrary: _scanLibrary,
            onRefreshMetadata: _refreshLibraryMetadata,
            onToggleVisibility: _toggleLibraryVisibility,
            getLibraryIcon: _getLibraryIcon,
            sectionHeaderFocusNode: sectionHeaderFocusNode,
          ),
      ],
    );
  }

  List<MediaLibrary> _buildOrderedLibraries(LibrariesProvider provider) {
    final allLibraries = provider.libraries.where((lib) => lib.type != 'livetv').toList();
    final fakeFavorites = MediaLibrary(
      key: kJellyfinFavoritesKey,
      title: t.libraries.tabs.favorites,
      type: 'favorites',
    );

    final orderKeys = provider.displayOrderKeys;
    if (orderKeys != null && orderKeys.isNotEmpty) {
      final libMap = {for (var l in allLibraries) l.globalKey: l};
      final result = <MediaLibrary>[];
      for (final key in orderKeys) {
        if (key == kJellyfinFavoritesKey) {
          result.add(fakeFavorites);
        } else {
          final lib = libMap.remove(key);
          if (lib != null) result.add(lib);
        }
      }
      result.addAll(libMap.values);
      return result;
    }

    final primary = allLibraries
        .where((l) => l.type.toLowerCase() == 'movie' || l.type.toLowerCase() == 'show')
        .toList();
    final secondary = allLibraries
        .where((l) => l.type.toLowerCase() != 'movie' && l.type.toLowerCase() != 'show')
        .toList();
    primary.sort((a, b) => a.title.compareTo(b.title));
    secondary.sort((a, b) => a.title.compareTo(b.title));
    return [...primary, fakeFavorites, ...secondary];
  }

  IconData _getLibraryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Symbols.movie_rounded;
      case 'show':
        return Symbols.tv_rounded;
      case 'favorites':
        return Symbols.favorite_rounded;
      case 'artist':
        return Symbols.music_note_rounded;
      case 'photo':
        return Symbols.photo_rounded;
      default:
        return Symbols.folder_rounded;
    }
  }

  Future<void> _toggleLibraryVisibility(
    MediaLibrary library,
    HiddenLibrariesProvider hiddenProvider,
    LibrariesProvider librariesProvider,
  ) async {
    final isHidden = hiddenProvider.hiddenLibraryKeys.contains(library.globalKey);
    if (isHidden) {
      await hiddenProvider.unhideLibrary(library.globalKey);
    } else {
      await hiddenProvider.hideLibrary(library.globalKey);
    }
  }

  Future<void> _scanLibrary(MediaLibrary library) async {
    try {
      final client = context.getClientForLibrary(library);
      if (mounted) {
        showAppSnackBar(context, t.messages.libraryScanning(title: library.title), duration: const Duration(seconds: 2));
      }
      await client.scanLibrary(library.key);
      if (mounted) {
        showSuccessSnackBar(context, t.messages.libraryScanStarted(title: library.title));
      }
    } catch (e) {
      appLogger.e('Library scan failed', error: e);
      if (mounted) {
        showErrorSnackBar(context, t.messages.libraryScanFailed(error: e.toString()));
      }
    }
  }

  Future<void> _refreshLibraryMetadata(MediaLibrary library) async {
    try {
      final client = context.getClientForLibrary(library);
      if (mounted) {
        showAppSnackBar(context, t.messages.metadataRefreshing(title: library.title), duration: const Duration(seconds: 2));
      }
      await client.refreshLibraryMetadata(library.key);
      if (mounted) {
        showSuccessSnackBar(context, t.messages.metadataRefreshStarted(title: library.title));
      }
    } catch (e) {
      appLogger.e('Metadata refresh failed', error: e);
      if (mounted) {
        showErrorSnackBar(context, t.messages.metadataRefreshFailed(error: e.toString()));
      }
    }
  }

  Widget _buildVideoPlaybackContent() {
    final isMobile = PlatformDetector.isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (Platform.isAndroid)
            ListTile(
              focusNode: _focusTracker.get(_kPlayerBackend),
              leading: const AppIcon(Symbols.play_circle_rounded, fill: 1),
              title: Text(t.settings.playerBackend),
              subtitle: Text(_useExoPlayer ? t.settings.exoPlayerDescription : t.settings.mpvDescription),
              trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
              onTap: () => _showPlayerBackendDialog(),
            ),
          if (Platform.isAndroid)
            ListTile(
              focusNode: _focusTracker.get(_kLiveTvPlayer),
              leading: const AppIcon(Symbols.live_tv_rounded, fill: 1),
              title: Text(t.settings.liveTvPlayer),
              subtitle: Text(_useExoPlayerForLiveTv ? t.settings.exoPlayerDescription : t.settings.mpvDescription),
              trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
              onTap: () => _showLiveTvPlayerDialog(),
            ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kHardwareDecoding),
            secondary: const AppIcon(Symbols.hardware_rounded, fill: 1),
            title: Text(t.settings.hardwareDecoding),
            subtitle: Text(t.settings.hardwareDecodingDescription),
            value: _enableHardwareDecoding,
            onChanged: (value) async {
              setState(() {
                _enableHardwareDecoding = value;
              });
              await _settingsService.setEnableHardwareDecoding(value);
            },
          ),
          if (Platform.isAndroid)
            SwitchListTile(
              focusNode: _focusTracker.get(_kMatchContentFrameRate),
              secondary: const AppIcon(Symbols.display_settings_rounded, fill: 1),
              title: Text(t.settings.matchContentFrameRate),
              subtitle: Text(t.settings.matchContentFrameRateDescription),
              value: _matchContentFrameRate,
              onChanged: (value) async {
                setState(() {
                  _matchContentFrameRate = value;
                });
                await _settingsService.setMatchContentFrameRate(value);
              },
            ),
          ListTile(
            focusNode: _focusTracker.get(_kBufferSize),
            leading: const AppIcon(Symbols.memory_rounded, fill: 1),
            title: Text(t.settings.bufferSize),
            subtitle: Text(t.settings.bufferSizeMB(size: _bufferSize.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showBufferSizeDialog(),
          ),
          ListTile(
            focusNode: _focusTracker.get(_kSubtitleStyling),
            leading: const AppIcon(Symbols.subtitles_rounded, fill: 1),
            title: Text(t.settings.subtitleStyling),
            subtitle: Text(t.settings.subtitleStylingDescription),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SubtitleStylingScreen()));
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kEnableExternalSubtitles),
            secondary: const AppIcon(Symbols.subtitles_rounded, fill: 1),
            title: Text(t.settings.enableExternalSubtitles),
            subtitle: Text(t.settings.enableExternalSubtitlesDescription),
            value: _enableExternalSubtitles,
            onChanged: (value) async {
              setState(() {
                _enableExternalSubtitles = value;
              });
              await _settingsService.setEnableExternalSubtitles(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kEnableTrickplay),
            secondary: const AppIcon(Symbols.view_timeline_rounded, fill: 1),
            title: Text(t.settings.enableTrickplay),
            subtitle: Text(t.settings.enableTrickplayDescription),
            value: _enableTrickplay,
            onChanged: (value) async {
              setState(() {
                _enableTrickplay = value;
              });
              await _settingsService.setEnableTrickplay(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kEnableChapterImages),
            secondary: const AppIcon(Symbols.photo_library_rounded, fill: 1),
            title: Text(t.settings.enableChapterImages),
            subtitle: Text(t.settings.enableChapterImagesDescription),
            value: _enableChapterImages,
            onChanged: (value) async {
              setState(() {
                _enableChapterImages = value;
              });
              await _settingsService.setEnableChapterImages(value);
            },
          ),
          // MPV Config is only available when using MPV player backend
          if (!Platform.isAndroid || !_useExoPlayer || !_useExoPlayerForLiveTv)
            ListTile(
              focusNode: _focusTracker.get(_kMpvConfig),
              leading: const AppIcon(Symbols.tune_rounded, fill: 1),
              title: Text(t.mpvConfig.title),
              subtitle: Text(t.mpvConfig.description),
              trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const MpvConfigScreen()));
              },
            ),
          ListTile(
            focusNode: _focusTracker.get(_kSmallSkipDuration),
            leading: const AppIcon(Symbols.replay_10_rounded, fill: 1),
            title: Text(t.settings.smallSkipDuration),
            subtitle: Text(t.settings.secondsUnit(seconds: _seekTimeSmall.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showSeekTimeSmallDialog(),
          ),
          ListTile(
            focusNode: _focusTracker.get(_kLargeSkipDuration),
            leading: const AppIcon(Symbols.replay_30_rounded, fill: 1),
            title: Text(t.settings.largeSkipDuration),
            subtitle: Text(t.settings.secondsUnit(seconds: _seekTimeLarge.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showSeekTimeLargeDialog(),
          ),
          ListTile(
            focusNode: _focusTracker.get(_kDefaultSleepTimer),
            leading: const AppIcon(Symbols.bedtime_rounded, fill: 1),
            title: Text(t.settings.defaultSleepTimer),
            subtitle: Text(t.settings.minutesUnit(minutes: _sleepTimerDuration.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showSleepTimerDurationDialog(),
          ),
          ListTile(
            focusNode: _focusTracker.get(_kMaxVolume),
            leading: const AppIcon(Symbols.volume_up_rounded, fill: 1),
            title: Text(t.settings.maxVolume),
            subtitle: Text(t.settings.maxVolumePercent(percent: _maxVolume.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showMaxVolumeDialog(),
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kRememberTrackSelections),
            secondary: const AppIcon(Symbols.bookmark_rounded, fill: 1),
            title: Text(t.settings.rememberTrackSelections),
            subtitle: Text(t.settings.rememberTrackSelectionsDescription),
            value: _rememberTrackSelections,
            onChanged: (value) async {
              setState(() {
                _rememberTrackSelections = value;
              });
              await _settingsService.setRememberTrackSelections(value);
            },
          ),
          if (!isMobile)
            SwitchListTile(
              focusNode: _focusTracker.get(_kClickVideoTogglesPlayback),
              secondary: const AppIcon(Symbols.play_pause_rounded, fill: 1),
              title: Text(t.settings.clickVideoTogglesPlayback),
              subtitle: Text(t.settings.clickVideoTogglesPlaybackDescription),
              value: _clickVideoTogglesPlayback,
              onChanged: (value) async {
                setState(() {
                  _clickVideoTogglesPlayback = value;
                });
                await _settingsService.setClickVideoTogglesPlayback(value);
              },
            ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kAutoSkipIntro),
            secondary: const AppIcon(Symbols.fast_forward_rounded, fill: 1),
            title: Text(t.settings.autoSkipIntro),
            subtitle: Text(t.settings.autoSkipIntroDescription),
            value: _autoSkipIntro,
            onChanged: (value) async {
              setState(() => _autoSkipIntro = value);
              await _settingsService.setAutoSkipIntro(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kAutoSkipOutro),
            secondary: const AppIcon(Symbols.skip_next_rounded, fill: 1),
            title: Text(t.settings.autoSkipOutro),
            subtitle: Text(t.settings.autoSkipOutroDescription),
            value: _autoSkipOutro,
            onChanged: (value) async {
              setState(() => _autoSkipOutro = value);
              await _settingsService.setAutoSkipOutro(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kAutoSkipRecap),
            secondary: const AppIcon(Symbols.replay_rounded, fill: 1),
            title: Text(t.settings.autoSkipRecap),
            subtitle: Text(t.settings.autoSkipRecapDescription),
            value: _autoSkipRecap,
            onChanged: (value) async {
              setState(() => _autoSkipRecap = value);
              await _settingsService.setAutoSkipRecap(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kAutoSkipPreview),
            secondary: const AppIcon(Symbols.preview_rounded, fill: 1),
            title: Text(t.settings.autoSkipPreview),
            subtitle: Text(t.settings.autoSkipPreviewDescription),
            value: _autoSkipPreview,
            onChanged: (value) async {
              setState(() => _autoSkipPreview = value);
              await _settingsService.setAutoSkipPreview(value);
            },
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kAutoSkipCommercial),
            secondary: const AppIcon(Symbols.ad_group_rounded, fill: 1),
            title: Text(t.settings.autoSkipCommercial),
            subtitle: Text(t.settings.autoSkipCommercialDescription),
            value: _autoSkipCommercial,
            onChanged: (value) async {
              setState(() => _autoSkipCommercial = value);
              await _settingsService.setAutoSkipCommercial(value);
            },
          ),
          ListTile(
            focusNode: _focusTracker.get(_kAutoSkipDelay),
            leading: const AppIcon(Symbols.timer_rounded, fill: 1),
            title: Text(t.settings.autoSkipDelay),
            subtitle: Text(t.settings.autoSkipDelayDescription(seconds: _autoSkipDelay.toString())),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showAutoSkipDelayDialog(),
          ),
        ],
    );
  }


  Future<void> _showDownloadLocationDialog() async {
    final storageService = DownloadStorageService.instance;
    final isCustom = storageService.isUsingCustomPath();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.settings.downloads),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.settings.downloadLocationDescription),
            const SizedBox(height: 16),
            FutureBuilder<String>(
              future: storageService.getCurrentDownloadPathDisplay(),
              builder: (context, snapshot) {
                return Text(
                  t.settings.currentPath(path: snapshot.data ?? '...'),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              },
            ),
          ],
        ),
        actions: [
          if (isCustom)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _resetDownloadLocation();
              },
              child: Text(t.settings.resetToDefault),
            ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.common.cancel)),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _selectDownloadLocation();
            },
            child: Text(t.settings.selectFolder),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDownloadLocation() async {
    try {
      String? selectedPath;
      String pathType = 'file';

      if (Platform.isAndroid) {
        // Use SAF on Android
        final safService = SafStorageService.instance;
        selectedPath = await safService.pickDirectory();
        if (selectedPath != null) {
          pathType = 'saf';
        }
      } else {
        // Use file_picker on desktop
        final result = await FilePicker.platform.getDirectoryPath(dialogTitle: t.settings.selectFolder);
        selectedPath = result;
      }

      if (selectedPath != null) {
        // Validate the path is writable (for non-SAF paths)
        if (pathType == 'file') {
          final dir = Directory(selectedPath);
          final isWritable = await DownloadStorageService.instance.isDirectoryWritable(dir);
          if (!isWritable) {
            if (mounted) {
              showErrorSnackBar(context, t.settings.downloadLocationInvalid);
            }
            return;
          }
        }

        // Save the setting
        await _settingsService.setCustomDownloadPath(selectedPath, type: pathType);
        await DownloadStorageService.instance.refreshCustomPath();

        if (mounted) {
          // ignore: no-empty-block - setState triggers rebuild to reflect new download path
          setState(() {});
          showSuccessSnackBar(context, t.settings.downloadLocationChanged);
        }
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, t.settings.downloadLocationSelectError);
      }
    }
  }

  Future<void> _resetDownloadLocation() async {
    await _settingsService.setCustomDownloadPath(null);
    await DownloadStorageService.instance.refreshCustomPath();

    if (mounted) {
      // ignore: no-empty-block - setState triggers rebuild to reflect reset path
      setState(() {});
      showAppSnackBar(context, t.settings.downloadLocationReset);
    }
  }

  Widget _buildAdvancedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            return Column(children: _buildPerformanceItems());
          },
        ),
        if (_keyboardShortcutsSupported && _keyboardService != null) ...[
          ListTile(
            focusNode: _focusTracker.get(_kVideoPlayerControls),
            leading: const AppIcon(Symbols.keyboard_rounded, fill: 1),
            title: Text(t.settings.videoPlayerControls),
            subtitle: Text(t.settings.keyboardShortcutsDescription),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showKeyboardShortcutsDialog(),
          ),
          SwitchListTile(
            focusNode: _focusTracker.get(_kVideoPlayerNavigation),
            secondary: const AppIcon(Symbols.gamepad_rounded, fill: 1),
            title: Text(t.settings.videoPlayerNavigation),
            subtitle: Text(t.settings.videoPlayerNavigationDescription),
            value: _videoPlayerNavigationEnabled,
            onChanged: (value) async {
              setState(() {
                _videoPlayerNavigationEnabled = value;
              });
              await _settingsService.setVideoPlayerNavigationEnabled(value);
            },
          ),
        ],
        SwitchListTile(
            focusNode: _focusTracker.get(_kDebugLogging),
            secondary: const AppIcon(Symbols.bug_report_rounded, fill: 1),
            title: Text(t.settings.debugLogging),
            subtitle: Text(t.settings.debugLoggingDescription),
            value: _enableDebugLogging,
            onChanged: (value) async {
              setState(() {
                _enableDebugLogging = value;
              });
              await _settingsService.setEnableDebugLogging(value);
            },
          ),
          ListTile(
            focusNode: _focusTracker.get(_kViewLogs),
            leading: const AppIcon(Symbols.article_rounded, fill: 1),
            title: Text(t.settings.viewLogs),
            subtitle: Text(t.settings.viewLogsDescription),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LogsScreen()));
            },
          ),
          ListTile(
            focusNode: _focusTracker.get(_kClearCache),
            leading: const AppIcon(Symbols.cleaning_services_rounded, fill: 1),
            title: Text(t.settings.clearCache),
            subtitle: Text(t.settings.clearCacheDescription),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showClearCacheDialog(),
          ),
          ListTile(
            focusNode: _focusTracker.get(_kResetSettings),
            leading: const AppIcon(Symbols.restore_rounded, fill: 1),
            title: Text(t.settings.resetSettings),
            subtitle: Text(t.settings.resetSettingsDescription),
            trailing: const AppIcon(Symbols.chevron_right_rounded, fill: 1),
            onTap: () => _showResetSettingsDialog(),
          ),
      ],
    );
  }

  void _showThemeDialog(ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.theme),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: AppIcon(
                  themeProvider.themeMode == settings.ThemeMode.system
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.systemTheme),
                subtitle: Text(t.settings.systemThemeDescription),
                onTap: () {
                  themeProvider.setThemeMode(settings.ThemeMode.system);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: AppIcon(
                  themeProvider.themeMode == settings.ThemeMode.light
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.lightTheme),
                onTap: () {
                  themeProvider.setThemeMode(settings.ThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: AppIcon(
                  themeProvider.themeMode == settings.ThemeMode.dark
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.darkTheme),
                onTap: () {
                  themeProvider.setThemeMode(settings.ThemeMode.dark);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: AppIcon(
                  themeProvider.themeMode == settings.ThemeMode.oled
                      ? Symbols.radio_button_checked_rounded
                      : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.oledTheme),
                subtitle: Text(t.settings.oledThemeDescription),
                onTap: () {
                  themeProvider.setThemeMode(settings.ThemeMode.oled);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
        );
      },
    );
  }

  void _showBufferSizeDialog() {
    final options = [64, 128, 256, 512, 1024];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.bufferSize),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((size) {
              return ListTile(
                leading: AppIcon(
                  _bufferSize == size ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text('${size}MB'),
                onTap: () {
                  setState(() {
                    _bufferSize = size;
                    _settingsService.setBufferSize(size);
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
        );
      },
    );
  }

  /// Generic numeric input dialog to avoid duplication across settings.
  /// On TV, uses a spinner widget with +/- buttons for D-pad navigation.
  /// On other platforms, uses a TextField with focus management.
  void _showNumericInputDialog({
    required String title,
    required String labelText,
    required String suffixText,
    required int min,
    required int max,
    required int currentValue,
    required Future<void> Function(int value) onSave,
  }) {
    final isTV = PlatformDetector.isTV();

    if (isTV) {
      _showNumericInputDialogTV(
        title: title,
        suffixText: suffixText,
        min: min,
        max: max,
        currentValue: currentValue,
        onSave: onSave,
      );
    } else {
      _showNumericInputDialogStandard(
        title: title,
        labelText: labelText,
        suffixText: suffixText,
        min: min,
        max: max,
        currentValue: currentValue,
        onSave: onSave,
      );
    }
  }

  /// TV-specific numeric input dialog with spinner widget.
  void _showNumericInputDialogTV({
    required String title,
    required String suffixText,
    required int min,
    required int max,
    required int currentValue,
    required Future<void> Function(int value) onSave,
  }) {
    int spinnerValue = currentValue;
    final saveFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TvNumberSpinner(
                    value: spinnerValue,
                    min: min,
                    max: max,
                    suffix: suffixText,
                    autofocus: true,
                    onChanged: (value) {
                      setDialogState(() {
                        spinnerValue = value;
                      });
                    },
                    onConfirm: () => saveFocusNode.requestFocus(),
                    onCancel: () => Navigator.pop(dialogContext),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t.settings.durationHint(min: min, max: max),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(t.common.cancel)),
                TextButton(
                  focusNode: saveFocusNode,
                  onPressed: () async {
                    await onSave(spinnerValue);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: Text(t.common.save),
                ),
              ],
            );
          },
        );
      },
    ).then((_) => saveFocusNode.dispose());
  }

  /// Standard numeric input dialog with TextField for non-TV platforms.
  void _showNumericInputDialogStandard({
    required String title,
    required String labelText,
    required String suffixText,
    required int min,
    required int max,
    required int currentValue,
    required Future<void> Function(int value) onSave,
  }) {
    final controller = TextEditingController(text: currentValue.toString());
    String? errorText;
    final cancelFocusNode = FocusNode();
    final saveFocusNode = FocusNode();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: KeyboardListener(
                focusNode: FocusNode(skipTraversal: true),
                onKeyEvent: (event) {
                  if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    cancelFocusNode.requestFocus();
                  }
                },
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: labelText,
                    hintText: t.settings.durationHint(min: min, max: max),
                    errorText: errorText,
                    suffixText: suffixText,
                  ),
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () {
                    saveFocusNode.requestFocus();
                  },
                  onChanged: (value) {
                    final parsed = int.tryParse(value);
                    setDialogState(() {
                      if (parsed == null) {
                        errorText = t.settings.validationErrorEnterNumber;
                      } else if (parsed < min || parsed > max) {
                        errorText = t.settings.validationErrorDuration(min: min, max: max, unit: labelText.toLowerCase());
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  focusNode: cancelFocusNode,
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(t.common.cancel),
                ),
                TextButton(
                  focusNode: saveFocusNode,
                  onPressed: () async {
                    final parsed = int.tryParse(controller.text);
                    if (parsed != null && parsed >= min && parsed <= max) {
                      await onSave(parsed);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    }
                  },
                  child: Text(t.common.save),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      cancelFocusNode.dispose();
      saveFocusNode.dispose();
    });
  }

  void _showSeekTimeSmallDialog() {
    _showNumericInputDialog(
      title: t.settings.smallSkipDuration,
      labelText: t.settings.secondsLabel,
      suffixText: t.settings.secondsShort,
      min: 1,
      max: 120,
      currentValue: _seekTimeSmall,
      onSave: (value) async {
        setState(() {
          _seekTimeSmall = value;
          _settingsService.setSeekTimeSmall(value);
        });
        await _keyboardService?.refreshFromStorage();
      },
    );
  }

  void _showSeekTimeLargeDialog() {
    _showNumericInputDialog(
      title: t.settings.largeSkipDuration,
      labelText: t.settings.secondsLabel,
      suffixText: t.settings.secondsShort,
      min: 1,
      max: 120,
      currentValue: _seekTimeLarge,
      onSave: (value) async {
        setState(() {
          _seekTimeLarge = value;
          _settingsService.setSeekTimeLarge(value);
        });
        await _keyboardService?.refreshFromStorage();
      },
    );
  }

  void _showSleepTimerDurationDialog() {
    _showNumericInputDialog(
      title: t.settings.defaultSleepTimer,
      labelText: t.settings.minutesLabel,
      suffixText: t.settings.minutesShort,
      min: 5,
      max: 240,
      currentValue: _sleepTimerDuration,
      onSave: (value) async {
        setState(() => _sleepTimerDuration = value);
        await _settingsService.setSleepTimerDuration(value);
      },
    );
  }

  void _showAutoSkipDelayDialog() {
    _showNumericInputDialog(
      title: t.settings.autoSkipDelay,
      labelText: t.settings.secondsLabel,
      suffixText: t.settings.secondsShort,
      min: 1,
      max: 30,
      currentValue: _autoSkipDelay,
      onSave: (value) async {
        setState(() => _autoSkipDelay = value);
        await _settingsService.setAutoSkipDelay(value);
      },
    );
  }

  void _showMaxVolumeDialog() {
    _showNumericInputDialog(
      title: t.settings.maxVolume,
      labelText: t.settings.maxVolumeDescription,
      suffixText: '%',
      min: 100,
      max: 300,
      currentValue: _maxVolume,
      onSave: (value) async {
        setState(() => _maxVolume = value);
        await _settingsService.setMaxVolume(value);
      },
    );
  }

  void _showPlayerBackendDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.playerBackend),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: AppIcon(
                  _useExoPlayer ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.exoPlayer),
                subtitle: Text(t.settings.exoPlayerDescription),
                onTap: () async {
                  setState(() {
                    _useExoPlayer = true;
                  });
                  await _settingsService.setUseExoPlayer(true);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: AppIcon(
                  !_useExoPlayer ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.mpv),
                subtitle: Text(t.settings.mpvDescription),
                onTap: () async {
                  setState(() {
                    _useExoPlayer = false;
                  });
                  await _settingsService.setUseExoPlayer(false);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
        );
      },
    );
  }

  void _showLiveTvPlayerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.liveTvPlayer),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  t.settings.liveTvPlayerDescription,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
              ListTile(
                leading: AppIcon(
                  !_useExoPlayerForLiveTv ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.liveTvMpv),
                subtitle: Text(t.settings.mpvDescription),
                onTap: () async {
                  setState(() {
                    _useExoPlayerForLiveTv = false;
                  });
                  await _settingsService.setUseExoPlayerForLiveTv(false);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              ListTile(
                leading: AppIcon(
                  _useExoPlayerForLiveTv ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                ),
                title: Text(t.settings.liveTvExoPlayer),
                subtitle: Text(t.settings.exoPlayerDescription),
                onTap: () async {
                  setState(() {
                    _useExoPlayerForLiveTv = true;
                  });
                  await _settingsService.setUseExoPlayerForLiveTv(true);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
        );
      },
    );
  }

  void _showKeyboardShortcutsDialog() {
    if (_keyboardService == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => _KeyboardShortcutsScreen(keyboardService: _keyboardService!)),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.clearCache),
          content: Text(t.settings.clearCacheDescription),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel)),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _settingsService.clearCache();
                if (mounted) {
                  navigator.pop();
                  showSuccessSnackBar(this.context, t.settings.clearCacheSuccess);
                }
              },
              child: Text(t.common.clear),
            ),
          ],
        );
      },
    );
  }

  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.resetSettings),
          content: Text(t.settings.resetSettingsDescription),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel)),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final settingsProvider = context.read<SettingsProvider>();
                await _settingsService.resetAllSettings();
                await _keyboardService?.resetToDefaults();
                if (!mounted) return;
                await settingsProvider.refresh();
                navigator.pop();
                // ignore: use_build_context_synchronously - guarded by mounted check
                showSuccessSnackBar(this.context, t.settings.resetSettingsSuccess);
                _loadSettings();
              },
              child: Text(t.common.reset),
            ),
          ],
        );
      },
    );
  }

  String _getLanguageDisplayName(AppLocale locale) {
    switch (locale) {
      case AppLocale.en:
        return 'English';
      case AppLocale.sv:
        return 'Svenska';
      case AppLocale.fr:
        return 'Français';
      case AppLocale.it:
        return 'Italiano';
      case AppLocale.nl:
        return 'Nederlands';
      case AppLocale.de:
        return 'Deutsch';
      case AppLocale.zh:
        return '中文';
      case AppLocale.ko:
        return '한국어';
      case AppLocale.es:
        return 'Español';
    }
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t.settings.language),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLocale.values.map((locale) {
              final isSelected = LocaleSettings.currentLocale == locale;
              return ListTile(
                title: Text(_getLanguageDisplayName(locale)),
                leading: AppIcon(
                  isSelected ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  fill: 1,
                  color: isSelected ? Theme.of(context).colorScheme.primary : null,
                ),
                tileColor: isSelected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                onTap: () async {
                  // Save the locale to settings
                  await _settingsService.setAppLocale(locale);

                  // Set the locale immediately
                  LocaleSettings.setLocale(locale);

                  // Close dialog
                  if (context.mounted) {
                    Navigator.pop(context);
                  }

                  // Trigger app-wide rebuild by restarting the app
                  if (context.mounted) {
                    _restartApp();
                  }
                },
              );
            }).toList(),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
        );
      },
    );
  }

  void _restartApp() {
    // Navigate to the root and remove all previous routes
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  /// Generic option selection dialog for settings with SettingsProvider
  void _showOptionSelectionDialog<T>({
    required String title,
    required List<_DialogOption<T>> options,
    required T Function(SettingsProvider) getCurrentValue,
    required Future<void> Function(T value, SettingsProvider provider) onSelect,
  }) {
    final settingsProvider = context.read<SettingsProvider>();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Consumer<SettingsProvider>(
          builder: (context, provider, child) {
            final currentValue = getCurrentValue(provider);
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: options.map((option) {
                  return ListTile(
                    leading: AppIcon(
                      currentValue == option.value
                          ? Symbols.radio_button_checked_rounded
                          : Symbols.radio_button_unchecked_rounded,
                      fill: 1,
                    ),
                    title: Text(option.title),
                    subtitle: option.subtitle != null ? Text(option.subtitle!) : null,
                    onTap: () async {
                      await onSelect(option.value, settingsProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
            );
          },
        );
      },
    );
  }

  void _showLibraryDensityDialog() {
    _showOptionSelectionDialog<settings.LibraryDensity>(
      title: t.settings.libraryDensity,
      options: [
        _DialogOption(
          value: settings.LibraryDensity.compact,
          title: t.settings.compact,
          subtitle: t.settings.compactDescription,
        ),
        _DialogOption(
          value: settings.LibraryDensity.normal,
          title: t.settings.normal,
          subtitle: t.settings.normalDescription,
        ),
        _DialogOption(
          value: settings.LibraryDensity.comfortable,
          title: t.settings.comfortable,
          subtitle: t.settings.comfortableDescription,
        ),
      ],
      getCurrentValue: (p) => p.libraryDensity,
      onSelect: (value, provider) => provider.setLibraryDensity(value),
    );
  }

  void _showViewModeDialog() {
    _showOptionSelectionDialog<settings.ViewMode>(
      title: t.settings.viewMode,
      options: [
        _DialogOption(
          value: settings.ViewMode.grid,
          title: t.settings.gridView,
          subtitle: t.settings.gridViewDescription,
        ),
        _DialogOption(
          value: settings.ViewMode.list,
          title: t.settings.listView,
          subtitle: t.settings.listViewDescription,
        ),
      ],
      getCurrentValue: (p) => p.viewMode,
      onSelect: (value, provider) => provider.setViewMode(value),
    );
  }

  void _showEpisodePosterModeDialog() {
    _showOptionSelectionDialog<settings.EpisodePosterMode>(
      title: t.settings.episodePosterMode,
      options: [
        _DialogOption(
          value: settings.EpisodePosterMode.seriesPoster,
          title: t.settings.seriesPoster,
          subtitle: t.settings.seriesPosterDescription,
        ),
        _DialogOption(
          value: settings.EpisodePosterMode.seasonPoster,
          title: t.settings.seasonPoster,
          subtitle: t.settings.seasonPosterDescription,
        ),
        _DialogOption(
          value: settings.EpisodePosterMode.episodeThumbnail,
          title: t.settings.episodeThumbnail,
          subtitle: t.settings.episodeThumbnailDescription,
        ),
      ],
      getCurrentValue: (p) => p.episodePosterMode,
      onSelect: (value, provider) => provider.setEpisodePosterMode(value),
    );
  }

  void _showTimeFormatDialog() {
    _showOptionSelectionDialog<settings.TimeFormat>(
      title: t.settings.timeFormat,
      options: [
        _DialogOption(
          value: settings.TimeFormat.twelveHour,
          title: t.settings.twelveHour,
          subtitle: t.settings.twelveHourDescription,
        ),
        _DialogOption(
          value: settings.TimeFormat.twentyFourHour,
          title: t.settings.twentyFourHour,
          subtitle: t.settings.twentyFourHourDescription,
        ),
      ],
      getCurrentValue: (p) => p.timeFormat,
      onSelect: (value, provider) => provider.setTimeFormat(value),
    );
  }
}

class _KeyboardShortcutsScreen extends StatefulWidget {
  final KeyboardShortcutsService keyboardService;

  const _KeyboardShortcutsScreen({required this.keyboardService});

  @override
  State<_KeyboardShortcutsScreen> createState() => _KeyboardShortcutsScreenState();
}

class _KeyboardShortcutsScreenState extends State<_KeyboardShortcutsScreen> {
  Map<String, HotKey> _hotkeys = {};
  bool _isLoading = true;
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadHotkeys();
  }

  void _focusFirstItem() {
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

  Future<void> _loadHotkeys() async {
    await widget.keyboardService.refreshFromStorage();
    if (!mounted) return;
    setState(() {
      _hotkeys = widget.keyboardService.hotkeys;
      _isLoading = false;
    });
    _focusFirstItem();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return FocusedScrollScaffold(
        title: Text(t.settings.keyboardShortcuts),
        slivers: const [SliverFillRemaining(child: Center(child: CircularProgressIndicator()))],
      );
    }

    return FocusedScrollScaffold(
      title: Text(t.settings.keyboardShortcuts),
      actions: [
        TextButton(
          onPressed: () async {
            await widget.keyboardService.resetToDefaults();
            await _loadHotkeys();
            if (mounted) {
              showSuccessSnackBar(this.context, t.settings.shortcutsReset);
            }
          },
          child: Text(t.common.reset),
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            key: _contentKey,
            delegate: SliverChildBuilderDelegate((context, index) {
              final actions = _hotkeys.keys.toList();
              final action = actions[index];
              final hotkey = _hotkeys[action]!;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(widget.keyboardService.getActionDisplayName(action)),
                  subtitle: Text(action),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.fromBorderSide(BorderSide(color: Theme.of(context).dividerColor)),
                      borderRadius: const BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Text(
                      widget.keyboardService.formatHotkey(hotkey),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  onTap: () => _editHotkey(action, hotkey),
                ),
              );
            }, childCount: _hotkeys.length),
          ),
        ),
      ],
    );
  }

  void _editHotkey(String action, HotKey currentHotkey) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return HotKeyRecorderWidget(
          actionName: widget.keyboardService.getActionDisplayName(action),
          currentHotKey: currentHotkey,
          onHotKeyRecorded: (newHotkey) async {
            final navigator = Navigator.of(context);

            // Check for conflicts
            final existingAction = widget.keyboardService.getActionForHotkey(newHotkey);
            if (existingAction != null && existingAction != action) {
              navigator.pop();
              showErrorSnackBar(
                context,
                t.settings.shortcutAlreadyAssigned(action: widget.keyboardService.getActionDisplayName(existingAction)),
              );
              return;
            }

            // Save the new hotkey
            await widget.keyboardService.setHotkey(action, newHotkey);

            if (mounted) {
              // Update UI directly instead of reloading from storage
              setState(() {
                _hotkeys[action] = newHotkey;
              });

              navigator.pop();

              showSuccessSnackBar(
                this.context,
                t.settings.shortcutUpdated(action: widget.keyboardService.getActionDisplayName(action)),
              );
            }
          },
          onCancel: () => Navigator.pop(context),
        );
      },
    );
  }
}

/// TV-only library list: up/down moves between rows only; left = reorder, right = scan/refresh/visibility.
class _LibraryRowsTV extends StatefulWidget {
  final List<MediaLibrary> libraries;
  final Set<String> hiddenKeys;
  final LibrariesProvider librariesProvider;
  final HiddenLibrariesProvider hiddenProvider;
  final Future<void> Function(MediaLibrary) onScanLibrary;
  final Future<void> Function(MediaLibrary) onRefreshMetadata;
  final Future<void> Function(MediaLibrary, HiddenLibrariesProvider, LibrariesProvider) onToggleVisibility;
  final IconData Function(String) getLibraryIcon;
  final FocusNode? sectionHeaderFocusNode;

  const _LibraryRowsTV({
    required this.libraries,
    required this.hiddenKeys,
    required this.librariesProvider,
    required this.hiddenProvider,
    required this.onScanLibrary,
    required this.onRefreshMetadata,
    required this.onToggleVisibility,
    required this.getLibraryIcon,
    this.sectionHeaderFocusNode,
  });

  @override
  State<_LibraryRowsTV> createState() => _LibraryRowsTVState();
}

class _LibraryRowsTVState extends State<_LibraryRowsTV> {
  final List<FocusNode> _centerFocusNodes = [];
  final List<FocusNode> _reorderUpFocusNodes = [];
  final List<FocusNode> _reorderDownFocusNodes = [];
  final List<FocusNode> _scanFocusNodes = [];
  final List<FocusNode> _refreshFocusNodes = [];
  final List<FocusNode> _visibilityFocusNodes = [];

  @override
  void initState() {
    super.initState();
    _ensureFocusNodes(widget.libraries.length);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
    // Scroll focused row into view when navigating with D-pad
    for (var i = 0; i < _centerFocusNodes.length; i++) {
      FocusNode? focused;
      if (_centerFocusNodes[i].hasFocus) {
        focused = _centerFocusNodes[i];
      } else if (_reorderUpFocusNodes[i].hasFocus) {
        focused = _reorderUpFocusNodes[i];
      } else if (_reorderDownFocusNodes[i].hasFocus) {
        focused = _reorderDownFocusNodes[i];
      } else if (_scanFocusNodes[i].hasFocus) {
        focused = _scanFocusNodes[i];
      } else if (_refreshFocusNodes[i].hasFocus) {
        focused = _refreshFocusNodes[i];
      } else if (_visibilityFocusNodes[i].hasFocus) {
        focused = _visibilityFocusNodes[i];
      }
      if (focused != null) {
        final ctx = focused.context;
        if (ctx != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final disableAnimations = context.read<SettingsProvider>().disableAnimations;
            Scrollable.ensureVisible(ctx, alignment: 0.5, duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200));
          });
        }
        break;
      }
    }
  }

  @override
  void didUpdateWidget(covariant _LibraryRowsTV oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureFocusNodes(widget.libraries.length);
  }

  void _ensureFocusNodes(int count) {
    while (_centerFocusNodes.length < count) {
      final i = _centerFocusNodes.length;
      final centerNode = FocusNode(debugLabel: 'LibraryRowCenter$i');
      centerNode.addListener(_onFocusChange);
      _centerFocusNodes.add(centerNode);

      final upNode = FocusNode(debugLabel: 'LibraryRowReorderUp$i');
      upNode.skipTraversal = true;
      upNode.addListener(_onFocusChange);
      _reorderUpFocusNodes.add(upNode);

      final downNode = FocusNode(debugLabel: 'LibraryRowReorderDown$i');
      downNode.skipTraversal = true;
      downNode.addListener(_onFocusChange);
      _reorderDownFocusNodes.add(downNode);

      final scanNode = FocusNode(debugLabel: 'LibraryRowScan$i');
      scanNode.skipTraversal = true;
      scanNode.addListener(_onFocusChange);
      _scanFocusNodes.add(scanNode);

      final refreshNode = FocusNode(debugLabel: 'LibraryRowRefresh$i');
      refreshNode.skipTraversal = true;
      refreshNode.addListener(_onFocusChange);
      _refreshFocusNodes.add(refreshNode);

      final visibilityNode = FocusNode(debugLabel: 'LibraryRowVisibility$i');
      visibilityNode.skipTraversal = true;
      visibilityNode.addListener(_onFocusChange);
      _visibilityFocusNodes.add(visibilityNode);
    }
    if (_centerFocusNodes.length > count) {
      for (var i = count; i < _centerFocusNodes.length; i++) {
        _centerFocusNodes[i].removeListener(_onFocusChange);
        _reorderUpFocusNodes[i].removeListener(_onFocusChange);
        _reorderDownFocusNodes[i].removeListener(_onFocusChange);
        _scanFocusNodes[i].removeListener(_onFocusChange);
        _refreshFocusNodes[i].removeListener(_onFocusChange);
        _visibilityFocusNodes[i].removeListener(_onFocusChange);
        _centerFocusNodes[i].dispose();
        _reorderUpFocusNodes[i].dispose();
        _reorderDownFocusNodes[i].dispose();
        _scanFocusNodes[i].dispose();
        _refreshFocusNodes[i].dispose();
        _visibilityFocusNodes[i].dispose();
      }
      _centerFocusNodes.length = count;
      _reorderUpFocusNodes.length = count;
      _reorderDownFocusNodes.length = count;
      _scanFocusNodes.length = count;
      _refreshFocusNodes.length = count;
      _visibilityFocusNodes.length = count;
    }
  }

  @override
  void dispose() {
    for (final node in _centerFocusNodes) {
      node.dispose();
    }
    for (final node in _reorderUpFocusNodes) {
      node.dispose();
    }
    for (final node in _reorderDownFocusNodes) {
      node.dispose();
    }
    for (final node in _scanFocusNodes) {
      node.dispose();
    }
    for (final node in _refreshFocusNodes) {
      node.dispose();
    }
    for (final node in _visibilityFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _moveLibrary(int fromIndex, int toIndex) {
    if (toIndex < 0 || toIndex >= widget.libraries.length || fromIndex == toIndex) return;
    final reordered = List<MediaLibrary>.from(widget.libraries);
    final item = reordered.removeAt(fromIndex);
    reordered.insert(toIndex, item);
    widget.librariesProvider.updateLibraryOrder(reordered);
  }

  KeyEventResult _handleCenterKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key.isUpKey) {
      if (index > 0) {
        _centerFocusNodes[index - 1].requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      if (index < widget.libraries.length - 1) {
        _centerFocusNodes[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    if (key.isLeftKey) {
      _reorderDownFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      final isFavorites = widget.libraries[index].globalKey == kJellyfinFavoritesKey;
      (isFavorites ? _visibilityFocusNodes[index] : _scanFocusNodes[index]).requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleReorderUpKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key.isSelectKey) {
      if (index > 0) _moveLibrary(index, index - 1);
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      if (index > 0) {
        final prev = widget.libraries[index - 1];
        final isPrevFavorites = prev.globalKey == kJellyfinFavoritesKey;
        (isPrevFavorites ? _centerFocusNodes[index - 1] : _visibilityFocusNodes[index - 1]).requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _reorderDownFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      if (index < widget.libraries.length - 1) {
        _reorderUpFocusNodes[index + 1].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      if (index > 0) {
        _reorderUpFocusNodes[index - 1].requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleReorderDownKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key.isSelectKey) {
      if (index < widget.libraries.length - 1) _moveLibrary(index, index + 1);
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      _reorderUpFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _centerFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      if (index > 0) {
        _reorderDownFocusNodes[index - 1].requestFocus();
      } else {
        _reorderUpFocusNodes[index].requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isDownKey) {
      if (index < widget.libraries.length - 1) {
        _reorderDownFocusNodes[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleScanKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key.isSelectKey) {
      widget.onScanLibrary(widget.libraries[index]);
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      _centerFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _refreshFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      if (index > 0) {
        final prevIsFavorites = widget.libraries[index - 1].globalKey == kJellyfinFavoritesKey;
        (prevIsFavorites ? _visibilityFocusNodes[index - 1] : _scanFocusNodes[index - 1]).requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isDownKey && index < widget.libraries.length - 1) {
      final nextIsFavorites = widget.libraries[index + 1].globalKey == kJellyfinFavoritesKey;
      (nextIsFavorites ? _visibilityFocusNodes[index + 1] : _scanFocusNodes[index + 1]).requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleRefreshKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key.isSelectKey) {
      widget.onRefreshMetadata(widget.libraries[index]);
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      _scanFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _visibilityFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      if (index > 0) {
        final prevIsFavorites = widget.libraries[index - 1].globalKey == kJellyfinFavoritesKey;
        (prevIsFavorites ? _visibilityFocusNodes[index - 1] : _refreshFocusNodes[index - 1]).requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isDownKey && index < widget.libraries.length - 1) {
      final nextIsFavorites = widget.libraries[index + 1].globalKey == kJellyfinFavoritesKey;
      (nextIsFavorites ? _visibilityFocusNodes[index + 1] : _refreshFocusNodes[index + 1]).requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _handleVisibilityKey(FocusNode node, KeyEvent event, int index) {
    if (!event.isActionable) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final isFavorites = widget.libraries[index].globalKey == kJellyfinFavoritesKey;

    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space || key.isSelectKey) {
      widget.onToggleVisibility(widget.libraries[index], widget.hiddenProvider, widget.librariesProvider);
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      (isFavorites ? _centerFocusNodes[index] : _refreshFocusNodes[index]).requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isRightKey) {
      _centerFocusNodes[index].requestFocus();
      return KeyEventResult.handled;
    }
    if (key.isUpKey) {
      if (index > 0) {
        _visibilityFocusNodes[index - 1].requestFocus();
      } else if (widget.sectionHeaderFocusNode != null) {
        widget.sectionHeaderFocusNode!.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (key.isDownKey && index < widget.libraries.length - 1) {
      _visibilityFocusNodes[index + 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: List.generate(widget.libraries.length, (index) {
        final library = widget.libraries[index];
        final isFavorites = library.globalKey == kJellyfinFavoritesKey;
        final isHidden = widget.hiddenKeys.contains(library.globalKey);
        final showFocus = InputModeTracker.isKeyboardMode(context);

        return Padding(
          key: ValueKey(library.globalKey),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              Focus(
                focusNode: _reorderUpFocusNodes[index],
                onKeyEvent: (n, e) => _handleReorderUpKey(n, e, index),
                child: Builder(
                  builder: (_) {
                    final hasFocus = _reorderUpFocusNodes[index].hasFocus;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                      child: Icon(
                        Icons.arrow_upward,
                        size: 24,
                        color: index > 0 ? null : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 4),
              Focus(
                focusNode: _reorderDownFocusNodes[index],
                onKeyEvent: (n, e) => _handleReorderDownKey(n, e, index),
                child: Builder(
                  builder: (_) {
                    final hasFocus = _reorderDownFocusNodes[index].hasFocus;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                      child: Icon(
                        Icons.arrow_downward,
                        size: 24,
                        color: index < widget.libraries.length - 1 ? null : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Focus(
                  focusNode: _centerFocusNodes[index],
                  onKeyEvent: (n, e) => _handleCenterKey(n, e, index),
                  child: Builder(
                    builder: (_) {
                      final hasFocus = _centerFocusNodes[index].hasFocus;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                        child: Row(
                          children: [
                            AppIcon(widget.getLibraryIcon(library.type), fill: 1, size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                library.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: isHidden ? theme.colorScheme.onSurfaceVariant : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!isFavorites) ...[
                Focus(
                  focusNode: _scanFocusNodes[index],
                  onKeyEvent: (n, e) => _handleScanKey(n, e, index),
                  child: Builder(
                    builder: (_) {
                      final hasFocus = _scanFocusNodes[index].hasFocus;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                        child: const AppIcon(Symbols.refresh_rounded, fill: 1, size: 24),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Focus(
                  focusNode: _refreshFocusNodes[index],
                  onKeyEvent: (n, e) => _handleRefreshKey(n, e, index),
                  child: Builder(
                    builder: (_) {
                      final hasFocus = _refreshFocusNodes[index].hasFocus;
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                        child: const AppIcon(Symbols.sync_rounded, fill: 1, size: 24),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Focus(
                focusNode: _visibilityFocusNodes[index],
                onKeyEvent: (n, e) => _handleVisibilityKey(n, e, index),
                child: Builder(
                  builder: (_) {
                    final hasFocus = _visibilityFocusNodes[index].hasFocus;
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: FocusTheme.focusDecoration(context, isFocused: showFocus && hasFocus),
                      child: AppIcon(
                        isHidden ? Symbols.visibility_off_rounded : Symbols.visibility_rounded,
                        fill: 1,
                        size: 24,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// Dialog for selecting PerformanceProfile (Small / Medium / Large).
class _PerformanceProfileDialog extends StatelessWidget {
  final String title;
  final settings.PerformanceProfile value;
  final void Function(settings.PerformanceProfile) onSelected;

  const _PerformanceProfileDialog({
    required this.title,
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: settings.PerformanceProfile.values.map((v) {
          return ListTile(
            leading: AppIcon(
              value == v ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
              fill: 1,
            ),
            title: Text(v == settings.PerformanceProfile.small
                ? t.settings.performanceSmall
                : v == settings.PerformanceProfile.medium
                    ? t.settings.performanceMedium
                    : t.settings.performanceLarge),
            onTap: () => onSelected(v),
          );
        }).toList(),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
    );
  }
}

/// Dialog for selecting GridPreloadLevel (Low / Medium / High).
class _SettingsSectionPage extends StatefulWidget {
  final String title;
  final Widget Function() content;
  final ValueNotifier<int>? rebuildNotifier;
  final FocusNode? firstFocusNode;

  const _SettingsSectionPage({
    required this.title,
    required this.content,
    this.rebuildNotifier,
    this.firstFocusNode,
  });

  @override
  State<_SettingsSectionPage> createState() => _SettingsSectionPageState();
}

class _SettingsSectionPageState extends State<_SettingsSectionPage> {
  final _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.rebuildNotifier?.addListener(_onParentStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Only auto-focus first item when using keyboard/dpad (not touchscreen)
      if (!InputModeTracker.isKeyboardMode(context)) return;
      if (widget.firstFocusNode != null) {
        widget.firstFocusNode!.requestFocus();
      } else {
        // Fallback: find first focusable within content (skip app bar back button)
        final contentContext = _contentKey.currentContext;
        if (contentContext != null) {
          FocusUtils.focusFirstInSubtree(contentContext);
        }
      }
    });
  }

  @override
  void dispose() {
    widget.rebuildNotifier?.removeListener(_onParentStateChanged);
    super.dispose();
  }

  void _onParentStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FocusedScrollScaffold(
      title: Text(widget.title),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Card(key: _contentKey, child: widget.content()),
            ]),
          ),
        ),
      ],
    );
  }
}

class _GridPreloadDialog extends StatelessWidget {
  final settings.GridPreloadLevel value;
  final void Function(settings.GridPreloadLevel) onSelected;

  const _GridPreloadDialog({
    required this.value,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.settings.performanceGridPreload),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: settings.GridPreloadLevel.values.map((v) {
          return ListTile(
            leading: AppIcon(
              value == v ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
              fill: 1,
            ),
            title: Text(v == settings.GridPreloadLevel.low
                ? t.settings.performanceLow
                : v == settings.GridPreloadLevel.medium
                    ? t.settings.performanceMedium
                    : t.settings.performanceHigh),
            onTap: () => onSelected(v),
          );
        }).toList(),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.common.cancel))],
    );
  }
}
