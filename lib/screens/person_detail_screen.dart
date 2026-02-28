import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../i18n/strings.g.dart';
import '../models/cast_role.dart';
import '../models/media_metadata.dart';
import '../services/jellyfin_client.dart';
import '../utils/app_logger.dart';
import '../widgets/app_bar_back_button.dart';
import '../widgets/collapsible_text.dart';
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

  @override
  void initState() {
    super.initState();
    _loadPersonData();
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
    } catch (e) {
      appLogger.e('Failed to load person data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final personId = widget.actor.tagKey ?? widget.actor.thumb ?? '';
    final imageUrl = personId.isNotEmpty ? widget.client.getPersonImageUrl(personId) : '';
    final isWide = screenWidth >= 600;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 56, left: 24, right: 24, bottom: 8),
                    child: isWide
                        ? _buildWideHeader(imageUrl)
                        : _buildNarrowHeader(imageUrl),
                  ),
                ),
              ),

              // Loading or content
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else ...[
                // Filmography
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_filmography.isNotEmpty) ...[
                          Text(
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

          const Positioned(
            top: 0,
            left: 0,
            child: AppBarBackButton(style: BackButtonStyle.circular),
          ),
        ],
      ),
    );
  }

  /// Wide layout (>= 600px): portrait photo on left, name + details on right
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
              if (!_isLoading && _overview != null && _overview!.isNotEmpty) ...[
                const SizedBox(height: 12),
                CollapsibleText(
                  text: _overview!,
                  maxLines: 6,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
              if (!_isLoading && _hasInfoRows) ...[
                const SizedBox(height: 16),
                ..._buildInfoRows(theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Narrow layout (< 600px): centered portrait photo, name below
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
        if (_overview != null && _overview!.isNotEmpty && !_isLoading) ...[
          const SizedBox(height: 12),
          CollapsibleText(
            text: _overview!,
            maxLines: 6,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
        if (!_isLoading && _hasInfoRows) ...[
          const SizedBox(height: 16),
          ..._buildInfoRows(theme),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  bool get _hasInfoRows =>
      _birthDate != null || _deathDate != null || (_birthPlace != null && _birthPlace!.isNotEmpty);

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

  Widget _buildFilmographySection() {
    final cardWidth = _getResponsiveCardWidth();
    final posterHeight = (cardWidth - 16) * 1.5;
    final containerHeight = posterHeight + 66;

    return SizedBox(
      height: containerHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 0),
        itemCount: _filmography.length,
        itemBuilder: (context, index) {
          final item = _filmography[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: MediaCard(
              item: item,
              width: cardWidth,
              height: posterHeight,
              forceGridMode: true,
            ),
          );
        },
      ),
    );
  }
}
