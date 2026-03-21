import '../mpv/mpv.dart';

import '../models/media_info.dart';
import '../models/media_metadata.dart';
import '../models/user_profile_preferences.dart';
import '../utils/app_logger.dart';
import '../utils/language_codes.dart';

// ============================================================================
// Track Matching Utilities
// ============================================================================
// These functions match MPV tracks to server tracks by properties (language,
// codec, title, etc.) instead of list index, since the two may be ordered
// differently.

/// Find the MPV subtitle track that matches a server subtitle track
SubtitleTrack? findMpvTrackForServerSubtitle(MediaSubtitleTrack serverTrack, List<SubtitleTrack> mpvTracks) {
  if (mpvTracks.isEmpty) return null;

  // For external subtitles, match by URI containing the server key
  if (serverTrack.isExternal && serverTrack.key != null) {
    for (final mpvTrack in mpvTracks) {
      if (mpvTrack.isExternal && mpvTrack.uri != null) {
        // Check if the MPV URI contains the server key path
        if (mpvTrack.uri!.contains(serverTrack.key!)) {
          return mpvTrack;
        }
      }
    }
  }

  // For internal subtitles, use scoring based on properties
  SubtitleTrack? bestMatch;
  int bestScore = 0;

  for (final mpvTrack in mpvTracks) {
    // Skip external tracks when matching internal server tracks
    if (!serverTrack.isExternal && mpvTrack.isExternal) continue;

    int score = 0;

    // Language match is most important (+10, +1 bonus for exact code match)
    if (_languagesMatch(mpvTrack.language, serverTrack.languageCode)) {
      score += 10;
      if (_languageCodesExactMatch(mpvTrack.language, serverTrack.languageCode)) {
        score += 1;
      }
    }

    // Codec match (+5)
    if (_subtitleCodecsMatch(mpvTrack.codec, serverTrack.codec)) {
      score += 5;
    }

    // Title match (+3)
    if (_titlesMatch(mpvTrack.title, serverTrack.title, serverTrack.displayTitle)) {
      score += 3;
    }

    // Forced flag match (+2)
    if (mpvTrack.isForced == serverTrack.forced) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = mpvTrack;
    }
  }

  // Require at least language match for a valid match
  return bestScore >= 10 ? bestMatch : null;
}

/// Find the server subtitle track that matches an MPV subtitle track
MediaSubtitleTrack? findServerTrackForMpvSubtitle(SubtitleTrack mpvTrack, List<MediaSubtitleTrack> serverTracks) {
  if (serverTracks.isEmpty) return null;

  // For external subtitles, match by URI containing the server key
  if (mpvTrack.isExternal && mpvTrack.uri != null) {
    for (final serverTrack in serverTracks) {
      if (serverTrack.isExternal && serverTrack.key != null) {
        if (mpvTrack.uri!.contains(serverTrack.key!)) {
          return serverTrack;
        }
      }
    }
  }

  // For internal subtitles, use scoring based on properties
  MediaSubtitleTrack? bestMatch;
  int bestScore = 0;

  for (final serverTrack in serverTracks) {
    // Skip external server tracks when matching internal MPV tracks
    if (!mpvTrack.isExternal && serverTrack.isExternal) continue;

    int score = 0;

    // Language match is most important (+10, +1 bonus for exact code match)
    if (_languagesMatch(mpvTrack.language, serverTrack.languageCode)) {
      score += 10;
      if (_languageCodesExactMatch(mpvTrack.language, serverTrack.languageCode)) {
        score += 1;
      }
    }

    // Codec match (+5)
    if (_subtitleCodecsMatch(mpvTrack.codec, serverTrack.codec)) {
      score += 5;
    }

    // Title match (+3)
    if (_titlesMatch(mpvTrack.title, serverTrack.title, serverTrack.displayTitle)) {
      score += 3;
    }

    // Forced flag match (+2)
    if (mpvTrack.isForced == serverTrack.forced) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = serverTrack;
    }
  }

  // Require at least language match for a valid match
  return bestScore >= 10 ? bestMatch : null;
}

