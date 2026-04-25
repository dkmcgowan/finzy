import 'dart:io';

import 'package:flutter/material.dart';
import 'package:finzy/widgets/app_icon.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:provider/provider.dart';

import '../../../models/shader_preset.dart';
import '../../../theme/mono_tokens.dart';
import '../../../mpv/mpv.dart';
import '../../../providers/shader_provider.dart';
import '../../../services/settings_service.dart';
import '../../../services/shader_service.dart';
import '../../../services/sleep_timer_service.dart';
import '../../../utils/formatters.dart';
import '../../../utils/platform_detector.dart';
import '../../../widgets/focusable_list_tile.dart';
import '../../../widgets/overlay_sheet.dart';
import '../widgets/sync_offset_control.dart';
import '../widgets/sleep_timer_content.dart';
import '../../../i18n/strings.g.dart';
import '../../../widgets/scroll_to_index_list_view.dart';
import 'base_video_control_sheet.dart';

enum _SettingsView { menu, speed, quality, sleep, audioSync, subtitleSync, audioDevice, shader, liveTvQuality }

/// Reusable menu item widget for settings sheet
class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String valueText;
  final VoidCallback onTap;
  final bool isHighlighted;
  final bool allowValueOverflow;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.valueText,
    required this.onTap,
    this.isHighlighted = false,
    this.allowValueOverflow = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueWidget = Text(
      valueText,
      style: TextStyle(color: isHighlighted ? kBrandAccent : Colors.white70, fontSize: 14),
      overflow: allowValueOverflow ? TextOverflow.ellipsis : null,
    );

    return FocusableListTile(
      leading: AppIcon(icon, fill: 1, color: isHighlighted ? kBrandAccent : Colors.white70),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowValueOverflow) Flexible(child: valueWidget) else valueWidget,
          const SizedBox(width: 8),
          const AppIcon(Symbols.chevron_right_rounded, fill: 1, color: Colors.white70),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// Unified settings sheet for playback adjustments with in-sheet navigation
class VideoSettingsSheet extends StatefulWidget {
  final Player player;
  final int audioSyncOffset;
  final int subtitleSyncOffset;

  /// Whether the user can control playback (false hides speed option in host-only mode).
  final bool canControl;

  /// Whether this is a live TV stream (hides speed settings).
  final bool isLive;

  /// Optional shader service for MPV shader control
  final ShaderService? shaderService;

  /// Called when shader preset changes
  final VoidCallback? onShaderChanged;

  /// Whether ambient lighting is currently enabled
  final bool isAmbientLightingEnabled;

  /// Called to toggle ambient lighting on/off (null if unsupported)
  final VoidCallback? onToggleAmbientLighting;

  /// Called when streaming quality changes (VOD) or Live TV quality changes; caller should restart playback.
  /// Passes previous values for revert-on-failure.
  final void Function({PlaybackMode? previousPlaybackMode, int? previousLiveTvBitrate})? onQualityChanged;

  const VideoSettingsSheet({
    super.key,
    required this.player,
    required this.audioSyncOffset,
    required this.subtitleSyncOffset,
    this.canControl = true,
    this.isLive = false,
    this.shaderService,
    this.onShaderChanged,
    this.isAmbientLightingEnabled = false,
    this.onToggleAmbientLighting,
    this.onQualityChanged,
  });

  @override
  State<VideoSettingsSheet> createState() => _VideoSettingsSheetState();
}

class _VideoSettingsSheetState extends State<VideoSettingsSheet> {
  _SettingsView _currentView = _SettingsView.menu;
  late int _audioSyncOffset;
  late int _subtitleSyncOffset;
  bool _enableHDR = true;
  bool _showPerformanceOverlay = false;
  bool _autoPlayNextEpisode = true;
  Future<PlaybackMode>? _cachedQualityFuture;
  Future<int?>? _cachedLiveTvQualityFuture;

  @override
  void initState() {
    super.initState();
    _audioSyncOffset = widget.audioSyncOffset;
    _subtitleSyncOffset = widget.subtitleSyncOffset;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.getInstance();
    if (!mounted) return;
    setState(() {
      _enableHDR = settings.getEnableHDR();
      _showPerformanceOverlay = settings.getShowPerformanceOverlay();
      _autoPlayNextEpisode = settings.getAutoPlayNextEpisode();
    });
  }

