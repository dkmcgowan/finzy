import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../focus/dpad_navigator.dart';
import '../providers/settings_provider.dart';
import '../focus/input_mode_tracker.dart';
import '../focus/key_event_utils.dart';
import '../i18n/strings.g.dart';
import '../models/cast_role.dart';
import '../models/media_metadata.dart';
import '../services/jellyfin_client.dart';
import '../utils/app_logger.dart';
import '../utils/platform_detector.dart';
import '../utils/scroll_utils.dart';
import '../widgets/app_bar_back_button.dart';
import '../widgets/collapsible_text.dart';
import '../widgets/focus_builders.dart';
import '../widgets/horizontal_scroll_with_arrows.dart';
import '../widgets/media_card.dart';
import '../widgets/placeholder_container.dart';

class PersonDetailScreen extends StatefulWidget {
  final CastRole actor;
  final JellyfinClient client;
  final String serverId;

  const PersonDetailScreen({
    super.key,
    required this.actor,
    required this.client,
    required this.serverId,
  });

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  String? _overview;
  String? _birthDate;
  String? _deathDate;
  String? _birthPlace;
  List<MediaMetadata> _filmography = [];
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  late final FocusNode _rootFocusNode;
  late final FocusNode _backButtonFocusNode;
  late final FocusNode _bioFocusNode;
  late final FocusNode _filmographyFocusNode;
  final ScrollController _filmographyScrollController = ScrollController();
  int _focusedFilmographyIndex = 0;
  final Map<int, GlobalKey<MediaCardState>> _filmCardKeys = {};

  final _bioSectionKey = GlobalKey();
  final _filmographySectionKey = GlobalKey();