/// Find the MPV audio track that matches a server audio track
AudioTrack? findMpvTrackForServerAudio(MediaAudioTrack serverTrack, List<AudioTrack> mpvTracks) {
  if (mpvTracks.isEmpty) return null;

  AudioTrack? bestMatch;
  int bestScore = 0;

  for (final mpvTrack in mpvTracks) {
    int score = 0;

    // Language match is most important (+10, +1 bonus for exact code match)
    if (_languagesMatch(mpvTrack.language, serverTrack.languageCode)) {
      score += 10;
      if (_languageCodesExactMatch(mpvTrack.language, serverTrack.languageCode)) {
        score += 1;
      }
    }

    // Codec match (+5)
    if (_audioCodecsMatch(mpvTrack.codec, serverTrack.codec)) {
      score += 5;
    }

    // Channel count match (+3)
    if (mpvTrack.channels != null && serverTrack.channels != null) {
      if (mpvTrack.channels == serverTrack.channels) {
        score += 3;
      }
    }

    // Title match (+2)
    if (_titlesMatch(mpvTrack.title, serverTrack.title, serverTrack.displayTitle)) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = mpvTrack;
    }
  }

  // Require at least language match for a valid match
  return bestScore >= 10 ? bestMatch : null;
}

/// Find the server audio track that matches an MPV audio track
MediaAudioTrack? findServerTrackForMpvAudio(AudioTrack mpvTrack, List<MediaAudioTrack> serverTracks) {
  if (serverTracks.isEmpty) return null;

  MediaAudioTrack? bestMatch;
  int bestScore = 0;

  for (final serverTrack in serverTracks) {
    int score = 0;

    // Language match is most important (+10, +1 bonus for exact code match)
    if (_languagesMatch(mpvTrack.language, serverTrack.languageCode)) {
      score += 10;
      if (_languageCodesExactMatch(mpvTrack.language, serverTrack.languageCode)) {
        score += 1;
      }
    }

    // Codec match (+5)
    if (_audioCodecsMatch(mpvTrack.codec, serverTrack.codec)) {
      score += 5;
    }

    // Channel count match (+3)
    if (mpvTrack.channels != null && serverTrack.channels != null) {
      if (mpvTrack.channels == serverTrack.channels) {
        score += 3;
      }
    }

    // Title match (+2)
    if (_titlesMatch(mpvTrack.title, serverTrack.title, serverTrack.displayTitle)) {
      score += 2;
    }

    if (score > bestScore) {
      bestScore = score;
      bestMatch = serverTrack;
    }
  }

  // Require at least language match for a valid match
  return bestScore >= 10 ? bestMatch : null;
}

/// Check if two language codes match exactly (after normalizing case and stripping region suffixes)
bool _languageCodesExactMatch(String? a, String? b) {
  if (a == null || b == null) return false;
  return a.toLowerCase().split('-').first == b.toLowerCase().split('-').first;
}

/// Check if two language codes refer to the same language
/// Handles both ISO 639-1 (2-letter) and ISO 639-2 (3-letter) codes
bool _languagesMatch(String? mpvLang, String? serverLang) {
  if (mpvLang == null || serverLang == null) return false;

  final mpvNormalized = mpvLang.toLowerCase().split('-').first;
  final serverNormalized = serverLang.toLowerCase().split('-').first;

  // Direct match
  if (mpvNormalized == serverNormalized) return true;

  // Use LanguageCodes to get all variations and check for overlap
  try {
    final mpvVariations = LanguageCodes.getVariations(mpvNormalized);
    return mpvVariations.contains(serverNormalized);
  } catch (_) {
    // LanguageCodes not initialized, fall back to direct comparison
    return false;
  }
}

/// Check if two subtitle codec strings match
/// Handles common aliases (e.g., subrip/srt, ass/ssa)
bool _subtitleCodecsMatch(String? mpvCodec, String? serverCodec) {
  if (mpvCodec == null || serverCodec == null) return false;

  final mpvNorm = mpvCodec.toLowerCase();
  final serverNorm = serverCodec.toLowerCase();

  if (mpvNorm == serverNorm) return true;

  // Common subtitle codec aliases
  const aliases = {
    'subrip': ['srt', 'subrip'],
    'srt': ['srt', 'subrip'],
    'ass': ['ass', 'ssa'],
    'ssa': ['ass', 'ssa'],
    'pgs': ['pgs', 'hdmv_pgs_subtitle'],
    'hdmv_pgs_subtitle': ['pgs', 'hdmv_pgs_subtitle'],
    'vobsub': ['vobsub', 'dvd_subtitle'],
    'dvd_subtitle': ['vobsub', 'dvd_subtitle'],
    'webvtt': ['webvtt', 'vtt'],
    'vtt': ['webvtt', 'vtt'],
  };

  final mpvAliases = aliases[mpvNorm] ?? [mpvNorm];
  return mpvAliases.contains(serverNorm);
}