  Future<void> _toggleHDR() async {
    final newValue = !_enableHDR;
    final settings = await SettingsService.getInstance();
    await settings.setEnableHDR(newValue);
    if (!mounted) return;
    setState(() {
      _enableHDR = newValue;
    });
    // Apply to player immediately
    await widget.player.setProperty('hdr-enabled', newValue ? 'yes' : 'no');
  }

  Future<void> _togglePerformanceOverlay() async {
    final newValue = !_showPerformanceOverlay;
    final settings = await SettingsService.getInstance();
    await settings.setShowPerformanceOverlay(newValue);
    if (!mounted) return;
    setState(() {
      _showPerformanceOverlay = newValue;
    });
  }

  Future<void> _toggleAutoPlayNextEpisode() async {
    final newValue = !_autoPlayNextEpisode;
    final settings = await SettingsService.getInstance();
    await settings.setAutoPlayNextEpisode(newValue);
    if (!mounted) return;
    setState(() {
      _autoPlayNextEpisode = newValue;
    });
  }

  void _navigateTo(_SettingsView view) {
    setState(() {
      _currentView = view;
    });
    OverlaySheetController.maybeOf(context)?.refocus();
  }

  void _navigateBack() {
    setState(() {
      _currentView = _SettingsView.menu;
    });
    OverlaySheetController.maybeOf(context)?.refocus();
  }

  String _qualityLabel(PlaybackMode mode) => switch (mode) {
        PlaybackMode.auto => t.settings.playbackModeAutoDirect,
        PlaybackMode.directPlay => t.settings.playbackModeDirectPlay,
        PlaybackMode.transcode15 => t.settings.quality15Mbps,
        PlaybackMode.transcode10 => t.settings.quality10Mbps,
        PlaybackMode.transcode8 => t.settings.quality8Mbps,
        PlaybackMode.transcode6 => t.settings.quality6Mbps,
        PlaybackMode.transcode4 => t.settings.quality4Mbps,
        PlaybackMode.transcode3 => t.settings.quality3Mbps,
        PlaybackMode.transcode1_5 => t.settings.quality1_5Mbps,
        PlaybackMode.transcode720k => t.settings.quality720kbps,
        PlaybackMode.transcode420k => t.settings.quality420kbps,
      };

  String _getTitle() {
    switch (_currentView) {
      case _SettingsView.menu:
        return t.videoSettings.playbackSettings;
      case _SettingsView.speed:
        return t.videoSettings.playbackSpeed;
      case _SettingsView.quality:
        return t.videoSettings.quality;
      case _SettingsView.liveTvQuality:
        return t.videoSettings.quality;
      case _SettingsView.sleep:
        return t.videoSettings.sleepTimer;
      case _SettingsView.audioSync:
        return t.videoSettings.audioSync;
      case _SettingsView.subtitleSync:
        return t.videoSettings.subtitleSync;
      case _SettingsView.audioDevice:
        return t.videoSettings.audioOutput;
      case _SettingsView.shader:
        return t.shaders.title;
    }
  }

  IconData _getIcon() {
    switch (_currentView) {
      case _SettingsView.menu:
        return Symbols.tune_rounded;
      case _SettingsView.speed:
        return Symbols.speed_rounded;
      case _SettingsView.quality:
      case _SettingsView.liveTvQuality:
        return Symbols.high_quality_rounded;
      case _SettingsView.sleep:
        return Symbols.bedtime_rounded;
      case _SettingsView.audioSync:
        return Symbols.sync_rounded;
      case _SettingsView.subtitleSync:
        return Symbols.subtitles_rounded;
      case _SettingsView.audioDevice:
        return Symbols.speaker_rounded;
      case _SettingsView.shader:
        return Symbols.auto_fix_high_rounded;
    }
  }

  String _formatSpeed(double speed) {
    if (speed == 1.0) return 'Normal';
    return '${speed.toStringAsFixed(2)}x';
  }