  bool _sawBackKeyDown = false;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode(debugLabel: 'person_root');
    _backButtonFocusNode = FocusNode(debugLabel: 'person_back');
    _bioFocusNode = FocusNode(debugLabel: 'person_bio');
    _filmographyFocusNode = FocusNode(debugLabel: 'person_filmography');
    _loadPersonData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _rootFocusNode.dispose();
    _backButtonFocusNode.dispose();
    _bioFocusNode.dispose();
    _filmographyFocusNode.dispose();
    _filmographyScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonData() async {
    try {
      final personId = widget.actor.tagKey ?? widget.actor.thumb ?? '';
      final results = await Future.wait([
        widget.client.getPersonDetails(personId),
        widget.client.getItemsByPerson(personId),
      ]);

      if (!mounted) return;

      final personDetails = results[0] as Map<String, dynamic>?;
      final items = results[1] as List<MediaMetadata>;

      setState(() {
        _overview = personDetails?['overview'] as String?;
        _birthDate = personDetails?['birthDate'] as String?;
        _deathDate = personDetails?['deathDate'] as String?;
        _birthPlace = personDetails?['birthPlace'] as String?;
        _filmography = items.map((item) {
          if (item.serverId == null) {
            return item.copyWith(serverId: widget.serverId);
          }
          return item;
        }).toList();
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && InputModeTracker.isKeyboardMode(context)) {
          _rootFocusNode.requestFocus();
        }
      });
    } catch (e) {
      appLogger.e('Failed to load person data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  bool get _hasBioContent =>
      (_overview != null && _overview!.isNotEmpty) || _hasInfoRows;

  bool get _hasInfoRows =>
      _birthDate != null || _deathDate != null || (_birthPlace != null && _birthPlace!.isNotEmpty);

  // ── Key event handlers ──

  KeyEventResult _handleRootKeyEvent(FocusNode node, KeyEvent event) {
    if (_rootFocusNode.hasPrimaryFocus) {
      if (!event.isActionable) return KeyEventResult.ignored;
      final key = event.logicalKey;
      if (key.isDownKey) {
        _focusFirstContent();
        return KeyEventResult.handled;
      }
      if (key.isUpKey) {
        _backButtonFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (key.isLeftKey || key.isRightKey || key.isSelectKey) {
        return KeyEventResult.handled;
      }
    }

    if (!event.logicalKey.isBackKey) return KeyEventResult.ignored;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return KeyEventResult.ignored;

    if (BackKeyUpSuppressor.consumeIfSuppressed(event)) {
      return KeyEventResult.handled;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      _sawBackKeyDown = true;
      return KeyEventResult.handled;
    }

    if (event is KeyUpEvent) {
      if (!_sawBackKeyDown) return KeyEventResult.handled;
      _sawBackKeyDown = false;
      BackKeyCoordinator.markHandled();
      BackKeyUpSuppressor.markClosedViaBackKey();
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleBackButtonKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!event.isActionable) return KeyEventResult.ignored;

    if (key.isUpKey || key.isRightKey) {
      return KeyEventResult.handled;
    }
    if (key.isLeftKey) {
      if (event is KeyUpEvent) {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      _focusFirstContent();
      return KeyEventResult.handled;
    }

    if (key.isSelectKey) {
      Navigator.pop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleBioKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (!event.isActionable) return KeyEventResult.ignored;

    if (key.isUpKey) {
      if (context.read<SettingsProvider>().disableAnimations) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
      _backButtonFocusNode.requestFocus();
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      if (_filmography.isNotEmpty) {
        _filmographyFocusNode.requestFocus();
        _scrollSectionIntoView(_filmographySectionKey);
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  KeyEventResult _handleFilmographyKeyEvent(FocusNode _, KeyEvent event) {
    final key = event.logicalKey;
    if (key.isBackKey) return KeyEventResult.ignored;

    if (key.isSelectKey) {
      if (event is KeyDownEvent && _focusedFilmographyIndex < _filmography.length) {
        _filmCardKeys[_focusedFilmographyIndex]?.currentState?.handleTap();
      }
      return KeyEventResult.handled;
    }

    if (!event.isActionable) return KeyEventResult.ignored;

    final disableAnims = context.read<SettingsProvider>().disableAnimations;

    if (key.isLeftKey) {
      if (_focusedFilmographyIndex > 0) {
        setState(() => _focusedFilmographyIndex--);
        scrollListToIndex(_filmographyScrollController, _focusedFilmographyIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    if (key.isRightKey) {
      if (_focusedFilmographyIndex < _filmography.length - 1) {
        setState(() => _focusedFilmographyIndex++);
        scrollListToIndex(_filmographyScrollController, _focusedFilmographyIndex, itemExtent: _getResponsiveCardWidth() + 4, disableAnimations: disableAnims);
      }
      return KeyEventResult.handled;
    }

    if (key.isUpKey) {
      if (_hasBioContent) {
        _bioFocusNode.requestFocus();
        _scrollSectionIntoView(_bioSectionKey);
      } else {
        if (disableAnims) {
          _scrollController.jumpTo(0);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
        _backButtonFocusNode.requestFocus();
      }
      return KeyEventResult.handled;
    }

    if (key.isDownKey) {
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _focusFirstContent() {
    if (_hasBioContent && !_isLoading) {
      _bioFocusNode.requestFocus();
      _scrollSectionIntoView(_bioSectionKey);
    } else if (_filmography.isNotEmpty) {
      _filmographyFocusNode.requestFocus();
      _scrollSectionIntoView(_filmographySectionKey);
    }
  }

  void _scrollSectionIntoView(GlobalKey key) {
    final disableAnimations = context.read<SettingsProvider>().disableAnimations;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  // ── Helpers ──

  String? _formatDate(String? isoDate) {
    if (isoDate == null) return null;
    try {
      final date = DateTime.parse(isoDate);
      return '${date.month}/${date.day}/${date.year}';
    } catch (_) {
      return null;
    }
  }

  int? _calculateAge(String? birthDateStr, String? deathDateStr) {
    if (birthDateStr == null) return null;
    try {
      final birth = DateTime.parse(birthDateStr);
      final end = deathDateStr != null ? DateTime.parse(deathDateStr) : DateTime.now();
      var age = end.year - birth.year;
      if (end.month < birth.month || (end.month == birth.month && end.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  double _getResponsiveCardWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1400) return 220.0;
    if (screenWidth >= 900) return 200.0;
    if (screenWidth >= 700) return 190.0;
    return 160.0;
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final personId = widget.actor.tagKey ?? widget.actor.thumb ?? '';
    final imageUrl = personId.isNotEmpty ? widget.client.getPersonImageUrl(personId) : '';
    final isWide = screenWidth >= 600;
    final isPhone = PlatformDetector.isPhone(context);

    return Focus(
      focusNode: _rootFocusNode,
      onKeyEvent: _handleRootKeyEvent,
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 56, left: 24, right: 24, bottom: 8),
                          child: isWide
                              ? _buildWideHeader(imageUrl)
                              : _buildNarrowHeader(imageUrl),
                        ),
                      ),
                      if (!isPhone)
                        Positioned(
                          top: 0,
                          left: 0,
                          child: FocusableAppBarBackButton(
                            focusNode: _backButtonFocusNode,
                            onKeyEvent: _handleBackButtonKeyEvent,
                            onPressed: () => Navigator.pop(context),
                            useDarkBase: true,
                          ),
                        ),
                    ],
                  ),
                ),

                if (_isLoading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else ...[
                  // Bio section (overview + info rows) as one focusable block
                  if (_hasBioContent)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _buildBioSection(isWide),
                      ),
                    ),

                  // Filmography
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_filmography.isNotEmpty) ...[
                            Text(
                              key: _filmographySectionKey,
                              t.discover.moviesAndShows,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildFilmographySection(),
                            const SizedBox(height: 24),
                          ] else ...[
                            const SizedBox(height: 16),
                            Text(
                              t.discover.noItemsFound,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            // Floating back button on mobile: stays visible when scrolling
            if (isPhone)
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: FocusableAppBarBackButton(
                    focusNode: _backButtonFocusNode,
                    onKeyEvent: _handleBackButtonKeyEvent,
                    onPressed: () => Navigator.pop(context),
                    useDarkBase: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Bio section (focusable block with overview + info rows) ──

  Widget _buildBioSection(bool isWide) {
    return Focus(
      focusNode: _bioFocusNode,
      onKeyEvent: _handleBioKeyEvent,
      child: ListenableBuilder(
        listenable: _bioFocusNode,
        builder: (context, _) {
          final focused = _bioFocusNode.hasFocus && InputModeTracker.isKeyboardMode(context);
          final theme = Theme.of(context);

          return Container(
            key: _bioSectionKey,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: focused
                  ? Border.all(color: theme.colorScheme.primary, width: 2)
                  : null,
              color: focused
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_overview != null && _overview!.isNotEmpty) ...[
                  Text(
                    t.discover.overview,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  CollapsibleText(
                    text: _overview!,
                    maxLines: focused ? 100 : 6,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                ],
                if (_hasInfoRows) ...[
                  if (_overview != null && _overview!.isNotEmpty) const SizedBox(height: 16),
                  ..._buildInfoRows(theme),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Header layouts ──

  Widget _buildWideHeader(String imageUrl) {
    final theme = Theme.of(context);
    const imageWidth = 180.0;
    const imageHeight = imageWidth * 1.5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: imageWidth,
            height: imageHeight,
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, loadingProgress) => const PlaceholderContainer(),
                    errorWidget: (context, error, stackTrace) => const PlaceholderContainer(),
                  )
                : const PlaceholderContainer(),
          ),
        ),
        const SizedBox(width: 24),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                widget.actor.tag,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowHeader(String imageUrl) {
    final theme = Theme.of(context);
    const imageWidth = 150.0;
    const imageHeight = imageWidth * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: imageWidth,
              height: imageHeight,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, loadingProgress) => const PlaceholderContainer(),
                      errorWidget: (context, error, stackTrace) => const PlaceholderContainer(),
                    )
                  : const PlaceholderContainer(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.actor.tag,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Info rows ──

  List<Widget> _buildInfoRows(ThemeData theme) {
    final rows = <Widget>[];
    final formattedBirth = _formatDate(_birthDate);
    final age = _calculateAge(_birthDate, _deathDate);

    if (formattedBirth != null) {
      final ageStr = age != null ? ' ($age years)' : '';
      rows.add(_inlineLabel('Born:', '$formattedBirth$ageStr', theme));
    }
    if (_deathDate != null) {
      final formattedDeath = _formatDate(_deathDate);
      final deathAge = _calculateAge(_birthDate, _deathDate);
      final ageStr = deathAge != null ? ' ($deathAge years)' : '';
      if (formattedDeath != null) {
        rows.add(_inlineLabel('Died:', '$formattedDeath$ageStr', theme));
      }
    }
    if (_birthPlace != null && _birthPlace!.isNotEmpty) {
      rows.add(_inlineLabel('Birth place:', _birthPlace!, theme));
    }

    return rows;
  }

  Widget _inlineLabel(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Filmography (locked focus horizontal row) ──

  Widget _buildFilmographySection() {
    final cardWidth = _getResponsiveCardWidth();
    final posterHeight = (cardWidth - 16) * 1.5;
    final containerHeight = posterHeight + 66;

    return Focus(
      focusNode: _filmographyFocusNode,
      onKeyEvent: _handleFilmographyKeyEvent,
      child: ListenableBuilder(
        listenable: _filmographyFocusNode,
        builder: (context, _) {
          final hasFocus = _filmographyFocusNode.hasFocus;
          return SizedBox(
            height: containerHeight,
            child: HorizontalScrollWithArrows(
              controller: _filmographyScrollController,
              builder: (scrollController) => ListView.builder(
                controller: scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
                itemCount: _filmography.length,
                itemBuilder: (context, index) {
                  final item = _filmography[index];
                  final isFocused = hasFocus && index == _focusedFilmographyIndex;
                  final cardKey = _filmCardKeys.putIfAbsent(index, () => GlobalKey<MediaCardState>());

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FocusBuilders.buildLockedFocusWrapper(
                      context: context,
                      isFocused: isFocused,
                      onTap: () => cardKey.currentState?.handleTap(),
                      child: MediaCard(
                        key: cardKey,
                        item: item,
                        width: cardWidth,
                        height: posterHeight,
                        forceGridMode: true,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