/// Check if two audio codec strings match
/// Handles common aliases (e.g., ac3/a52, dts variants)
bool _audioCodecsMatch(String? mpvCodec, String? serverCodec) {
  if (mpvCodec == null || serverCodec == null) return false;

  final mpvNorm = mpvCodec.toLowerCase();
  final serverNorm = serverCodec.toLowerCase();

  if (mpvNorm == serverNorm) return true;

  // Common audio codec aliases
  const aliases = {
    'ac3': ['ac3', 'a52', 'eac3', 'dolby digital'],
    'a52': ['ac3', 'a52'],
    'eac3': ['eac3', 'e-ac-3', 'dolby digital plus', 'ac3'],
    'dts': ['dts', 'dca'],
    'dca': ['dts', 'dca'],
    'aac': ['aac', 'mp4a'],
    'mp4a': ['aac', 'mp4a'],
    'truehd': ['truehd', 'mlp'],
    'mlp': ['truehd', 'mlp'],
    'flac': ['flac'],
    'opus': ['opus'],
    'vorbis': ['vorbis', 'ogg'],
    'mp3': ['mp3', 'mp3float'],
  };

  final mpvAliases = aliases[mpvNorm] ?? [mpvNorm];
  return mpvAliases.contains(serverNorm);
}

/// Check if titles match (fuzzy comparison)
bool _titlesMatch(String? mpvTitle, String? serverTitle, String? serverDisplayTitle) {
  if (mpvTitle == null || mpvTitle.isEmpty) return true; // No title to match against

  final mpvNorm = mpvTitle.toLowerCase().trim();

  // Check exact match with either server title
  if (serverTitle != null && serverTitle.toLowerCase().trim() == mpvNorm) return true;
  if (serverDisplayTitle != null && serverDisplayTitle.toLowerCase().trim() == mpvNorm) return true;

  // Check if one contains the other (partial match)
  if (serverTitle != null && serverTitle.toLowerCase().contains(mpvNorm)) return true;
  if (serverDisplayTitle != null && serverDisplayTitle.toLowerCase().contains(mpvNorm)) return true;

  return false;
}

/// Priority levels for track selection
enum TrackSelectionPriority {
  navigation, // Priority 1: User's manual selection from previous episode
  serverSelected, // Priority 2: Server's selected track from media info
  perMedia, // Priority 3: Per-media language preference
  profile, // Priority 4: User profile preferences
  defaultTrack, // Priority 5: Default or first track
  off, // Priority 6: Subtitles off (subtitle only)
}

/// Result of track selection including the selected track and which priority was used
class TrackSelectionResult<T> {
  final T track;
  final TrackSelectionPriority priority;

  TrackSelectionResult(this.track, this.priority);
}

/// Service for selecting and applying audio and subtitle tracks based on
/// preferences, user profiles, and per-media settings.
class TrackSelectionService {
  final Player player;
  final UserProfilePreferences? profileSettings;
  final MediaMetadata metadata;
  final MediaInfo? mediaInfo;

  TrackSelectionService({required this.player, this.profileSettings, required this.metadata, this.mediaInfo});

  /// Build list of preferred languages from a user profile
  List<String> _buildPreferredLanguages(UserProfilePreferences profile, {required bool isAudio}) {
    final primary = isAudio ? profile.defaultAudioLanguage : profile.defaultSubtitleLanguage;
    final list = isAudio ? profile.defaultAudioLanguages : profile.defaultSubtitleLanguages;

    final result = <String>[];
    if (primary != null && primary.isNotEmpty) {
      result.add(primary);
    }
    if (list != null) {
      result.addAll(list);
    }
    return result;
  }

  /// Find a track by preferred language with variation lookup and logging
  T? _findTrackByPreferredLanguage<T>(
    List<T> tracks,
    String preferredLanguage,
    String? Function(T) getLanguage,
    String Function(T) getDescription,
    String trackType,
  ) {
    final languageVariations = LanguageCodes.getVariations(preferredLanguage);
    return _findTrackByLanguageVariations<T>(
      tracks,
      preferredLanguage,
      languageVariations,
      getLanguage,
      getDescription,
      trackType,
    );
  }

