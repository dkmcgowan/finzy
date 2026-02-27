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
  List<MediaMetadata> _filmography = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPersonData();
  }

  Future<void> _loadPersonData() async {
    try {
      final results = await Future.wait([
        widget.client.getPersonDetails(widget.actor.tag),
        widget.client.getItemsByPerson(widget.actor.tagKey ?? widget.actor.thumb ?? ''),
      ]);

      if (!mounted) return;

      final personDetails = results[0] as Map<String, dynamic>?;
      final items = results[1] as List<MediaMetadata>;

      setState(() {
        _overview = personDetails?['overview'] as String?;
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

  double _getResponsiveCardWidth() {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 1400) return 220.0;
    if (screenWidth >= 900) return 200.0;
    if (screenWidth >= 700) return 190.0;
    return 160.0;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final headerHeight = size.height * 0.5;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final personId = widget.actor.tagKey ?? widget.actor.thumb ?? '';
    final imageUrl = personId.isNotEmpty ? widget.client.getPersonImageUrl(personId) : '';

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Hero header with person image
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    SizedBox(
                      height: headerHeight,
                      width: double.infinity,
                      child: imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              placeholder: (_, __) => const PlaceholderContainer(),
                              errorWidget: (_, __, ___) => const PlaceholderContainer(),
                            )
                          : const PlaceholderContainer(),
                    ),
                    // Gradient overlay
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: -1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, bgColor.withValues(alpha: 0.9), bgColor],
                            stops: const [0.3, 0.8, 1.0],
                          ),
                        ),
                      ),
                    ),
                    // Person name at bottom of hero
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            widget.actor.tag,
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        // Biography
                        if (_overview != null && _overview!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          CollapsibleText(
                            text: _overview!,
                            maxLines: 6,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Filmography section
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
                        ] else if (!_isLoading) ...[
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
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Back button
          const Positioned(
            top: 0,
            left: 0,
            child: AppBarBackButton(style: BackButtonStyle.circular),
          ),
        ],
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