  String _formatSleepTimer(SleepTimerService sleepTimer) {
    if (!sleepTimer.isActive) return 'Off';
    final remaining = sleepTimer.remainingTime;
    if (remaining == null) return 'Off';
    return 'Active (${formatDurationWithSeconds(remaining)})';
  }

  Widget _buildMenuView() {
    final sleepTimer = SleepTimerService();
    final isDesktop = PlatformDetector.isDesktop(context);

    return ListView(
      children: [
        // Quality - streaming quality (Auto, Direct Play, or transcode tiers) for VOD
        if (!widget.isLive)
          FutureBuilder<PlaybackMode>(
            future: SettingsService.getInstance().then((s) => s.getPlaybackMode()),
            builder: (context, snapshot) {
              final label = snapshot.hasData ? _qualityLabel(snapshot.data!) : '...';
              return _SettingsMenuItem(
                icon: Symbols.high_quality_rounded,
                title: t.videoSettings.quality,
                valueText: label,
                onTap: () => _navigateTo(_SettingsView.quality),
              );
            },
          ),

        // Live TV Quality - only when watching Live TV
        if (widget.isLive)
          FutureBuilder<int?>(
            future: SettingsService.getInstance().then((s) => s.getLiveTvMaxStreamingBitrate()),
            builder: (context, snapshot) {
              final bitrate = snapshot.data;
              final label = bitrate == null
                  ? t.settings.playbackModeAutoDirect
                  : switch (bitrate) {
                      15000000 => t.settings.quality15Mbps,
                      10000000 => t.settings.quality10Mbps,
                      8000000 => t.settings.quality8Mbps,
                      6000000 => t.settings.quality6Mbps,
                      4000000 => t.settings.quality4Mbps,
                      3000000 => t.settings.quality3Mbps,
                      1500000 => t.settings.quality1_5Mbps,
                      720000 => t.settings.quality720kbps,
                      420000 => t.settings.quality420kbps,
                      _ => t.settings.liveTvQualityNone,
                    };
              return _SettingsMenuItem(
                icon: Symbols.high_quality_rounded,
                title: t.videoSettings.quality,
                valueText: label,
                onTap: () => _navigateTo(_SettingsView.liveTvQuality),
              );
            },
          ),

        // Playback Speed - hidden for live TV and when user cannot control playback
        if (widget.canControl && !widget.isLive)
          StreamBuilder<double>(
            stream: widget.player.streams.rate,
            initialData: widget.player.state.rate,
            builder: (context, snapshot) {
              final currentRate = snapshot.data ?? 1.0;
              return _SettingsMenuItem(
                icon: Symbols.speed_rounded,
                title: t.videoSettings.playbackSpeed,
                valueText: _formatSpeed(currentRate),
                onTap: () => _navigateTo(_SettingsView.speed),
              );
            },
          ),

        // Sleep Timer
        ListenableBuilder(
          listenable: sleepTimer,
          builder: (context, _) {
            final isActive = sleepTimer.isActive;
            return _SettingsMenuItem(
              icon: Symbols.bedtime_rounded,
              title: t.videoSettings.sleepTimer,
              valueText: _formatSleepTimer(sleepTimer),
              isHighlighted: isActive,
              onTap: () => _navigateTo(_SettingsView.sleep),
            );
          },
        ),

        // Audio Sync
        _SettingsMenuItem(
          icon: Symbols.sync_rounded,
          title: t.videoSettings.audioSync,
          valueText: formatSyncOffset(_audioSyncOffset.toDouble()),
          isHighlighted: _audioSyncOffset != 0,
          onTap: () => _navigateTo(_SettingsView.audioSync),
        ),

        // Subtitle Sync
        _SettingsMenuItem(
          icon: Symbols.subtitles_rounded,
          title: t.videoSettings.subtitleSync,
          valueText: formatSyncOffset(_subtitleSyncOffset.toDouble()),
          isHighlighted: _subtitleSyncOffset != 0,
          onTap: () => _navigateTo(_SettingsView.subtitleSync),
        ),

        // HDR Toggle (iOS, macOS, and Windows)
        if (Platform.isIOS || Platform.isMacOS || Platform.isWindows)
          ListTile(
            leading: AppIcon(Symbols.hdr_strong_rounded, fill: 1, color: _enableHDR ? kBrandAccent : Colors.white70),
            title: Text(t.videoSettings.hdr, style: const TextStyle(color: Colors.white)),
            trailing: Switch(value: _enableHDR, onChanged: (_) => _toggleHDR(), activeThumbColor: kBrandAccent),
            onTap: _toggleHDR,
          ),

        // Auto-Play Next Episode Toggle
        ListTile(
          leading: AppIcon(
            Symbols.skip_next_rounded,
            fill: 1,
            color: _autoPlayNextEpisode ? kBrandAccent : Colors.white70,
          ),
          title: Text(t.videoControls.autoPlayNext, style: const TextStyle(color: Colors.white)),
          trailing: Switch(
            value: _autoPlayNextEpisode,
            onChanged: (_) => _toggleAutoPlayNextEpisode(),
            activeThumbColor: kBrandAccent,
          ),
          onTap: _toggleAutoPlayNextEpisode,
        ),

        // Audio Output Device (Desktop only)
        if (isDesktop)
          StreamBuilder<AudioDevice>(
            stream: widget.player.streams.audioDevice,
            initialData: widget.player.state.audioDevice,
            builder: (context, snapshot) {
              final currentDevice = snapshot.data ?? widget.player.state.audioDevice;
              final deviceLabel = currentDevice.description.isEmpty
                  ? currentDevice.name
                  : currentDevice.description;

              return _SettingsMenuItem(
                icon: Symbols.speaker_rounded,
                title: t.videoSettings.audioOutput,
                valueText: deviceLabel,
                allowValueOverflow: true,
                onTap: () => _navigateTo(_SettingsView.audioDevice),
              );
            },
          ),

        // Shader Preset (MPV only)
        if (widget.shaderService != null && widget.shaderService!.isSupported)
          _SettingsMenuItem(
            icon: Symbols.auto_fix_high_rounded,
            title: t.shaders.title,
            valueText: widget.shaderService!.currentPreset.name,
            isHighlighted: widget.shaderService!.currentPreset.isEnabled,
            onTap: () => _navigateTo(_SettingsView.shader),
          ),

        // Ambient Lighting (MPV only)
        if (widget.onToggleAmbientLighting != null)
          ListTile(
            leading: AppIcon(
              Symbols.blur_on,
              fill: 1,
              color: widget.isAmbientLightingEnabled ? kBrandAccent : Colors.white70,
            ),
            title: Text(t.videoControls.ambientLighting, style: const TextStyle(color: Colors.white)),
            trailing: Switch(
              value: widget.isAmbientLightingEnabled,
              onChanged: (_) {
                widget.onToggleAmbientLighting?.call();
                OverlaySheetController.of(context).close();
              },
              activeThumbColor: kBrandAccent,
            ),
            onTap: () {
              widget.onToggleAmbientLighting?.call();
              OverlaySheetController.of(context).close();
            },
          ),

        // Performance Overlay Toggle
        ListTile(
          leading: AppIcon(
            Symbols.analytics_rounded,
            fill: 1,
            color: _showPerformanceOverlay ? kBrandAccent : Colors.white70,
          ),
          title: Text(t.videoSettings.performanceOverlay, style: const TextStyle(color: Colors.white)),
          trailing: Switch(
            value: _showPerformanceOverlay,
            onChanged: (_) => _togglePerformanceOverlay(),
            activeThumbColor: kBrandAccent,
          ),
          onTap: _togglePerformanceOverlay,
        ),
      ],
    );
  }