  /// Apply a filter to tracks, falling back to original if filter produces empty result
  List<T> _applyFilterWithFallback<T>(List<T> tracks, List<T> Function(List<T>) filter, String _) {
    final filtered = filter(tracks);
    return filtered.isNotEmpty ? filtered : tracks;
  }

  /// Generic track matching for audio and subtitle tracks
  /// Returns the best matching track based on hierarchical criteria:
  /// 1. Exact match (id + title + language)
  /// 2. Partial match (title + language)
  /// 3. Language-only match
  T? findBestTrackMatch<T>(
    List<T> availableTracks,
    T preferred,
    String Function(T) getId,
    String? Function(T) getTitle,
    String? Function(T) getLanguage,
  ) {
    if (availableTracks.isEmpty) return null;

    // Filter out auto and no tracks
    final validTracks = availableTracks.where((t) => getId(t) != 'auto' && getId(t) != 'no').toList();
    if (validTracks.isEmpty) return null;

    final preferredId = getId(preferred);
    final preferredTitle = getTitle(preferred);
    final preferredLanguage = getLanguage(preferred);

    // Try to match: id, title, and language
    for (var track in validTracks) {
      if (getId(track) == preferredId && getTitle(track) == preferredTitle && getLanguage(track) == preferredLanguage) {
        return track;
      }
    }

    // Try to match: title and language
    for (var track in validTracks) {
      if (getTitle(track) == preferredTitle && getLanguage(track) == preferredLanguage) {
        return track;
      }
    }

    // Try to match: language only
    for (var track in validTracks) {
      if (getLanguage(track) == preferredLanguage) {
        return track;
      }
    }

    return null;
  }

  AudioTrack? findBestAudioMatch(List<AudioTrack> availableTracks, AudioTrack preferred) {
    return findBestTrackMatch<AudioTrack>(availableTracks, preferred, (t) => t.id, (t) => t.title, (t) => t.language);
  }

  AudioTrack? findAudioTrackByProfile(List<AudioTrack> availableTracks, UserProfilePreferences profile) {
    if (availableTracks.isEmpty || !profile.autoSelectAudio) return null;

    final preferredLanguages = _buildPreferredLanguages(profile, isAudio: true);
    if (preferredLanguages.isEmpty) return null;

    for (final preferredLanguage in preferredLanguages) {
      final match = _findTrackByPreferredLanguage<AudioTrack>(
        availableTracks,
        preferredLanguage,
        (t) => t.language,
        (t) => t.title ?? 'Track ${t.id}',
        'audio track',
      );
      if (match != null) return match;
    }

    return null;
  }

  SubtitleTrack? findBestSubtitleMatch(List<SubtitleTrack> availableTracks, SubtitleTrack preferred) {
    // Handle special "no subtitles" case
    if (preferred.id == 'no') {
      return SubtitleTrack.off;
    }

    return findBestTrackMatch<SubtitleTrack>(
      availableTracks,
      preferred,
      (t) => t.id,
      (t) => t.title,
      (t) => t.language,
    );
  }

  SubtitleTrack? findSubtitleTrackByProfile(
    List<SubtitleTrack> availableTracks,
    UserProfilePreferences profile, {
    AudioTrack? selectedAudioTrack,
  }) {
    if (availableTracks.isEmpty) return null;

    // Mode 0: Manually selected - return OFF
    if (profile.autoSelectSubtitle == 0) return SubtitleTrack.off;

    // Mode 1: Shown with foreign audio
    if (profile.autoSelectSubtitle == 1) {
      if (selectedAudioTrack != null && profile.defaultSubtitleLanguage != null) {
        final audioLang = selectedAudioTrack.language?.toLowerCase();
        final prefLang = profile.defaultSubtitleLanguage!.toLowerCase();
        final languageVariations = LanguageCodes.getVariations(prefLang);

        // If audio matches preferred language, no subtitles needed
        if (audioLang != null && languageVariations.contains(audioLang)) {
          return SubtitleTrack.off;
        }
      }
    }

    // Mode 2: Always enabled (or continuing from mode 1 with foreign audio)
    final preferredLanguages = _buildPreferredLanguages(profile, isAudio: false);
    if (preferredLanguages.isEmpty) return null;

    // Apply filtering with fallback to original tracks if filter produces empty result
    var candidateTracks = availableTracks;
    candidateTracks = filterSubtitlesBySDH(candidateTracks, profile.defaultSubtitleAccessibility);
    candidateTracks = filterSubtitlesByForced(candidateTracks, profile.defaultSubtitleForced);
    candidateTracks = _applyFilterWithFallback(availableTracks, (_) => candidateTracks, 'strict filters');

    for (final preferredLanguage in preferredLanguages) {
      final match = _findTrackByPreferredLanguage<SubtitleTrack>(
        candidateTracks,
        preferredLanguage,
        (t) => t.language,
        (t) => t.title ?? 'Track ${t.id}',
        'subtitle',
      );
      if (match != null) return match;
    }

    return null;
  }

