/// Utility class for codec-related operations.
///
/// Provides centralized codec name mappings, file extension lookups,
/// and display name formatting.
class CodecUtils {
  CodecUtils._();

  /// Maps server subtitle codec names to API format for Jellyfin's subtitle stream endpoint.
  ///
  /// Uses format the server can deliver. For embedded formats (DVDSUB, PGS) the server
  /// converts to SRT; requesting .sub/.sup returns 404 (jellyfin-web parity).
  /// Subrip uses 'srt' not 'subrip' per Jellyfin API (issue #7958).
  static String getSubtitleExtension(String? codec) {
    if (codec == null) return 'srt';

    switch (codec.toLowerCase()) {
      case 'subrip':
      case 'srt':
        return 'srt';
      case 'ass':
        return 'ass';
      case 'ssa':
        return 'ssa';
      case 'webvtt':
      case 'vtt':
        return 'vtt';
      case 'mov_text':
        return 'srt';
      case 'pgs':
      case 'hdmv_pgs_subtitle':
        // Server converts PGS to SRT for streaming
        return 'srt';
      case 'dvd_subtitle':
      case 'dvdsub':
        // Server converts DVDSUB to SRT for streaming; .sub returns 404
        return 'srt';
      default:
        return 'srt';
    }
  }

  /// True for image-based ("bitmap") subtitle codecs that ExoPlayer cannot decode.
  /// These need server-side OCR conversion to SubRip for delivery to ExoPlayer.
  static bool isImageBasedSubtitleCodec(String? codec) {
    if (codec == null) return false;
    return switch (codec.toLowerCase()) {
      'pgs' || 'pgssub' || 'hdmv_pgs_subtitle' => true,
      'dvd_subtitle' || 'dvdsub' => true,
      'dvb_subtitle' || 'dvbsub' => true,
      _ => false,
    };
  }

  /// Formats a subtitle codec name to a user-friendly display format.
  ///
  /// Accepts both internal codec names (e.g. 'SUBRIP') and MIME types
  /// (e.g. 'application/x-subrip', emitted by ExoPlayer for external tracks)
  /// and maps both to friendly names like 'SRT'.
  static String formatSubtitleCodec(String codec) {
    final lower = codec.toLowerCase();
    // MIME types (ExoPlayer sets these for external SubtitleConfigurations)
    switch (lower) {
      case 'application/x-subrip':
      case 'text/x-subrip':
        return 'SRT';
      case 'text/vtt':
      case 'application/x-vtt':
        return 'VTT';
      case 'text/x-ssa':
      case 'application/x-ssa':
        return 'SSA';
      case 'application/x-ass':
        return 'ASS';
      case 'application/ttml+xml':
        return 'TTML';
    }
    final upper = codec.toUpperCase();
    return switch (upper) {
      'SUBRIP' => 'SRT',
      'DVD_SUBTITLE' || 'DVDSUB' => 'DVD',
      'DVB_SUBTITLE' || 'DVBSUB' => 'DVB',
      'WEBVTT' => 'VTT',
      'HDMV_PGS_SUBTITLE' || 'PGSSUB' => 'PGS',
      'MOV_TEXT' => 'MOV',
      _ => upper,
    };
  }

  /// Formats a video codec name to a user-friendly display format.
  ///
  /// Converts internal codec names like 'hevc' to friendly names like 'HEVC'.
  static String formatVideoCodec(String codec) {
    final lower = codec.toLowerCase();
    return switch (lower) {
      'h264' || 'avc1' || 'avc' => 'H.264',
      'hevc' || 'h265' || 'hev1' => 'HEVC',
      'av1' => 'AV1',
      'vp8' => 'VP8',
      'vp9' => 'VP9',
      'mpeg2video' || 'mpeg2' => 'MPEG-2',
      'mpeg4' => 'MPEG-4',
      'vc1' => 'VC-1',
      _ => codec.toUpperCase(),
    };
  }

  /// Formats an audio codec name to a user-friendly display format.
  static String formatAudioCodec(String codec) {
    final lower = codec.toLowerCase();
    return switch (lower) {
      'aac' => 'AAC',
      'ac3' => 'AC3',
      'eac3' || 'ec3' => 'E-AC3',
      'truehd' => 'TrueHD',
      'dts' => 'DTS',
      'dca' => 'DTS',
      'dtshd' || 'dts-hd' => 'DTS-HD',
      'flac' => 'FLAC',
      'mp3' || 'mp3float' => 'MP3',
      'opus' => 'Opus',
      'vorbis' => 'Vorbis',
      'pcm_s16le' || 'pcm_s24le' || 'pcm' => 'PCM',
      _ => codec.toUpperCase(),
    };
  }
}