  Widget _buildQualityView() {
    _cachedQualityFuture ??= SettingsService.getInstance().then((s) => s.getPlaybackMode());
    return FutureBuilder<PlaybackMode>(
      future: _cachedQualityFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }
        final currentMode = snapshot.data!;
        final modes = [
          PlaybackMode.auto,
          PlaybackMode.directPlay,
          PlaybackMode.transcode15,
          PlaybackMode.transcode10,
          PlaybackMode.transcode8,
          PlaybackMode.transcode6,
          PlaybackMode.transcode4,
          PlaybackMode.transcode3,
          PlaybackMode.transcode1_5,
          PlaybackMode.transcode720k,
          PlaybackMode.transcode420k,
        ];
        final selectedIndex = modes.indexOf(currentMode);
        if (selectedIndex < 0) return const SizedBox.shrink();
        return ScrollToIndexListView(
          itemCount: modes.length,
          initialIndex: selectedIndex,
          itemBuilder: (context, index) {
            final mode = modes[index];
            final isSelected = currentMode == mode;
            return FocusableListTile(
              key: ValueKey(mode),
              title: Text(_qualityLabel(mode), style: TextStyle(color: isSelected ? kBrandAccent : Colors.white)),
              trailing: isSelected ? const AppIcon(Symbols.check_rounded, fill: 1, color: kBrandAccent) : null,
              onTap: () async {
                final settings = await SettingsService.getInstance();
                await settings.setPlaybackMode(mode);
                widget.onQualityChanged?.call(previousPlaybackMode: currentMode);
                if (context.mounted) OverlaySheetController.of(context).close();
              },
            );
          },
        );
      },
    );
  }

  static const List<int?> _liveTvQualityBitrates = [
    null,
    15000000,
    10000000,
    8000000,
    6000000,
    4000000,
    3000000,
    1500000,
    720000,
    420000,
  ];

  String _liveTvQualityLabel(int? bitrate) {
    if (bitrate == null) return t.settings.playbackModeAutoDirect;
    return switch (bitrate) {
      15000000 => t.settings.quality15Mbps,
      10000000 => t.settings.quality10Mbps,
      8000000 => t.settings.quality8Mbps,
      6000000 => t.settings.quality6Mbps,
      4000000 => t.settings.quality4Mbps,
      3000000 => t.settings.quality3Mbps,
      1500000 => t.settings.quality1_5Mbps,
      720000 => t.settings.quality720kbps,
      420000 => t.settings.quality420kbps,
      _ => t.settings.liveTvQualityNone,
    };
  }

  Widget _buildLiveTvQualityView() {
    _cachedLiveTvQualityFuture ??= SettingsService.getInstance().then((s) => s.getLiveTvMaxStreamingBitrate());
    return FutureBuilder<int?>(
      future: _cachedLiveTvQualityFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.white70));
        }
        final currentBitrate = snapshot.data;
        final bitrates = _liveTvQualityBitrates;
        final selectedIndex = bitrates.indexOf(currentBitrate);
        final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
        return ScrollToIndexListView(
          itemCount: bitrates.length,
          initialIndex: safeIndex,
          itemBuilder: (context, index) {
            final bitrate = bitrates[index];
            final isSelected = bitrate == currentBitrate;
            return FocusableListTile(
              key: ValueKey(bitrate),
              title: Text(_liveTvQualityLabel(bitrate), style: TextStyle(color: isSelected ? kBrandAccent : Colors.white)),
              trailing: isSelected ? const AppIcon(Symbols.check_rounded, fill: 1, color: kBrandAccent) : null,
              onTap: () async {
                final settings = await SettingsService.getInstance();
                await settings.setLiveTvMaxStreamingBitrate(bitrate);
                widget.onQualityChanged?.call(previousLiveTvBitrate: currentBitrate);
                if (context.mounted) OverlaySheetController.of(context).close();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSpeedView() {
    return StreamBuilder<double>(
      stream: widget.player.streams.rate,
      initialData: widget.player.state.rate,
      builder: (context, snapshot) {
        final currentRate = snapshot.data ?? 1.0;
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0];
        final selectedIndex = speeds.indexWhere((s) => (currentRate - s).abs() < 0.01);
        final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;

        return ScrollToIndexListView(
          itemCount: speeds.length,
          initialIndex: safeIndex,
          itemBuilder: (context, index) {
            final speed = speeds[index];
            final isSelected = (currentRate - speed).abs() < 0.01;
            final label = speed == 1.0 ? 'Normal' : '${speed.toStringAsFixed(2)}x';

            return FocusableListTile(
              title: Text(label, style: TextStyle(color: isSelected ? kBrandAccent : Colors.white)),
              trailing: isSelected ? const AppIcon(Symbols.check_rounded, fill: 1, color: kBrandAccent) : null,
              onTap: () async {
                widget.player.setRate(speed);
                // Save as default playback speed
                final settings = await SettingsService.getInstance();
                await settings.setDefaultPlaybackSpeed(speed);
                if (context.mounted) {
                  OverlaySheetController.of(context).close(); // Close sheet after selection
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSleepView() {
    final sleepTimer = SleepTimerService();

    return SleepTimerContent(player: widget.player, sleepTimer: sleepTimer, onCancel: () => OverlaySheetController.of(context).close());
  }

  Widget _buildAudioSyncView() {
    return SyncOffsetControl(
      player: widget.player,
      propertyName: 'audio-delay',
      initialOffset: _audioSyncOffset,
      labelText: t.videoControls.audioLabel,
      onOffsetChanged: (offset) async {
        final settings = await SettingsService.getInstance();
        await settings.setAudioSyncOffset(offset);
        if (!mounted) return;
        setState(() {
          _audioSyncOffset = offset;
        });
      },
    );
  }

  Widget _buildSubtitleSyncView() {
    return SyncOffsetControl(
      player: widget.player,
      propertyName: 'sub-delay',
      initialOffset: _subtitleSyncOffset,
      labelText: t.videoControls.subtitlesLabel,
      onOffsetChanged: (offset) async {
        final settings = await SettingsService.getInstance();
        await settings.setSubtitleSyncOffset(offset);
        if (!mounted) return;
        setState(() {
          _subtitleSyncOffset = offset;
        });
      },
    );
  }

  /// Extract the audio backend name from a device name (e.g. "coreaudio" from "coreaudio/BuiltIn").
  static String _audioBackend(String name) {
    final slash = name.indexOf('/');
    return slash > 0 ? name.substring(0, slash) : name;
  }

  /// Pretty-print a backend identifier.
  static String _formatBackend(String backend) {
    const labels = {
      'coreaudio': 'CoreAudio',
      'avfoundation': 'AVFoundation',
      'wasapi': 'WASAPI',
      'pulse': 'PulseAudio',
      'pipewire': 'PipeWire',
      'alsa': 'ALSA',
      'jack': 'JACK',
      'oss': 'OSS',
    };
    return labels[backend] ?? backend;
  }

  Widget _buildAudioDeviceView() {
    return StreamBuilder<List<AudioDevice>>(
      stream: widget.player.streams.audioDevices,
      initialData: widget.player.state.audioDevices,
      builder: (context, snapshot) {
        final devices = snapshot.data ?? [];

        return StreamBuilder<AudioDevice>(
          stream: widget.player.streams.audioDevice,
          initialData: widget.player.state.audioDevice,
          builder: (context, selectedSnapshot) {
            final currentDevice = selectedSnapshot.data ?? widget.player.state.audioDevice;

            // Check for duplicate descriptions (same physical device across multiple backends).
            final descCounts = <String, int>{};
            for (final d in devices) {
              final desc = d.description.isEmpty ? d.name : d.description;
              descCounts[desc] = (descCounts[desc] ?? 0) + 1;
            }
            final hasDuplicates = descCounts.values.any((c) => c > 1);

            if (!hasDuplicates) {
              return _buildFlatDeviceList(devices, currentDevice);
            }

            // Group devices by backend, keeping "auto" at the top ungrouped.
            final ungrouped = <AudioDevice>[];
            final groups = <String, List<AudioDevice>>{};
            for (final d in devices) {
              final backend = _audioBackend(d.name);
              if (!d.name.contains('/')) {
                ungrouped.add(d);
              } else {
                (groups[backend] ??= []).add(d);
              }
            }

            return ListView(
              children: [
                for (final d in ungrouped) _buildDeviceTile(d, currentDevice),
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      _formatBackend(entry.key),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final d in entry.value) _buildDeviceTile(d, currentDevice),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFlatDeviceList(List<AudioDevice> devices, AudioDevice currentDevice) {
    final selectedIndex = devices.indexWhere((d) => d.name == currentDevice.name);
    final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;
    return ScrollToIndexListView(
      itemCount: devices.length,
      initialIndex: safeIndex,
      itemBuilder: (context, index) => _buildDeviceTile(devices[index], currentDevice),
    );
  }

  Widget _buildDeviceTile(AudioDevice device, AudioDevice currentDevice) {
    final isSelected = device.name == currentDevice.name;
    final label = device.description.isEmpty ? device.name : device.description;

    return FocusableListTile(
      title: Text(label, style: TextStyle(color: isSelected ? kBrandAccent : Colors.white)),
      trailing: isSelected ? const AppIcon(Symbols.check_rounded, fill: 1, color: kBrandAccent) : null,
      onTap: () {
        widget.player.setAudioDevice(device);
        OverlaySheetController.of(context).close();
      },
    );
  }

  Widget _buildShaderView() {
    if (widget.shaderService == null) return const SizedBox.shrink();

    return Consumer<ShaderProvider>(
      builder: (context, shaderProvider, _) {
        final currentPreset = widget.shaderService!.currentPreset;
        final presets = ShaderPreset.allPresets;
        final selectedIndex = presets.indexWhere((p) => p.id == currentPreset.id);
        final safeIndex = selectedIndex >= 0 ? selectedIndex : 0;

        return ScrollToIndexListView(
          itemCount: presets.length,
          initialIndex: safeIndex,
          itemExtent: 72.0,
          itemBuilder: (context, index) {
            final preset = presets[index];
            final isSelected = preset.id == currentPreset.id;

            return FocusableListTile(
              title: Text(preset.name, style: TextStyle(color: isSelected ? kBrandAccent : Colors.white)),
              subtitle: _getShaderSubtitle(preset) != null
                  ? Text(_getShaderSubtitle(preset)!, style: const TextStyle(color: Colors.white54, fontSize: 12))
                  : null,
              trailing: isSelected ? const AppIcon(Symbols.check_rounded, fill: 1, color: kBrandAccent) : null,
              onTap: () async {
                await widget.shaderService!.applyPreset(preset);
                await shaderProvider.setPreset(preset);
                widget.onShaderChanged?.call();
                if (context.mounted) OverlaySheetController.of(context).close();
              },
            );
          },
        );
      },
    );
  }

  String? _getShaderSubtitle(ShaderPreset preset) {
    switch (preset.type) {
      case ShaderPresetType.none:
        return t.shaders.noShaderDescription;
      case ShaderPresetType.nvscaler:
        return t.shaders.nvscalerDescription;
      case ShaderPresetType.anime4k:
        if (preset.anime4kConfig != null) {
          final quality = preset.anime4kConfig!.quality == Anime4KQuality.fast
              ? t.shaders.qualityFast
              : t.shaders.qualityHQ;
          final mode = preset.modeDisplayName;
          return '$quality - ${t.shaders.mode} $mode';
        }
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sleepTimer = SleepTimerService();
    final isShaderActive = widget.shaderService != null && widget.shaderService!.currentPreset.isEnabled;
    final isIconActive =
        _currentView == _SettingsView.menu &&
        (sleepTimer.isActive || _audioSyncOffset != 0 || _subtitleSyncOffset != 0 || isShaderActive);

    return BaseVideoControlSheet(
      title: _getTitle(),
      icon: _getIcon(),
      iconColor: () {
        if (isIconActive) return kBrandAccent;
        if (_currentView == _SettingsView.shader && isShaderActive) return kBrandAccent;
        return Colors.white;
      }(),
      onBack: _currentView != _SettingsView.menu ? _navigateBack : null,
      child: () {
        switch (_currentView) {
          case _SettingsView.menu:
            return _buildMenuView();
          case _SettingsView.speed:
            return _buildSpeedView();
          case _SettingsView.quality:
            return _buildQualityView();
          case _SettingsView.liveTvQuality:
            return _buildLiveTvQualityView();
          case _SettingsView.sleep:
            return _buildSleepView();
          case _SettingsView.audioSync:
            return _buildAudioSyncView();
          case _SettingsView.subtitleSync:
            return _buildSubtitleSyncView();
          case _SettingsView.audioDevice:
            return _buildAudioDeviceView();
          case _SettingsView.shader:
            return _buildShaderView();
        }
      }(),
    );
  }
}