  /// Filters subtitle tracks based on SDH (Subtitles for Deaf or Hard-of-Hearing) preference
  ///
  /// Values:
  /// - 0: Prefer non-SDH subtitles
  /// - 1: Prefer SDH subtitles
  /// - 2: Only show SDH subtitles
  /// - 3: Only show non-SDH subtitles
  List<SubtitleTrack> filterSubtitlesBySDH(List<SubtitleTrack> tracks, int preference) {
    if (preference == 0 || preference == 1) {
      final preferSDH = preference == 1;
      final preferred = tracks.where((t) => isSDH(t) == preferSDH).toList();
      return preferred.isNotEmpty ? preferred : tracks;
    } else if (preference == 2) {
      return tracks.where((t) => isSDH(t)).toList();
    } else if (preference == 3) {
      return tracks.where((t) => !isSDH(t)).toList();
    }
    return tracks;
  }

  /// Filters subtitle tracks based on forced subtitle preference
  ///
  /// Values:
  /// - 0: Prefer non-forced subtitles
  /// - 1: Prefer forced subtitles
  /// - 2: Only show forced subtitles
  /// - 3: Only show non-forced subtitles
  List<SubtitleTrack> filterSubtitlesByForced(List<SubtitleTrack> tracks, int preference) {
    if (preference == 0 || preference == 1) {
      final preferForced = preference == 1;
      final preferred = tracks.where((t) => isForced(t) == preferForced).toList();
      return preferred.isNotEmpty ? preferred : tracks;
    } else if (preference == 2) {
      return tracks.where((t) => isForced(t)).toList();
    } else if (preference == 3) {
      return tracks.where((t) => !isForced(t)).toList();
    }
    return tracks;
  }

  /// Checks if a subtitle track is SDH (Subtitles for Deaf or Hard-of-Hearing)
  ///
  /// Since mpv may not expose this directly, we infer from the title
  bool isSDH(SubtitleTrack track) {
    final title = track.title?.toLowerCase() ?? '';

    // Look for common SDH indicators
    return title.contains('sdh') ||
        title.contains('cc') ||
        title.contains('hearing impaired') ||
        title.contains('deaf');
  }

  /// Checks if a subtitle track is forced
  bool isForced(SubtitleTrack track) {
    final title = track.title?.toLowerCase() ?? '';
    return title.contains('forced');
  }

  /// Find a track matching a preferred language from a list of tracks
  /// Returns the first track whose language matches any variation of the preferred language
  T? _findTrackByLanguageVariations<T>(
    List<T> tracks,
    String _,
    List<String> languageVariations,
    String? Function(T) getLanguage,
    String Function(T) _,
    String _,
  ) {
    for (var track in tracks) {
      final trackLang = getLanguage(track)?.toLowerCase();
      if (trackLang != null && languageVariations.any((lang) => trackLang.startsWith(lang))) {
        return track;
      }
    }
    return null;
  }

  /// Checks if a track language matches a preferred language
  ///
  /// Handles both 2-letter (ISO 639-1) and 3-letter (ISO 639-2) codes
  /// Also handles bibliographic variants and region codes (e.g., "en-US")
  bool languageMatches(String? trackLanguage, String? preferredLanguage) {
    if (trackLanguage == null || preferredLanguage == null) {
      return false;
    }

    final track = trackLanguage.toLowerCase();
    final preferred = preferredLanguage.toLowerCase();

    // Direct match
    if (track == preferred) return true;

    // Extract base language codes (handle region codes like "en-US")
    final trackBase = track.split('-').first;
    final preferredBase = preferred.split('-').first;

    if (trackBase == preferredBase) return true;

    // Get all variations of the preferred language (e.g., "en" → ["en", "eng"])
    final variations = LanguageCodes.getVariations(preferredBase);

    // Check if track's base code matches any variation
    return variations.contains(trackBase);
  }

  /// Select the best audio track based on priority:
  /// Priority 1: Preferred track from navigation
  /// Priority 2: Server-selected track from media info
  /// Priority 3: Per-media language preference
  /// Priority 4: User profile preferences
  /// Priority 5: Default or first track
  TrackSelectionResult<AudioTrack>? selectAudioTrack(
    List<AudioTrack> availableTracks,
    AudioTrack? preferredAudioTrack,
  ) {
    if (availableTracks.isEmpty) return null;

    AudioTrack? trackToSelect;

    // Priority 1: Try to match preferred track from navigation
    if (preferredAudioTrack != null) {
      trackToSelect = findBestAudioMatch(availableTracks, preferredAudioTrack);
      if (trackToSelect != null) {
        return TrackSelectionResult(trackToSelect, TrackSelectionPriority.navigation);
      }
    }

    // Priority 2: Check server-selected track from media info
    if (mediaInfo != null && availableTracks.isNotEmpty) {
      final serverSelectedTrack = mediaInfo!.audioTracks.where((t) => t.selected).firstOrNull;

      if (serverSelectedTrack != null) {
        final matchedMpvTrack = findMpvTrackForServerAudio(serverSelectedTrack, availableTracks);

        if (matchedMpvTrack != null) {
          return TrackSelectionResult(matchedMpvTrack, TrackSelectionPriority.serverSelected);
        }
      }
    }

    // Priority 3: Try per-media language preference
    if (metadata.audioLanguage != null) {
      final matchedTrack = availableTracks.firstWhere(
        (track) => languageMatches(track.language, metadata.audioLanguage),
        orElse: () => availableTracks.first,
      );
      if (languageMatches(matchedTrack.language, metadata.audioLanguage)) {
        return TrackSelectionResult(matchedTrack, TrackSelectionPriority.perMedia);
      }
    }

    // Priority 4: Try user profile preferences
    if (profileSettings != null) {
      trackToSelect = findAudioTrackByProfile(availableTracks, profileSettings!);
      if (trackToSelect != null) {
        return TrackSelectionResult(trackToSelect, TrackSelectionPriority.profile);
      }
    }

    // Priority 5: Use default or first track
    trackToSelect = availableTracks.firstWhere((t) => t.isDefault, orElse: () => availableTracks.first);
    return TrackSelectionResult(trackToSelect, TrackSelectionPriority.defaultTrack);
  }

  /// Select the best subtitle track based on priority:
  /// Priority 1: Preferred track from navigation
  /// Priority 2: Server-selected track from media info
  /// Priority 3: Per-media language preference
  /// Priority 4: User profile preferences
  /// Priority 5: Default track
  /// Priority 6: Off
  TrackSelectionResult<SubtitleTrack> selectSubtitleTrack(
    List<SubtitleTrack> availableTracks,
    SubtitleTrack? preferredSubtitleTrack,
    AudioTrack? selectedAudioTrack,
  ) {
    SubtitleTrack? subtitleToSelect;

    // Priority 1: Try preferred track from navigation
    if (preferredSubtitleTrack != null) {
      if (preferredSubtitleTrack.id == 'no') {
        return TrackSelectionResult(SubtitleTrack.off, TrackSelectionPriority.navigation);
      } else if (availableTracks.isNotEmpty) {
        subtitleToSelect = findBestSubtitleMatch(availableTracks, preferredSubtitleTrack);
        if (subtitleToSelect != null) {
          return TrackSelectionResult(subtitleToSelect, TrackSelectionPriority.navigation);
        }
      }
    }

    // Priority 2: Check server-selected track from media info
    if (mediaInfo != null && availableTracks.isNotEmpty) {
      final serverSelectedTrack = mediaInfo!.subtitleTracks.where((t) => t.selected).firstOrNull;

      if (serverSelectedTrack != null) {
        appLogger.d('[Sub] mediaInfo has serverSelected subtitle: ${serverSelectedTrack.displayTitle ?? serverSelectedTrack.language ?? "track"}');
        final matchedMpvTrack = findMpvTrackForServerSubtitle(serverSelectedTrack, availableTracks);

        if (matchedMpvTrack != null) {
          appLogger.d('[Sub] matched MPV track for server-selected, will use serverSelected priority');
          return TrackSelectionResult(matchedMpvTrack, TrackSelectionPriority.serverSelected);
        }
      }
    }

    // Priority 3: Try per-media language preference
    if (metadata.subtitleLanguage != null) {
      if (metadata.subtitleLanguage == 'none' || metadata.subtitleLanguage!.isEmpty) {
        return TrackSelectionResult(SubtitleTrack.off, TrackSelectionPriority.perMedia);
      } else if (availableTracks.isNotEmpty) {
        final matchedTrack = availableTracks.firstWhere(
          (track) => languageMatches(track.language, metadata.subtitleLanguage),
          orElse: () => availableTracks.first,
        );
        if (languageMatches(matchedTrack.language, metadata.subtitleLanguage)) {
          return TrackSelectionResult(matchedTrack, TrackSelectionPriority.perMedia);
        }
      }
    }

    // Priority 4: Apply user profile preferences
    if (profileSettings != null && availableTracks.isNotEmpty) {
      subtitleToSelect = findSubtitleTrackByProfile(
        availableTracks,
        profileSettings!,
        selectedAudioTrack: selectedAudioTrack,
      );
      if (subtitleToSelect != null) {
        return TrackSelectionResult(subtitleToSelect, TrackSelectionPriority.profile);
      }
    }

    // Priority 5: Check for default subtitle
    if (availableTracks.isNotEmpty) {
      final defaultTrack = availableTracks.firstWhere((t) => t.isDefault, orElse: () => availableTracks.first);
      if (defaultTrack.isDefault) {
        appLogger.d('[Sub] using defaultTrack from MPV: ${defaultTrack.title ?? defaultTrack.id}');
        return TrackSelectionResult(defaultTrack, TrackSelectionPriority.defaultTrack);
      }
    }

    // Priority 6: Turn off subtitles
    return TrackSelectionResult(SubtitleTrack.off, TrackSelectionPriority.off);
  }

  /// Select and apply audio and subtitle tracks based on preferences
  Future<void> selectAndApplyTracks({
    AudioTrack? preferredAudioTrack,
    SubtitleTrack? preferredSubtitleTrack,
    double? defaultPlaybackSpeed,
    Function(AudioTrack)? onAudioTrackChanged,
    Function(SubtitleTrack)? onSubtitleTrackChanged,
  }) async {
    // Wait for tracks to be loaded
    int attempts = 0;
    while (player.state.tracks.audio.isEmpty && player.state.tracks.subtitle.isEmpty && attempts < 100) {
      if (player.disposed) return;
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (player.disposed) return;

    // Get real tracks (excluding auto and no)
    final realAudioTracks = player.state.tracks.audio.where((t) => t.id != 'auto' && t.id != 'no').toList();
    final realSubtitleTracks = player.state.tracks.subtitle.where((t) => t.id != 'auto' && t.id != 'no').toList();

    // Select and apply audio track
    final audioResult = selectAudioTrack(realAudioTracks, preferredAudioTrack);
    AudioTrack? selectedAudioTrack;
    if (audioResult != null) {
      selectedAudioTrack = audioResult.track;
      appLogger.d(
        'Audio: ${selectedAudioTrack.title ?? selectedAudioTrack.language ?? "Track ${selectedAudioTrack.id}"} [${audioResult.priority.name}]',
      );
      player.selectAudioTrack(selectedAudioTrack);

      // Notify callback if this was user's navigation preference (Priority 1)
      if (audioResult.priority == TrackSelectionPriority.navigation && onAudioTrackChanged != null) {
        onAudioTrackChanged(selectedAudioTrack);
      }
    }

    // Select and apply subtitle track
    final subtitleResult = selectSubtitleTrack(realSubtitleTracks, preferredSubtitleTrack, selectedAudioTrack);
    final selectedSubtitleTrack = subtitleResult.track;
    final subtitleName = selectedSubtitleTrack.id == 'no'
        ? 'OFF'
        : (selectedSubtitleTrack.title ?? selectedSubtitleTrack.language ?? 'Track ${selectedSubtitleTrack.id}');
    appLogger.d('[Sub] applied: $subtitleName priority=${subtitleResult.priority.name}');
    player.selectSubtitleTrack(selectedSubtitleTrack);

    // Notify callback if this was user's navigation preference (Priority 1)
    if (subtitleResult.priority == TrackSelectionPriority.navigation && onSubtitleTrackChanged != null) {
      onSubtitleTrackChanged(selectedSubtitleTrack);
    }

    // Apply default playback speed from settings
    if (defaultPlaybackSpeed != null && defaultPlaybackSpeed != 1.0) {
      player.setRate(defaultPlaybackSpeed);
    }
  }
}
