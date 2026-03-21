///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsZh with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZh({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  $meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		$meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh>.
	@override final TranslationMetadata<AppLocale, Translations> $meta;

	/// Access flat map
	@override dynamic operator[](String key) => $meta.getTranslation(key);

	late final TranslationsZh _root = this; // ignore: unused_field

	@override 
	TranslationsZh $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZh(meta: meta ?? this.$meta);

	// Translations
	@override late final _TranslationsAppZh app = _TranslationsAppZh._(_root);
	@override late final _TranslationsAuthZh auth = _TranslationsAuthZh._(_root);
	@override late final _TranslationsCommonZh common = _TranslationsCommonZh._(_root);
	@override late final _TranslationsScreensZh screens = _TranslationsScreensZh._(_root);
	@override late final _TranslationsUpdateZh update = _TranslationsUpdateZh._(_root);
	@override late final _TranslationsSettingsZh settings = _TranslationsSettingsZh._(_root);
	@override late final _TranslationsSearchZh search = _TranslationsSearchZh._(_root);
	@override late final _TranslationsHotkeysZh hotkeys = _TranslationsHotkeysZh._(_root);
	@override late final _TranslationsPinEntryZh pinEntry = _TranslationsPinEntryZh._(_root);
	@override late final _TranslationsFileInfoZh fileInfo = _TranslationsFileInfoZh._(_root);
	@override late final _TranslationsMediaMenuZh mediaMenu = _TranslationsMediaMenuZh._(_root);
	@override late final _TranslationsAccessibilityZh accessibility = _TranslationsAccessibilityZh._(_root);
	@override late final _TranslationsTooltipsZh tooltips = _TranslationsTooltipsZh._(_root);
	@override late final _TranslationsVideoControlsZh videoControls = _TranslationsVideoControlsZh._(_root);
	@override late final _TranslationsUserStatusZh userStatus = _TranslationsUserStatusZh._(_root);
	@override late final _TranslationsMessagesZh messages = _TranslationsMessagesZh._(_root);
	@override late final _TranslationsSubtitlingStylingZh subtitlingStyling = _TranslationsSubtitlingStylingZh._(_root);
	@override late final _TranslationsMpvConfigZh mpvConfig = _TranslationsMpvConfigZh._(_root);
	@override late final _TranslationsDialogZh dialog = _TranslationsDialogZh._(_root);
	@override late final _TranslationsDiscoverZh discover = _TranslationsDiscoverZh._(_root);
	@override late final _TranslationsErrorsZh errors = _TranslationsErrorsZh._(_root);
	@override late final _TranslationsLibrariesZh libraries = _TranslationsLibrariesZh._(_root);
	@override late final _TranslationsAboutZh about = _TranslationsAboutZh._(_root);
	@override late final _TranslationsServerSelectionZh serverSelection = _TranslationsServerSelectionZh._(_root);
	@override late final _TranslationsHubDetailZh hubDetail = _TranslationsHubDetailZh._(_root);
	@override late final _TranslationsLogsZh logs = _TranslationsLogsZh._(_root);
	@override late final _TranslationsLicensesZh licenses = _TranslationsLicensesZh._(_root);
	@override late final _TranslationsNavigationZh navigation = _TranslationsNavigationZh._(_root);
	@override late final _TranslationsLiveTvZh liveTv = _TranslationsLiveTvZh._(_root);
	@override late final _TranslationsDownloadsZh downloads = _TranslationsDownloadsZh._(_root);
	@override late final _TranslationsPlaylistsZh playlists = _TranslationsPlaylistsZh._(_root);
	@override late final _TranslationsCollectionsZh collections = _TranslationsCollectionsZh._(_root);
	@override late final _TranslationsShadersZh shaders = _TranslationsShadersZh._(_root);
	@override late final _TranslationsCompanionRemoteZh companionRemote = _TranslationsCompanionRemoteZh._(_root);
	@override late final _TranslationsVideoSettingsZh videoSettings = _TranslationsVideoSettingsZh._(_root);
	@override late final _TranslationsExternalPlayerZh externalPlayer = _TranslationsExternalPlayerZh._(_root);
}

// Path: app
class _TranslationsAppZh implements TranslationsAppEn {
	_TranslationsAppZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'Finzy';
}

// Path: auth
class _TranslationsAuthZh implements TranslationsAuthEn {
	_TranslationsAuthZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get signInWithJellyfin => '使用 Jellyfin 登录';
	@override String get jellyfinServerUrl => '服务器 URL';
	@override String get jellyfinServerUrlHint => 'https://your-jellyfin.example.com';
	@override String get jellyfinUsername => '用户名';
	@override String get jellyfinPassword => '密码';
	@override String get jellyfinSignIn => '登录';
	@override String get showQRCode => '显示二维码';
	@override String get authenticate => '验证';
	@override String get debugEnterToken => '调试：输入 Jellyfin Token';
	@override String get authTokenLabel => 'Jellyfin 授权令牌 (Auth Token)';
	@override String get authTokenHint => '输入你的令牌';
	@override String get authenticationTimeout => '验证超时。请重试。';
	@override String get sessionExpired => '您的会话已过期。请重新登录。';
	@override String get connectionTimeout => '连接超时。请检查网络后重试。';
	@override String get invalidPassword => '用户名或密码错误。';
	@override String get notAuthorized => '未授权。请重新登录。';
	@override String get serverUnreachable => '无法连接服务器。请检查 URL 和网络连接。';
	@override String get serverError => '服务器错误。请稍后重试。';
	@override String get scanQRToSignIn => '扫描二维码登录';
	@override String get waitingForAuth => '等待验证中...\n请在你的浏览器中完成登录。';
	@override String get useBrowser => '使用浏览器';
}

// Path: common
class _TranslationsCommonZh implements TranslationsCommonEn {
	_TranslationsCommonZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get cancel => '取消';
	@override String get save => '保存';
	@override String get close => '关闭';
	@override String get clear => '清除';
	@override String get reset => '重置';
	@override String get later => '稍后';
	@override String get submit => '提交';
	@override String get confirm => '确认';
	@override String get retry => '重试';
	@override String get logout => '登出';
	@override String get quickConnect => 'Quick Connect';
	@override String get quickConnectDescription => 'To sign in with Quick Connect, select the \'Quick Connect\' button on the device you are logging in from and enter the displayed code below.';
	@override String get quickConnectCode => 'Quick Connect Code';
	@override String get authorize => 'Authorize';
	@override String get quickConnectSuccess => 'Quick Connect authorized successfully';
	@override String get quickConnectError => 'Failed to authorize Quick Connect code';
	@override String get unknown => '未知';
	@override String get refresh => '刷新';
	@override String get yes => '是';
	@override String get no => '否';
	@override String get delete => '删除';
	@override String get shuffle => '随机播放';
	@override String get addTo => '添加到...';
	@override String get remove => '删除';
	@override String get paste => '粘贴';
	@override String get connect => '连接';
	@override String get disconnect => '断开连接';
	@override String get play => '播放';
	@override String get pause => '暂停';
	@override String get resume => '继续';
	@override String get error => '错误';
	@override String get search => '搜索';
	@override String get home => '首页';
	@override String get back => '返回';
	@override String get settings => '设置';
	@override String get mute => '静音';
	@override String get ok => '确定';
	@override String get none => 'None';
	@override String get loading => '加载中...';
	@override String get reconnect => '重新连接';
	@override String get goOffline => '进入离线模式';
	@override String get goOnline => '返回在线';
	@override String get connectionAvailable => '连接可用';
	@override String get exitConfirmTitle => '退出应用？';
	@override String get exitConfirmMessage => '确定要退出吗？';
	@override String get dontAskAgain => '不再询问';
	@override String get exit => '退出';
	@override String get viewAll => '查看全部';
}

// Path: screens
class _TranslationsScreensZh implements TranslationsScreensEn {
	_TranslationsScreensZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get licenses => '许可证';
	@override String get switchProfile => '切换用户';
	@override String get subtitleStyling => '字幕样式';
	@override String get mpvConfig => 'MPV 配置';
	@override String get logs => '日志';
}

// Path: update
class _TranslationsUpdateZh implements TranslationsUpdateEn {
	_TranslationsUpdateZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get available => '有可用更新';
	@override String versionAvailable({required Object version}) => '版本 ${version} 已发布';
	@override String currentVersion({required Object version}) => '当前版本: ${version}';
	@override String get skipVersion => '跳过此版本';
	@override String get viewRelease => '查看发布详情';
	@override String get updateInStore => '在应用商店更新';
	@override String get latestVersion => '已安装的版本是可用的最新版本';
	@override String get checkFailed => '无法检查更新';
}

// Path: settings
class _TranslationsSettingsZh implements TranslationsSettingsEn {
	_TranslationsSettingsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '设置';
	@override String get supportOptionalCaption => '可选——应用保持免费';
	@override String get supportTierSupport => '支持开发';
	@override String get supportTipThankYou => '感谢你的支持！';
	@override String get language => '语言';
	@override String get theme => '主题';
	@override String get appearance => '外观';
	@override String get videoPlayback => '视频播放';
	@override String get advanced => '高级';
	@override String get episodePosterMode => '剧集海报样式';
	@override String get seriesPoster => '剧集海报';
	@override String get seriesPosterDescription => '为所有剧集显示剧集海报';
	@override String get seasonPoster => '季海报';
	@override String get seasonPosterDescription => '为剧集显示特定季的海报';
	@override String get episodeThumbnail => '剧集缩略图';
	@override String get episodeThumbnailDescription => '显示16:9剧集截图缩略图';
	@override String get timeFormat => '时间格式';
	@override String get system => '系统';
	@override String get systemDescription => '跟随系统时间格式设置';
	@override String get twelveHour => '12小时制';
	@override String get twentyFourHour => '24小时制';
	@override String get twelveHourDescription => '例如 1:00 PM';
	@override String get twentyFourHourDescription => '例如 13:00';
	@override String get showHeroSectionDescription => '在主屏幕上显示精选内容轮播区';
	@override String get secondsLabel => '秒';
	@override String get minutesLabel => '分钟';
	@override String get secondsShort => 's';
	@override String get minutesShort => 'm';
	@override String durationHint({required Object min, required Object max}) => '输入时长 (${min}-${max})';
	@override String get systemTheme => '系统';
	@override String get systemThemeDescription => '跟随系统设置';
	@override String get lightTheme => '浅色';
	@override String get darkTheme => '深色';
	@override String get oledTheme => 'OLED';
	@override String get oledThemeDescription => '纯黑色适用于 OLED 屏幕';
	@override String get libraryDensity => '媒体库密度';
	@override String get compact => '紧凑';
	@override String get compactDescription => '卡片更小，显示更多项目';
	@override String get normal => '标准';
	@override String get normalDescription => '默认尺寸';
	@override String get comfortable => '舒适';
	@override String get comfortableDescription => '卡片更大，显示更少项目';
	@override String get viewMode => '视图模式';
	@override String get gridView => '网格视图';
	@override String get gridViewDescription => '以网格布局显示项目';
	@override String get listView => '列表视图';
	@override String get listViewDescription => '以列表布局显示项目';
	@override String get animations => '动画';
	@override String get animationsDescription => '启用过渡和滚动动画';
	@override String get showHeroSection => '显示主要精选区';
	@override String get useGlobalHubs => '使用主页布局';
	@override String get useGlobalHubsDescription => '显示与官方 Jellyfin 客户端相同的主页推荐。关闭时将显示按媒体库分类的推荐。';
	@override String get showServerNameOnHubs => '在推荐栏显示服务器名称';
	@override String get showServerNameOnHubsDescription => '始终在推荐栏标题中显示服务器名称。关闭时仅在推荐栏名称重复时显示。';
	@override String get showJellyfinRecommendations => '电影推荐';
	@override String get showJellyfinRecommendationsDescription => '在电影库的“推荐”标签页中显示“因为您观看过”等推荐行。在服务器行为改进前默认关闭。';
	@override String get alwaysKeepSidebarOpen => '始终保持侧边栏展开';
	@override String get alwaysKeepSidebarOpenDescription => '侧边栏保持展开状态，内容区域自动调整';
	@override String get showUnwatchedCount => '显示未观看数量';
	@override String get showUnwatchedCountDescription => '在剧集和季上显示未观看的集数';
	@override String get playerBackend => '播放器引擎';
	@override String get exoPlayer => 'ExoPlayer（推荐）';
	@override String get exoPlayerDescription => 'Android 原生播放器，硬件支持更好';
	@override String get mpv => 'MPV';
	@override String get mpvDescription => '功能更多的高级播放器，支持 ASS 字幕';
	@override String get liveTvPlayer => '直播电视播放器';
	@override String get liveTvPlayerDescription => '直播电视推荐使用 MPV。ExoPlayer 在某些设备上可能有问题。';
	@override String get liveTvMpv => 'MPV (Recommended)';
	@override String get liveTvExoPlayer => 'ExoPlayer';
	@override String get liveTvQuality => '直播电视画质';
	@override String get liveTvQualityDescription => '限制直播电视的转码画质。不限制则使用服务器默认。';
	@override String get liveTvQualityNone => '不限制';
	@override String get streamingQuality => '流媒体画质';
	@override String get streamingQualityDescription => '限制VOD转码画质。自动由服务器决定。';
	@override String get hardwareDecoding => '硬件解码';
	@override String get hardwareDecodingDescription => '如果可用，使用硬件加速';
	@override String get bufferSize => '缓冲区大小';
	@override String bufferSizeMB({required Object size}) => '${size}MB';
	@override String get subtitleStyling => '字幕样式';
	@override String get subtitleStylingDescription => '调整字幕外观';
	@override String get smallSkipDuration => '短跳过时长';
	@override String get largeSkipDuration => '长跳过时长';
	@override String secondsUnit({required Object seconds}) => '${seconds} 秒';
	@override String get defaultSleepTimer => '默认睡眠定时器';
	@override String minutesUnit({required Object minutes}) => '${minutes} 分钟';
	@override String get rememberTrackSelections => '记住每个剧集/电影的音轨选择';
	@override String get rememberTrackSelectionsDescription => '在播放过程中更改音轨时自动保存音频和字幕语言偏好';
	@override String get clickVideoTogglesPlayback => '点击视频可切换播放/暂停';
	@override String get clickVideoTogglesPlaybackDescription => '如果启用此选项，点击视频播放器将播放或暂停视频。否则，点击将显示或隐藏播放控件';
	@override String get videoPlayerControls => '视频播放器键盘控制';
	@override String get keyboardShortcuts => '键盘快捷键';
	@override String get keyboardShortcutsDescription => '自定义键盘快捷键';
	@override String get videoPlayerNavigation => '键盘视频播放器导航';
	@override String get videoPlayerNavigationDescription => '使用方向键导航视频播放器控件';
	@override String get debugLogging => '调试日志';
	@override String get debugLoggingDescription => '启用详细日志记录以便故障排除';
	@override String get viewLogs => '查看日志';
	@override String get viewLogsDescription => '查看应用程序日志';
	@override String get clearCache => '清除缓存';
	@override String get clearCacheDescription => '这将清除所有缓存的图片和数据。清除缓存后，应用程序加载内容可能会变慢。';
	@override String get clearCacheSuccess => '缓存清除成功';
	@override String get resetSettings => '重置设置';
	@override String get resetSettingsDescription => '这会将所有设置重置为其默认值。此操作无法撤销。';
	@override String get resetSettingsSuccess => '设置重置成功';
	@override String get shortcutsReset => '快捷键已重置为默认值';
	@override String get about => '关于';
	@override String get aboutDescription => '应用程序信息和许可证';
	@override String get updates => '更新';
	@override String get updateAvailable => '有可用更新';
	@override String get checkForUpdates => '检查更新';
	@override String get validationErrorEnterNumber => '请输入一个有效的数字';
	@override String validationErrorDuration({required Object min, required Object max, required Object unit}) => '时长必须介于 ${min} 和 ${max} ${unit} 之间';
	@override String shortcutAlreadyAssigned({required Object action}) => '快捷键已被分配给 ${action}';
	@override String shortcutUpdated({required Object action}) => '快捷键已为 ${action} 更新';
	@override String get autoSkip => '自动跳过';
	@override String get autoSkipIntro => '自动跳过片头';
	@override String get autoSkipIntroDescription => '几秒钟后自动跳过片头标记';
	@override String get enableExternalSubtitles => 'Enable External Subtitles';
	@override String get enableExternalSubtitlesDescription => 'Show external subtitle options in the player; they load when you select one.';
	@override String get alwaysBurnInSubtitleWhenTranscoding => '转码时烧录字幕';
	@override String get alwaysBurnInSubtitleWhenTranscodingDescription => '转码时将所选字幕烧录到视频中。与 jellyfin-web 相同。';
	@override String get enableTrickplay => 'Enable trickplay thumbnails';
	@override String get enableTrickplayDescription => 'Show timeline scrub thumbnails when seeking. Requires trickplay data on the server.';
	@override String get enableChapterImages => 'Enable Chapter Images';
	@override String get enableChapterImagesDescription => 'Show thumbnail images for chapters in the chapter list.';
	@override String get autoSkipOutro => '自动跳过片尾';
	@override String get autoSkipOutroDescription => '自动跳过片尾片段';
	@override String get autoSkipRecap => '自动跳过回顾';
	@override String get autoSkipRecapDescription => '自动跳过回顾片段';
	@override String get autoSkipPreview => '自动跳过预告';
	@override String get autoSkipPreviewDescription => '自动跳过预告片段';
	@override String get autoSkipCommercial => '自动跳过广告';
	@override String get autoSkipCommercialDescription => '自动跳过广告片段';
	@override String get autoSkipDelay => '自动跳过延迟';
	@override String autoSkipDelayDescription({required Object seconds}) => '自动跳过前等待 ${seconds} 秒';
	@override String get showDownloads => 'Show Downloads';
	@override String get showDownloadsDescription => 'Show the Downloads section in the navigation menu';
	@override String get downloads => '下载';
	@override String get downloadLocationDescription => '选择下载内容的存储位置';
	@override String get downloadLocationDefault => '默认（应用存储）';
	@override String get downloadsDefault => '下载默认（应用存储）';
	@override String get libraryOrder => '媒体库管理';
	@override String get downloadLocationCustom => '自定义位置';
	@override String get selectFolder => '选择文件夹';
	@override String get resetToDefault => '重置为默认';
	@override String currentPath({required Object path}) => '当前: ${path}';
	@override String get downloadLocationChanged => '下载位置已更改';
	@override String get downloadLocationReset => '下载位置已重置为默认';
	@override String get downloadLocationInvalid => '所选文件夹不可写入';
	@override String get downloadLocationSelectError => '选择文件夹失败';
	@override String get downloadOnWifiOnly => '仅在 WiFi 时下载';
	@override String get downloadOnWifiOnlyDescription => '使用蜂窝数据时禁止下载';
	@override String get downloadQuality => '下载质量';
	@override String get downloadQualityDescription => '离线下载质量。原始保留源文件；其他选项转码以节省空间。';
	@override String get downloadQualityOriginal => '原始';
	@override String get downloadQualityOriginalDescription => '使用原文件。';
	@override String get playbackModeAutoDescription => '由服务器决定。';
	@override String get playbackModeAuto => '自动';
	@override String get playbackModeAutoDirect => '自动 - Direct';
	@override String get playbackModeDirectPlayDescription => '使用原文件。';
	@override String get playbackModeDirectPlay => 'Direct';
	@override String get quality15Mbps => '15 Mbps';
	@override String get quality10Mbps => '10 Mbps';
	@override String get quality8Mbps => '8 Mbps';
	@override String get quality6Mbps => '6 Mbps';
	@override String get quality4Mbps => '4 Mbps';
	@override String get quality3Mbps => '3 Mbps';
	@override String get quality1_5Mbps => '1.5 Mbps';
	@override String get quality720kbps => '720 kbps';
	@override String get quality420kbps => '420 kbps';
	@override String get cellularDownloadBlocked => '蜂窝数据下已禁用下载。请连接 WiFi 或更改设置。';
	@override String get maxVolume => '最大音量';
	@override String get maxVolumeDescription => '允许音量超过 100% 以适应安静的媒体';
	@override String maxVolumePercent({required Object percent}) => '${percent}%';
	@override String get matchContentFrameRate => '匹配内容帧率';
	@override String get matchContentFrameRateDescription => '调整显示刷新率以匹配视频内容，减少画面抖动并节省电量';
	@override String get requireProfileSelectionOnOpen => '打开应用时询问配置文件';
	@override String get requireProfileSelectionOnOpenDescription => '每次打开应用时显示配置文件选择';
	@override String get confirmExitOnBack => '退出前确认';
	@override String get confirmExitOnBackDescription => '按返回键退出应用时显示确认对话框';
	@override String get performance => '性能';
	@override String get performanceImageQuality => '图像质量';
	@override String get performanceImageQualityDescription => '较低质量加载更快。小 = 最快，大 = 最佳质量。';
	@override String get performancePosterSize => '海报大小';
	@override String get performancePosterSizeDescription => '网格中海报卡片的大小。小 = 更多项目，大 = 更大卡片。';
	@override String get performanceDisableAnimations => '禁用动画';
	@override String get performanceDisableAnimationsDescription => '关闭所有过渡以获得更灵敏的导航';
	@override String get performanceGridPreload => '网格预加载';
	@override String get performanceGridPreloadDescription => '加载多少屏幕外项目。低 = 更快，高 = 更流畅的滚动。';
	@override String get performanceSmall => '小';
	@override String get performanceMedium => '中';
	@override String get performanceLarge => '大';
	@override String get performanceLow => '低';
	@override String get performanceHigh => '高';
	@override String get hideSupportDevelopment => '隐藏支持开发';
	@override String get hideSupportDevelopmentDescription => '在设置中隐藏支持开发部分';
}

// Path: search
class _TranslationsSearchZh implements TranslationsSearchEn {
	_TranslationsSearchZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get hint => '搜索电影、系列、音乐...';
	@override String get tryDifferentTerm => '尝试不同的搜索词';
	@override String get searchYourMedia => '搜索媒体';
	@override String get enterTitleActorOrKeyword => '输入标题、演员或关键词';
	@override late final _TranslationsSearchCategoriesZh categories = _TranslationsSearchCategoriesZh._(_root);
}

// Path: hotkeys
class _TranslationsHotkeysZh implements TranslationsHotkeysEn {
	_TranslationsHotkeysZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String setShortcutFor({required Object actionName}) => '为 ${actionName} 设置快捷键';
	@override String get clearShortcut => '清除快捷键';
	@override late final _TranslationsHotkeysActionsZh actions = _TranslationsHotkeysActionsZh._(_root);
}

// Path: pinEntry
class _TranslationsPinEntryZh implements TranslationsPinEntryEn {
	_TranslationsPinEntryZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get enterPin => '输入 PIN';
	@override String get showPin => '显示 PIN';
	@override String get hidePin => '隐藏 PIN';
}

// Path: fileInfo
class _TranslationsFileInfoZh implements TranslationsFileInfoEn {
	_TranslationsFileInfoZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '文件信息';
	@override String get video => '视频';
	@override String get audio => '音频';
	@override String get file => '文件';
	@override String get advanced => '高级';
	@override String get codec => '编解码器';
	@override String get resolution => '分辨率';
	@override String get bitrate => '比特率';
	@override String get frameRate => '帧率';
	@override String get aspectRatio => '宽高比';
	@override String get profile => '配置文件';
	@override String get bitDepth => '位深度';
	@override String get colorSpace => '色彩空间';
	@override String get colorRange => '色彩范围';
	@override String get colorPrimaries => '颜色原色';
	@override String get chromaSubsampling => '色度子采样';
	@override String get channels => '声道';
	@override String get path => '路径';
	@override String get size => '大小';
	@override String get container => '容器';
	@override String get duration => '时长';
	@override String get optimizedForStreaming => '已优化用于流媒体';
	@override String get has64bitOffsets => '64位偏移量';
}

// Path: mediaMenu
class _TranslationsMediaMenuZh implements TranslationsMediaMenuEn {
	_TranslationsMediaMenuZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get markAsWatched => '标记为已观看';
	@override String get markAsUnwatched => '标记为未观看';
	@override String get goToSeries => '转到系列';
	@override String get goToSeason => '转到季';
	@override String get shufflePlay => '随机播放';
	@override String get fileInfo => '文件信息';
	@override String get confirmDelete => '确定要从文件系统中删除此项吗？';
	@override String get deleteMultipleWarning => '可能会删除多个项目。';
	@override String get mediaDeletedSuccessfully => '媒体项已成功删除';
	@override String get mediaFailedToDelete => '删除媒体项失败';
	@override String get rate => '评分';
}

// Path: accessibility
class _TranslationsAccessibilityZh implements TranslationsAccessibilityEn {
	_TranslationsAccessibilityZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String mediaCardMovie({required Object title}) => '${title}, 电影';
	@override String mediaCardShow({required Object title}) => '${title}, 电视剧';
	@override String mediaCardEpisode({required Object title, required Object episodeInfo}) => '${title}, ${episodeInfo}';
	@override String mediaCardSeason({required Object title, required Object seasonInfo}) => '${title}, ${seasonInfo}';
	@override String get mediaCardWatched => '已观看';
	@override String mediaCardPartiallyWatched({required Object percent}) => '已观看 ${percent} 百分比';
	@override String get mediaCardUnwatched => '未观看';
	@override String get tapToPlay => '点击播放';
}

// Path: tooltips
class _TranslationsTooltipsZh implements TranslationsTooltipsEn {
	_TranslationsTooltipsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get shufflePlay => '随机播放';
	@override String get playTrailer => '播放预告片';
	@override String get playFromStart => '从头播放';
	@override String get markAsWatched => '标记为已观看';
	@override String get markAsUnwatched => '标记为未观看';
}

// Path: videoControls
class _TranslationsVideoControlsZh implements TranslationsVideoControlsEn {
	_TranslationsVideoControlsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get audioLabel => '音频';
	@override String get subtitlesLabel => '字幕';
	@override String get resetToZero => '重置为 0ms';
	@override String addTime({required Object amount, required Object unit}) => '+${amount}${unit}';
	@override String minusTime({required Object amount, required Object unit}) => '-${amount}${unit}';
	@override String playsLater({required Object label}) => '${label} 播放较晚';
	@override String playsEarlier({required Object label}) => '${label} 播放较早';
	@override String get noOffset => '无偏移';
	@override String get letterbox => '信箱模式（Letterbox）';
	@override String get fillScreen => '填充屏幕';
	@override String get stretch => '拉伸';
	@override String get lockRotation => '锁定旋转';
	@override String get unlockRotation => '解锁旋转';
	@override String get timerActive => '定时器已激活';
	@override String playbackWillPauseIn({required Object duration}) => '播放将在 ${duration} 后暂停';
	@override String get sleepTimerCompleted => '睡眠定时器已完成 - 播放已暂停';
	@override String get autoPlayNext => '自动播放下一集';
	@override String get playNext => '播放下一集';
	@override String get playButton => '播放';
	@override String get pauseButton => '暂停';
	@override String seekBackwardButton({required Object seconds}) => '后退 ${seconds} 秒';
	@override String seekForwardButton({required Object seconds}) => '前进 ${seconds} 秒';
	@override String get previousButton => '上一集';
	@override String get nextButton => '下一集';
	@override String get previousChapterButton => '上一章节';
	@override String get nextChapterButton => '下一章节';
	@override String get muteButton => '静音';
	@override String get unmuteButton => '取消静音';
	@override String get settingsButton => '视频设置';
	@override String get audioTrackButton => '音轨';
	@override String get subtitlesButton => '字幕';
	@override String get chaptersButton => '章节';
	@override String get versionsButton => '视频版本';
	@override String get pipButton => '画中画模式';
	@override String get aspectRatioButton => '宽高比';
	@override String get ambientLighting => '氛围灯光';
	@override String get ambientLightingOn => '开启氛围灯光';
	@override String get ambientLightingOff => '关闭氛围灯光';
	@override String get fullscreenButton => '进入全屏';
	@override String get exitFullscreenButton => '退出全屏';
	@override String get alwaysOnTopButton => '置顶窗口';
	@override String get rotationLockButton => '旋转锁定';
	@override String get timelineSlider => '视频时间轴';
	@override String get volumeSlider => '音量调节';
	@override String endsAt({required Object time}) => '${time} 结束';
	@override String get pipFailed => '画中画启动失败';
	@override late final _TranslationsVideoControlsPipErrorsZh pipErrors = _TranslationsVideoControlsPipErrorsZh._(_root);
	@override String get chapters => '章节';
	@override String get noChaptersAvailable => '没有可用的章节';
}

// Path: userStatus
class _TranslationsUserStatusZh implements TranslationsUserStatusEn {
	_TranslationsUserStatusZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get admin => '管理员';
	@override String get restricted => '受限';
	@override String get protected => '受保护';
	@override String get current => '当前';
}

// Path: messages
class _TranslationsMessagesZh implements TranslationsMessagesEn {
	_TranslationsMessagesZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get markedAsWatched => '已标记为已观看';
	@override String get markedAsUnwatched => '已标记为未观看';
	@override String get markedAsWatchedOffline => '已标记为已观看 (将在联网时同步)';
	@override String get markedAsUnwatchedOffline => '已标记为未观看 (将在联网时同步)';
	@override String errorLoading({required Object error}) => '错误: ${error}';
	@override String get fileInfoNotAvailable => '文件信息不可用';
	@override String errorLoadingFileInfo({required Object error}) => '加载文件信息时出错: ${error}';
	@override String get errorLoadingSeries => '加载系列时出错';
	@override String get errorLoadingSeason => '加载季时出错';
	@override String get musicNotSupported => '尚不支持播放音乐';
	@override String get logsCleared => '日志已清除';
	@override String get logsCopied => '日志已复制到剪贴板';
	@override String get noLogsAvailable => '没有可用日志';
	@override String libraryScanning({required Object title}) => '正在扫描 “${title}”...';
	@override String libraryScanStarted({required Object title}) => '已开始扫描 “${title}” 媒体库';
	@override String libraryScanFailed({required Object error}) => '无法扫描媒体库: ${error}';
	@override String metadataRefreshing({required Object title}) => '正在刷新 “${title}” 的元数据...';
	@override String metadataRefreshStarted({required Object title}) => '已开始刷新 “${title}” 的元数据';
	@override String metadataRefreshFailed({required Object error}) => '无法刷新元数据: ${error}';
	@override String get logoutConfirm => '你确定要登出吗？';
	@override String get noSeasonsFound => '未找到季';
	@override String get noEpisodesFound => '在第一季中未找到剧集';
	@override String get noEpisodesFoundGeneral => '未找到剧集';
	@override String get noResultsFound => '未找到结果';
	@override String sleepTimerSet({required Object label}) => '睡眠定时器已设置为 ${label}';
	@override String get noItemsAvailable => '没有可用的项目';
	@override String get failedToCreatePlayQueueNoItems => '创建播放队列失败 - 没有项目';
	@override String failedPlayback({required Object action, required Object error}) => '无法${action}: ${error}';
	@override String get switchingToCompatiblePlayer => '正在切换到兼容的播放器...';
	@override String get qualityRevertedOnError => '因播放错误已恢复为之前的画质。';
}

// Path: subtitlingStyling
class _TranslationsSubtitlingStylingZh implements TranslationsSubtitlingStylingEn {
	_TranslationsSubtitlingStylingZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get stylingOptions => '样式选项';
	@override String get fontSize => '字号';
	@override String get textColor => '文本颜色';
	@override String get borderSize => '边框大小';
	@override String get borderColor => '边框颜色';
	@override String get backgroundOpacity => '背景不透明度';
	@override String get backgroundColor => '背景颜色';
	@override String get position => 'Position';
}

// Path: mpvConfig
class _TranslationsMpvConfigZh implements TranslationsMpvConfigEn {
	_TranslationsMpvConfigZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'MPV 配置';
	@override String get description => '高级视频播放器设置';
	@override String get properties => '属性';
	@override String get presets => '预设';
	@override String get noProperties => '未配置任何属性';
	@override String get noPresets => '没有保存的预设';
	@override String get addProperty => '添加属性';
	@override String get editProperty => '编辑属性';
	@override String get deleteProperty => '删除属性';
	@override String get propertyKey => '属性键';
	@override String get propertyKeyHint => '例如 hwdec, demuxer-max-bytes';
	@override String get propertyValue => '属性值';
	@override String get propertyValueHint => '例如 auto, 256000000';
	@override String get saveAsPreset => '保存为预设...';
	@override String get presetName => '预设名称';
	@override String get presetNameHint => '输入此预设的名称';
	@override String get loadPreset => '加载';
	@override String get deletePreset => '删除';
	@override String get presetSaved => '预设已保存';
	@override String get presetLoaded => '预设已加载';
	@override String get presetDeleted => '预设已删除';
	@override String get confirmDeletePreset => '确定要删除此预设吗？';
	@override String get confirmDeleteProperty => '确定要删除此属性吗？';
	@override String entriesCount({required Object count}) => '${count} 条目';
}

// Path: dialog
class _TranslationsDialogZh implements TranslationsDialogEn {
	_TranslationsDialogZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get confirmAction => '确认操作';
}

// Path: discover
class _TranslationsDiscoverZh implements TranslationsDiscoverEn {
	_TranslationsDiscoverZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '发现';
	@override String get switchProfile => '切换用户';
	@override String get noContentAvailable => '没有可用内容';
	@override String get addMediaToLibraries => '请向你的媒体库添加一些媒体';
	@override String get continueWatching => '继续观看';
	@override String playEpisode({required Object season, required Object episode}) => 'S${season}E${episode}';
	@override String get overview => '概述';
	@override String get cast => '演员表';
	@override String get moreLikeThis => '相似推荐';
	@override String get moviesAndShows => 'Movies & Shows';
	@override String get noItemsFound => 'No items found on this server';
	@override String get extras => '预告片与花絮';
	@override String get seasons => '季数';
	@override String get studio => '制作公司';
	@override String get rating => '年龄分级';
	@override String episodeCount({required Object count}) => '${count} 集';
	@override String watchedProgress({required Object watched, required Object total}) => '已观看 ${watched}/${total} 集';
	@override String get movie => '电影';
	@override String get tvShow => '电视剧';
	@override String minutesLeft({required Object minutes}) => '剩余 ${minutes} 分钟';
}

// Path: errors
class _TranslationsErrorsZh implements TranslationsErrorsEn {
	_TranslationsErrorsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String searchFailed({required Object error}) => '搜索失败: ${error}';
	@override String connectionTimeout({required Object context}) => '加载 ${context} 时连接超时';
	@override String get connectionFailed => '无法连接到 Jellyfin 服务器';
	@override String failedToLoad({required Object context, required Object error}) => '无法加载 ${context}: ${error}';
	@override String get noClientAvailable => '没有可用客户端';
	@override String authenticationFailed({required Object error}) => '验证失败: ${error}';
	@override String get couldNotLaunchUrl => '无法打开授权 URL';
	@override String get pleaseEnterToken => '请输入一个令牌';
	@override String get invalidToken => '令牌无效';
	@override String failedToVerifyToken({required Object error}) => '无法验证令牌: ${error}';
	@override String failedToSwitchProfile({required Object displayName}) => '无法切换到 ${displayName}';
}

// Path: libraries
class _TranslationsLibrariesZh implements TranslationsLibrariesEn {
	_TranslationsLibrariesZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '媒体库';
	@override String get scanLibraryFiles => '扫描媒体库文件';
	@override String get scanLibrary => '扫描媒体库';
	@override String get analyze => '分析';
	@override String get analyzeLibrary => '分析媒体库';
	@override String get refreshMetadata => '刷新元数据';
	@override String get emptyTrash => '清空回收站';
	@override String emptyingTrash({required Object title}) => '正在清空 “${title}” 的回收站...';
	@override String trashEmptied({required Object title}) => '已清空 “${title}” 的回收站';
	@override String failedToEmptyTrash({required Object error}) => '无法清空回收站: ${error}';
	@override String analyzing({required Object title}) => '正在分析 “${title}”...';
	@override String analysisStarted({required Object title}) => '已开始分析 “${title}”';
	@override String failedToAnalyze({required Object error}) => '无法分析媒体库: ${error}';
	@override String get noLibrariesFound => '未找到媒体库';
	@override String get thisLibraryIsEmpty => '此媒体库为空';
	@override String get all => '全部';
	@override String get clearAll => '全部清除';
	@override String scanLibraryConfirm({required Object title}) => '确定要扫描 “${title}” 吗？';
	@override String analyzeLibraryConfirm({required Object title}) => '确定要分析 “${title}” 吗？';
	@override String refreshMetadataConfirm({required Object title}) => '确定要刷新 “${title}” 的元数据吗？';
	@override String emptyTrashConfirm({required Object title}) => '确定要清空 “${title}” 的回收站吗？';
	@override String get manageLibraries => '管理媒体库';
	@override String get sort => '排序';
	@override String get sortBy => '排序依据';
	@override String get filters => '筛选器';
	@override String get confirmActionMessage => '确定要执行此操作吗？';
	@override String get showLibrary => '显示媒体库';
	@override String get hideLibrary => '隐藏媒体库';
	@override String get libraryOptions => '媒体库选项';
	@override String get content => '媒体库内容';
	@override String get selectLibrary => '选择媒体库';
	@override String filtersWithCount({required Object count}) => '筛选器（${count}）';
	@override String get noRecommendations => '暂无推荐';
	@override String get noCollections => '此媒体库中没有合集';
	@override String get noFavorites => '此媒体库中无收藏';
	@override String get noGenres => '此媒体库中无类型';
	@override String get noFoldersFound => '未找到文件夹';
	@override String get folders => '文件夹';
	@override late final _TranslationsLibrariesTabsZh tabs = _TranslationsLibrariesTabsZh._(_root);
	@override late final _TranslationsLibrariesGroupingsZh groupings = _TranslationsLibrariesGroupingsZh._(_root);
}

// Path: about
class _TranslationsAboutZh implements TranslationsAboutEn {
	_TranslationsAboutZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '关于';
	@override String get openSourceLicenses => '开源许可证';
	@override String versionLabel({required Object version}) => '版本 ${version}';
	@override String get appDescription => '一款精美的 Flutter Jellyfin 客户端';
	@override String get viewLicensesDescription => '查看第三方库的许可证';
}

// Path: serverSelection
class _TranslationsServerSelectionZh implements TranslationsServerSelectionEn {
	_TranslationsServerSelectionZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get allServerConnectionsFailed => '无法连接到任何服务器。请检查你的网络并重试。';
	@override String noServersFoundForAccount({required Object username, required Object email}) => '未找到 ${username} (${email}) 的服务器';
	@override String failedToLoadServers({required Object error}) => '无法加载服务器: ${error}';
}

// Path: hubDetail
class _TranslationsHubDetailZh implements TranslationsHubDetailEn {
	_TranslationsHubDetailZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '标题';
	@override String get releaseYear => '发行年份';
	@override String get dateAdded => '添加日期';
	@override String get rating => '评分';
	@override String get noItemsFound => '未找到项目';
}

// Path: logs
class _TranslationsLogsZh implements TranslationsLogsEn {
	_TranslationsLogsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get clearLogs => '清除日志';
	@override String get copyLogs => '复制日志';
	@override String get error => '错误:';
	@override String get stackTrace => '堆栈跟踪 (Stack Trace):';
}

// Path: licenses
class _TranslationsLicensesZh implements TranslationsLicensesEn {
	_TranslationsLicensesZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get relatedPackages => '相关软件包';
	@override String get license => '许可证';
	@override String licenseNumber({required Object number}) => '许可证 ${number}';
	@override String licensesCount({required Object count}) => '${count} 个许可证';
}

// Path: navigation
class _TranslationsNavigationZh implements TranslationsNavigationEn {
	_TranslationsNavigationZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get libraries => '媒体库';
	@override String get downloads => '下载';
	@override String get liveTv => '电视直播';
}

// Path: liveTv
class _TranslationsLiveTvZh implements TranslationsLiveTvEn {
	_TranslationsLiveTvZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '电视直播';
	@override String get channels => '频道';
	@override String get guide => '节目指南';
	@override String get recordings => '录制';
	@override String get subscriptions => '录制规则';
	@override String get scheduled => '已计划';
	@override String get seriesTimers => 'Series Timers';
	@override String get noChannels => '没有可用的频道';
	@override String get dvr => 'DVR';
	@override String get noDvr => '没有服务器配置了DVR';
	@override String get tuneFailed => '无法调谐频道';
	@override String get loading => '正在加载频道...';
	@override String get nowPlaying => '正在播放';
	@override String get record => '录制';
	@override String get recordSeries => '录制系列';
	@override String get cancelRecording => '取消录制';
	@override String get deleteSubscription => '删除录制规则';
	@override String get deleteSubscriptionConfirm => '确定要删除此录制规则吗？';
	@override String get subscriptionDeleted => '录制规则已删除';
	@override String get noPrograms => '没有可用的节目数据';
	@override String get noRecordings => 'No recordings';
	@override String get noScheduled => 'No scheduled recordings';
	@override String get noSubscriptions => 'No series timers';
	@override String get cancelTimer => 'Cancel Recording';
	@override String get cancelTimerConfirm => 'Are you sure you want to cancel this scheduled recording?';
	@override String get timerCancelled => 'Recording cancelled';
	@override String get editSeriesTimer => '编辑';
	@override String get deleteSeriesTimer => 'Delete Series Timer';
	@override String get deleteSeriesTimerConfirm => 'Are you sure you want to delete this series timer? All associated scheduled recordings will also be removed.';
	@override String get seriesTimerDeleted => 'Series timer deleted';
	@override String get seriesTimerUpdated => 'Series timer updated';
	@override String get recordNewOnly => 'Record new episodes only';
	@override String get keepUpTo => 'Keep up to';
	@override String get keepAll => 'Keep all';
	@override String keepEpisodes({required Object count}) => '${count} episodes';
	@override String get prePadding => 'Start recording early';
	@override String get postPadding => 'Continue recording after';
	@override String minutes({required Object count}) => '${count} min';
	@override String get days => 'Days';
	@override String get priority => 'Priority';
	@override String channelNumber({required Object number}) => '频道 ${number}';
	@override String get live => '直播';
	@override String get hd => '高清';
	@override String get premiere => '新';
	@override String get reloadGuide => '重新加载节目指南';
	@override String get guideReloaded => '节目指南已重新加载';
	@override String get allChannels => '所有频道';
	@override String get now => '现在';
	@override String get today => '今天';
	@override String get midnight => '午夜';
	@override String get overnight => '凌晨';
	@override String get morning => '上午';
	@override String get daytime => '白天';
	@override String get evening => '晚上';
	@override String get lateNight => '深夜';
	@override String get programs => 'Programs';
	@override String get onNow => 'On Now';
	@override String get upcomingShows => 'Shows';
	@override String get upcomingMovies => 'Movies';
	@override String get upcomingSports => 'Sports';
	@override String get forKids => 'For Kids';
	@override String get upcomingNews => 'News';
	@override String get watchChannel => '观看频道';
	@override String get recentlyAdded => 'Recently Added';
	@override String get recordingScheduled => 'Recording scheduled';
	@override String get seriesRecordingScheduled => 'Series recording scheduled';
	@override String get recordingFailed => 'Failed to schedule recording';
	@override String get cancelSeries => 'Cancel Series';
	@override String get stopRecording => 'Stop Recording';
	@override String get doNotRecord => 'Do Not Record';
}

// Path: downloads
class _TranslationsDownloadsZh implements TranslationsDownloadsEn {
	_TranslationsDownloadsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '下载';
	@override String get manage => '管理';
	@override String get tvShows => '电视剧';
	@override String get movies => '电影';
	@override String get noDownloads => '暂无下载';
	@override String get noDownloadsDescription => '下载的内容将在此处显示以供离线观看';
	@override String get downloadNow => '下载';
	@override String get deleteDownload => '删除下载';
	@override String get retryDownload => '重试下载';
	@override String get downloadQueued => '下载已排队';
	@override String get downloadStarting => '正在启动...';
	@override String episodesQueued({required Object count}) => '${count} 集已加入下载队列';
	@override String get downloadDeleted => '下载已删除';
	@override String deleteConfirm({required Object title}) => '确定要删除 "${title}" 吗？下载的文件将从您的设备中删除。';
	@override String deletingWithProgress({required Object title, required Object current, required Object total}) => '正在删除 ${title}... (${current}/${total})';
	@override String get noDownloadsTree => '暂无下载';
	@override String get pauseAll => '全部暂停';
	@override String get resumeAll => '全部继续';
	@override String get deleteAll => '全部删除';
}

// Path: playlists
class _TranslationsPlaylistsZh implements TranslationsPlaylistsEn {
	_TranslationsPlaylistsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '播放列表';
	@override String get noPlaylists => '未找到播放列表';
	@override String get create => '创建播放列表';
	@override String get playlistName => '播放列表名称';
	@override String get enterPlaylistName => '输入播放列表名称';
	@override String get delete => '删除播放列表';
	@override String get removeItem => '从播放列表中移除';
	@override String get smartPlaylist => '智能播放列表';
	@override String itemCount({required Object count}) => '${count} 个项目';
	@override String get oneItem => '1 个项目';
	@override String get emptyPlaylist => '此播放列表为空';
	@override String get deleteConfirm => '删除播放列表？';
	@override String deleteMessage({required Object name}) => '确定要删除 "${name}" 吗？';
	@override String get created => '播放列表已创建';
	@override String get deleted => '播放列表已删除';
	@override String get itemAdded => '已添加到播放列表';
	@override String get itemRemoved => '已从播放列表中移除';
	@override String get selectPlaylist => '选择播放列表';
	@override String get createNewPlaylist => '创建新播放列表';
	@override String get errorCreating => '创建播放列表失败';
	@override String get errorDeleting => '删除播放列表失败';
	@override String get errorLoading => '加载播放列表失败';
	@override String get errorAdding => '添加到播放列表失败';
	@override String get errorReordering => '重新排序播放列表项目失败';
	@override String get errorRemoving => '从播放列表中移除失败';
	@override String get playlist => '播放列表';
	@override String get addToPlaylist => '添加到播放列表';
}

// Path: collections
class _TranslationsCollectionsZh implements TranslationsCollectionsEn {
	_TranslationsCollectionsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '合集';
	@override String get collection => '合集';
	@override String get addToCollection => '添加到合集';
	@override String get empty => '合集为空';
	@override String get unknownLibrarySection => '无法删除：未知的媒体库分区';
	@override String get deleteCollection => '删除合集';
	@override String deleteConfirm({required Object title}) => '确定要删除"${title}"吗？此操作无法撤销。';
	@override String get deleted => '已删除合集';
	@override String get deleteFailed => '删除合集失败';
	@override String deleteFailedWithError({required Object error}) => '删除合集失败：${error}';
	@override String failedToLoadItems({required Object error}) => '加载合集项目失败：${error}';
	@override String get selectCollection => '选择合集';
	@override String get createNewCollection => '创建新合集';
	@override String get collectionName => '合集名称';
	@override String get enterCollectionName => '输入合集名称';
	@override String get addedToCollection => '已添加到合集';
	@override String get errorAddingToCollection => '添加到合集失败';
	@override String get created => '已创建合集';
	@override String get removeFromCollection => '从合集移除';
	@override String removeFromCollectionConfirm({required Object title}) => '将“${title}”从此合集移除？';
	@override String get removedFromCollection => '已从合集移除';
	@override String get removeFromCollectionFailed => '从合集移除失败';
	@override String removeFromCollectionError({required Object error}) => '从合集移除时出错：${error}';
}

// Path: shaders
class _TranslationsShadersZh implements TranslationsShadersEn {
	_TranslationsShadersZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '着色器';
	@override String get noShaderDescription => '无视频增强';
	@override String get nvscalerDescription => 'NVIDIA 图像缩放，使视频更清晰';
	@override String get qualityFast => '快速';
	@override String get qualityHQ => '高质量';
	@override String get mode => '模式';
}

// Path: companionRemote
class _TranslationsCompanionRemoteZh implements TranslationsCompanionRemoteEn {
	_TranslationsCompanionRemoteZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'Companion Remote';
	@override String get connectToDevice => '连接到设备';
	@override String get hostRemoteSession => '创建远程会话';
	@override String get controlThisDevice => '使用手机控制此设备';
	@override String get remoteControl => '远程控制';
	@override String get controlDesktop => '控制桌面设备';
	@override String connectedTo({required Object name}) => '已连接到 ${name}';
	@override late final _TranslationsCompanionRemoteSessionZh session = _TranslationsCompanionRemoteSessionZh._(_root);
	@override late final _TranslationsCompanionRemotePairingZh pairing = _TranslationsCompanionRemotePairingZh._(_root);
	@override late final _TranslationsCompanionRemoteRemoteZh remote = _TranslationsCompanionRemoteRemoteZh._(_root);
}

// Path: videoSettings
class _TranslationsVideoSettingsZh implements TranslationsVideoSettingsEn {
	_TranslationsVideoSettingsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get playbackSettings => '播放设置';
	@override String get quality => '画质';
	@override String get qualityDescription => '流媒体画质。自动由服务器决定。';
	@override String get playbackSpeed => '播放速度';
	@override String get sleepTimer => '睡眠定时器';
	@override String get audioSync => '音频同步';
	@override String get subtitleSync => '字幕同步';
	@override String get hdr => 'HDR';
	@override String get audioOutput => '音频输出';
	@override String get performanceOverlay => '性能监控';
}

// Path: externalPlayer
class _TranslationsExternalPlayerZh implements TranslationsExternalPlayerEn {
	_TranslationsExternalPlayerZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '外部播放器';
	@override String get useExternalPlayer => '使用外部播放器';
	@override String get useExternalPlayerDescription => '在外部应用中打开视频，而不是使用内置播放器';
	@override String get selectPlayer => '选择播放器';
	@override String get systemDefault => '系统默认';
	@override String get addCustomPlayer => '添加自定义播放器';
	@override String get playerName => '播放器名称';
	@override String get playerCommand => '命令';
	@override String get playerPackage => '包名';
	@override String get playerUrlScheme => 'URL 方案';
	@override String get customPlayer => '自定义播放器';
	@override String get off => '关闭';
	@override String get launchFailed => '无法打开外部播放器';
	@override String appNotInstalled({required Object name}) => '${name} 未安装';
	@override String get playInExternalPlayer => '在外部播放器中播放';
}

// Path: search.categories
class _TranslationsSearchCategoriesZh implements TranslationsSearchCategoriesEn {
	_TranslationsSearchCategoriesZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get movies => 'Movies';
	@override String get shows => 'Shows';
	@override String get episodes => 'Episodes';
	@override String get people => 'People';
	@override String get collections => 'Collections';
	@override String get programs => 'Programs';
	@override String get channels => 'Channels';
}

// Path: hotkeys.actions
class _TranslationsHotkeysActionsZh implements TranslationsHotkeysActionsEn {
	_TranslationsHotkeysActionsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get playPause => '播放/暂停';
	@override String get volumeUp => '增大音量';
	@override String get volumeDown => '减小音量';
	@override String seekForward({required Object seconds}) => '快进 (${seconds}秒)';
	@override String seekBackward({required Object seconds}) => '快退 (${seconds}秒)';
	@override String get fullscreenToggle => '切换全屏';
	@override String get muteToggle => '切换静音';
	@override String get subtitleToggle => '切换字幕';
	@override String get audioTrackNext => '下一音轨';
	@override String get subtitleTrackNext => '下一字幕轨';
	@override String get chapterNext => '下一章节';
	@override String get chapterPrevious => '上一章节';
	@override String get speedIncrease => '加速';
	@override String get speedDecrease => '减速';
	@override String get speedReset => '重置速度';
	@override String get subSeekNext => '跳转到下一字幕';
	@override String get subSeekPrev => '跳转到上一字幕';
	@override String get shaderToggle => '切换着色器';
	@override String get skipMarker => '跳过片头/片尾';
}

// Path: videoControls.pipErrors
class _TranslationsVideoControlsPipErrorsZh implements TranslationsVideoControlsPipErrorsEn {
	_TranslationsVideoControlsPipErrorsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get androidVersion => '需要 Android 8.0 或更高版本';
	@override String get permissionDisabled => '画中画权限已禁用。请在设置 > 应用 > Finzy > 画中画中启用';
	@override String get notSupported => '此设备不支持画中画模式';
	@override String get failed => '画中画启动失败';
	@override String unknown({required Object error}) => '发生错误：${error}';
}

// Path: libraries.tabs
class _TranslationsLibrariesTabsZh implements TranslationsLibrariesTabsEn {
	_TranslationsLibrariesTabsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get movies => '电影';
	@override String get shows => '剧集';
	@override String get suggestions => '推荐';
	@override String get browse => '浏览';
	@override String get genres => '类型';
	@override String get favorites => '收藏';
	@override String get collections => '合集';
	@override String get playlists => '播放列表';
}

// Path: libraries.groupings
class _TranslationsLibrariesGroupingsZh implements TranslationsLibrariesGroupingsEn {
	_TranslationsLibrariesGroupingsZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get all => '全部';
	@override String get movies => '电影';
	@override String get shows => '剧集';
	@override String get seasons => '季';
	@override String get episodes => '集';
	@override String get folders => '文件夹';
}

// Path: companionRemote.session
class _TranslationsCompanionRemoteSessionZh implements TranslationsCompanionRemoteSessionEn {
	_TranslationsCompanionRemoteSessionZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get creatingSession => '正在创建远程会话...';
	@override String get failedToCreate => '创建远程会话失败：';
	@override String get noSession => '没有可用的会话';
	@override String get scanQrCode => '扫描 QR 码';
	@override String get orEnterManually => '或手动输入';
	@override String get hostAddress => '主机地址';
	@override String get sessionId => '会话 ID';
	@override String get pin => 'PIN';
	@override String get connected => '已连接';
	@override String get waitingForConnection => '等待连接中...';
	@override String get usePhoneToControl => '使用移动设备控制此应用';
	@override String copiedToClipboard({required Object label}) => '${label}已复制到剪贴板';
	@override String get copyToClipboard => '复制到剪贴板';
	@override String get newSession => '新建会话';
	@override String get minimize => '最小化';
}

// Path: companionRemote.pairing
class _TranslationsCompanionRemotePairingZh implements TranslationsCompanionRemotePairingEn {
	_TranslationsCompanionRemotePairingZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get recent => '最近';
	@override String get scan => '扫描';
	@override String get manual => '手动';
	@override String get recentConnections => '最近连接';
	@override String get quickReconnect => '快速重新连接之前配对的设备';
	@override String get pairWithDesktop => '与桌面配对';
	@override String get enterSessionDetails => '输入桌面设备上显示的会话信息';
	@override String get hostAddressHint => '192.168.1.100:48632';
	@override String get sessionIdHint => '输入8位会话 ID';
	@override String get pinHint => '输入6位 PIN';
	@override String get connecting => '连接中...';
	@override String get tips => '提示';
	@override String get tipDesktop => '在桌面上打开 Finzy，并从设置或菜单中启用 Companion Remote';
	@override String get tipScan => '使用扫描选项卡扫描桌面上的 QR 码以快速配对';
	@override String get tipWifi => '请确保两台设备连接到同一个 WiFi 网络';
	@override String get cameraPermissionRequired => '扫描 QR 码需要相机权限。\n请在设备设置中授予相机访问权限。';
	@override String cameraError({required Object error}) => '无法启动相机：${error}';
	@override String get scanInstruction => '将相机对准桌面上显示的 QR 码';
	@override String get noRecentConnections => '没有最近的连接';
	@override String get connectUsingManual => '使用手动输入连接设备以开始使用';
	@override String get invalidQrCode => '无效的 QR 码格式';
	@override String get removeRecentConnection => '删除最近连接';
	@override String removeConfirm({required Object name}) => '确定要从最近连接中删除 "${name}" 吗？';
	@override String get validationHostRequired => '请输入主机地址';
	@override String get validationHostFormat => '格式必须为 IP:端口（例如 192.168.1.100:48632）';
	@override String get validationSessionIdRequired => '请输入会话 ID';
	@override String get validationSessionIdLength => '会话 ID 必须为8个字符';
	@override String get validationPinRequired => '请输入 PIN';
	@override String get validationPinLength => 'PIN 必须为6位数字';
	@override String get connectionTimedOut => '连接超时。请检查会话 ID 和 PIN。';
	@override String get sessionNotFound => '找不到会话。请检查您的凭据。';
	@override String failedToConnect({required Object error}) => '连接失败：${error}';
	@override String failedToLoadRecent({required Object error}) => '加载最近会话失败：${error}';
}

// Path: companionRemote.remote
class _TranslationsCompanionRemoteRemoteZh implements TranslationsCompanionRemoteRemoteEn {
	_TranslationsCompanionRemoteRemoteZh._(this._root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get disconnectConfirm => '是否要断开远程会话的连接？';
	@override String get reconnecting => '重新连接中...';
	@override String attemptOf({required Object current}) => '第 ${current} 次尝试，共 5 次';
	@override String get retryNow => '立即重试';
	@override String get connectionError => '连接错误';
	@override String get notConnected => '未连接';
	@override String get tabRemote => '遥控';
	@override String get tabPlay => '播放';
	@override String get tabMore => '更多';
	@override String get menu => '菜单';
	@override String get tabNavigation => '标签导航';
	@override String get tabDiscover => '发现';
	@override String get tabLibraries => '媒体库';
	@override String get tabSearch => '搜索';
	@override String get tabDownloads => '下载';
	@override String get tabSettings => '设置';
	@override String get previous => '上一个';
	@override String get playPause => '播放/暂停';
	@override String get next => '下一个';
	@override String get seekBack => '后退';
	@override String get stop => '停止';
	@override String get seekForward => '快进';
	@override String get volume => '音量';
	@override String get volumeDown => '减小';
	@override String get volumeUp => '增大';
	@override String get fullscreen => '全屏';
	@override String get subtitles => '字幕';
	@override String get audio => '音频';
	@override String get searchHint => '在桌面上搜索...';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZh {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.title' => 'Finzy',
			'auth.signInWithJellyfin' => '使用 Jellyfin 登录',
			'auth.jellyfinServerUrl' => '服务器 URL',
			'auth.jellyfinServerUrlHint' => 'https://your-jellyfin.example.com',
			'auth.jellyfinUsername' => '用户名',
			'auth.jellyfinPassword' => '密码',
			'auth.jellyfinSignIn' => '登录',
			'auth.showQRCode' => '显示二维码',
			'auth.authenticate' => '验证',
			'auth.debugEnterToken' => '调试：输入 Jellyfin Token',
			'auth.authTokenLabel' => 'Jellyfin 授权令牌 (Auth Token)',
			'auth.authTokenHint' => '输入你的令牌',
			'auth.authenticationTimeout' => '验证超时。请重试。',
			'auth.sessionExpired' => '您的会话已过期。请重新登录。',
			'auth.connectionTimeout' => '连接超时。请检查网络后重试。',
			'auth.invalidPassword' => '用户名或密码错误。',
			'auth.notAuthorized' => '未授权。请重新登录。',
			'auth.serverUnreachable' => '无法连接服务器。请检查 URL 和网络连接。',
			'auth.serverError' => '服务器错误。请稍后重试。',
			'auth.scanQRToSignIn' => '扫描二维码登录',
			'auth.waitingForAuth' => '等待验证中...\n请在你的浏览器中完成登录。',
			'auth.useBrowser' => '使用浏览器',
			'common.cancel' => '取消',
			'common.save' => '保存',
			'common.close' => '关闭',
			'common.clear' => '清除',
			'common.reset' => '重置',
			'common.later' => '稍后',
			'common.submit' => '提交',
			'common.confirm' => '确认',
			'common.retry' => '重试',
			'common.logout' => '登出',
			'common.quickConnect' => 'Quick Connect',
			'common.quickConnectDescription' => 'To sign in with Quick Connect, select the \'Quick Connect\' button on the device you are logging in from and enter the displayed code below.',
			'common.quickConnectCode' => 'Quick Connect Code',
			'common.authorize' => 'Authorize',
			'common.quickConnectSuccess' => 'Quick Connect authorized successfully',
			'common.quickConnectError' => 'Failed to authorize Quick Connect code',
			'common.unknown' => '未知',
			'common.refresh' => '刷新',
			'common.yes' => '是',
			'common.no' => '否',
			'common.delete' => '删除',
			'common.shuffle' => '随机播放',
			'common.addTo' => '添加到...',
			'common.remove' => '删除',
			'common.paste' => '粘贴',
			'common.connect' => '连接',
			'common.disconnect' => '断开连接',
			'common.play' => '播放',
			'common.pause' => '暂停',
			'common.resume' => '继续',
			'common.error' => '错误',
			'common.search' => '搜索',
			'common.home' => '首页',
			'common.back' => '返回',
			'common.settings' => '设置',
			'common.mute' => '静音',
			'common.ok' => '确定',
			'common.none' => 'None',
			'common.loading' => '加载中...',
			'common.reconnect' => '重新连接',
			'common.goOffline' => '进入离线模式',
			'common.goOnline' => '返回在线',
			'common.connectionAvailable' => '连接可用',
			'common.exitConfirmTitle' => '退出应用？',
			'common.exitConfirmMessage' => '确定要退出吗？',
			'common.dontAskAgain' => '不再询问',
			'common.exit' => '退出',
			'common.viewAll' => '查看全部',
			'screens.licenses' => '许可证',
			'screens.switchProfile' => '切换用户',
			'screens.subtitleStyling' => '字幕样式',
			'screens.mpvConfig' => 'MPV 配置',
			'screens.logs' => '日志',
			'update.available' => '有可用更新',
			'update.versionAvailable' => ({required Object version}) => '版本 ${version} 已发布',
			'update.currentVersion' => ({required Object version}) => '当前版本: ${version}',
			'update.skipVersion' => '跳过此版本',
			'update.viewRelease' => '查看发布详情',
			'update.updateInStore' => '在应用商店更新',
			'update.latestVersion' => '已安装的版本是可用的最新版本',
			'update.checkFailed' => '无法检查更新',
			'settings.title' => '设置',
			'settings.supportOptionalCaption' => '可选——应用保持免费',
			'settings.supportTierSupport' => '支持开发',
			'settings.supportTipThankYou' => '感谢你的支持！',
			'settings.language' => '语言',
			'settings.theme' => '主题',
			'settings.appearance' => '外观',
			'settings.videoPlayback' => '视频播放',
			'settings.advanced' => '高级',
			'settings.episodePosterMode' => '剧集海报样式',
			'settings.seriesPoster' => '剧集海报',
			'settings.seriesPosterDescription' => '为所有剧集显示剧集海报',
			'settings.seasonPoster' => '季海报',
			'settings.seasonPosterDescription' => '为剧集显示特定季的海报',
			'settings.episodeThumbnail' => '剧集缩略图',
			'settings.episodeThumbnailDescription' => '显示16:9剧集截图缩略图',
			'settings.timeFormat' => '时间格式',
			'settings.system' => '系统',
			'settings.systemDescription' => '跟随系统时间格式设置',
			'settings.twelveHour' => '12小时制',
			'settings.twentyFourHour' => '24小时制',
			'settings.twelveHourDescription' => '例如 1:00 PM',
			'settings.twentyFourHourDescription' => '例如 13:00',
			'settings.showHeroSectionDescription' => '在主屏幕上显示精选内容轮播区',
			'settings.secondsLabel' => '秒',
			'settings.minutesLabel' => '分钟',
			'settings.secondsShort' => 's',
			'settings.minutesShort' => 'm',
			'settings.durationHint' => ({required Object min, required Object max}) => '输入时长 (${min}-${max})',
			'settings.systemTheme' => '系统',
			'settings.systemThemeDescription' => '跟随系统设置',
			'settings.lightTheme' => '浅色',
			'settings.darkTheme' => '深色',
			'settings.oledTheme' => 'OLED',
			'settings.oledThemeDescription' => '纯黑色适用于 OLED 屏幕',
			'settings.libraryDensity' => '媒体库密度',
			'settings.compact' => '紧凑',
			'settings.compactDescription' => '卡片更小，显示更多项目',
			'settings.normal' => '标准',
			'settings.normalDescription' => '默认尺寸',
			'settings.comfortable' => '舒适',
			'settings.comfortableDescription' => '卡片更大，显示更少项目',
			'settings.viewMode' => '视图模式',
			'settings.gridView' => '网格视图',
			'settings.gridViewDescription' => '以网格布局显示项目',
			'settings.listView' => '列表视图',
			'settings.listViewDescription' => '以列表布局显示项目',
			'settings.animations' => '动画',
			'settings.animationsDescription' => '启用过渡和滚动动画',
			'settings.showHeroSection' => '显示主要精选区',
			'settings.useGlobalHubs' => '使用主页布局',
			'settings.useGlobalHubsDescription' => '显示与官方 Jellyfin 客户端相同的主页推荐。关闭时将显示按媒体库分类的推荐。',
			'settings.showServerNameOnHubs' => '在推荐栏显示服务器名称',
			'settings.showServerNameOnHubsDescription' => '始终在推荐栏标题中显示服务器名称。关闭时仅在推荐栏名称重复时显示。',
			'settings.showJellyfinRecommendations' => '电影推荐',
			'settings.showJellyfinRecommendationsDescription' => '在电影库的“推荐”标签页中显示“因为您观看过”等推荐行。在服务器行为改进前默认关闭。',
			'settings.alwaysKeepSidebarOpen' => '始终保持侧边栏展开',
			'settings.alwaysKeepSidebarOpenDescription' => '侧边栏保持展开状态，内容区域自动调整',
			'settings.showUnwatchedCount' => '显示未观看数量',
			'settings.showUnwatchedCountDescription' => '在剧集和季上显示未观看的集数',
			'settings.playerBackend' => '播放器引擎',
			'settings.exoPlayer' => 'ExoPlayer（推荐）',
			'settings.exoPlayerDescription' => 'Android 原生播放器，硬件支持更好',
			'settings.mpv' => 'MPV',
			'settings.mpvDescription' => '功能更多的高级播放器，支持 ASS 字幕',
			'settings.liveTvPlayer' => '直播电视播放器',
			'settings.liveTvPlayerDescription' => '直播电视推荐使用 MPV。ExoPlayer 在某些设备上可能有问题。',
			'settings.liveTvMpv' => 'MPV (Recommended)',
			'settings.liveTvExoPlayer' => 'ExoPlayer',
			'settings.liveTvQuality' => '直播电视画质',
			'settings.liveTvQualityDescription' => '限制直播电视的转码画质。不限制则使用服务器默认。',
			'settings.liveTvQualityNone' => '不限制',
			'settings.streamingQuality' => '流媒体画质',
			'settings.streamingQualityDescription' => '限制VOD转码画质。自动由服务器决定。',
			'settings.hardwareDecoding' => '硬件解码',
			'settings.hardwareDecodingDescription' => '如果可用，使用硬件加速',
			'settings.bufferSize' => '缓冲区大小',
			'settings.bufferSizeMB' => ({required Object size}) => '${size}MB',
			'settings.subtitleStyling' => '字幕样式',
			'settings.subtitleStylingDescription' => '调整字幕外观',
			'settings.smallSkipDuration' => '短跳过时长',
			'settings.largeSkipDuration' => '长跳过时长',
			'settings.secondsUnit' => ({required Object seconds}) => '${seconds} 秒',
			'settings.defaultSleepTimer' => '默认睡眠定时器',
			'settings.minutesUnit' => ({required Object minutes}) => '${minutes} 分钟',
			'settings.rememberTrackSelections' => '记住每个剧集/电影的音轨选择',
			'settings.rememberTrackSelectionsDescription' => '在播放过程中更改音轨时自动保存音频和字幕语言偏好',
			'settings.clickVideoTogglesPlayback' => '点击视频可切换播放/暂停',
			'settings.clickVideoTogglesPlaybackDescription' => '如果启用此选项，点击视频播放器将播放或暂停视频。否则，点击将显示或隐藏播放控件',
			'settings.videoPlayerControls' => '视频播放器键盘控制',
			'settings.keyboardShortcuts' => '键盘快捷键',
			'settings.keyboardShortcutsDescription' => '自定义键盘快捷键',
			'settings.videoPlayerNavigation' => '键盘视频播放器导航',
			'settings.videoPlayerNavigationDescription' => '使用方向键导航视频播放器控件',
			'settings.debugLogging' => '调试日志',
			'settings.debugLoggingDescription' => '启用详细日志记录以便故障排除',
			'settings.viewLogs' => '查看日志',
			'settings.viewLogsDescription' => '查看应用程序日志',
			'settings.clearCache' => '清除缓存',
			'settings.clearCacheDescription' => '这将清除所有缓存的图片和数据。清除缓存后，应用程序加载内容可能会变慢。',
			'settings.clearCacheSuccess' => '缓存清除成功',
			'settings.resetSettings' => '重置设置',
			'settings.resetSettingsDescription' => '这会将所有设置重置为其默认值。此操作无法撤销。',
			'settings.resetSettingsSuccess' => '设置重置成功',
			'settings.shortcutsReset' => '快捷键已重置为默认值',
			'settings.about' => '关于',
			'settings.aboutDescription' => '应用程序信息和许可证',
			'settings.updates' => '更新',
			'settings.updateAvailable' => '有可用更新',
			'settings.checkForUpdates' => '检查更新',
			'settings.validationErrorEnterNumber' => '请输入一个有效的数字',
			'settings.validationErrorDuration' => ({required Object min, required Object max, required Object unit}) => '时长必须介于 ${min} 和 ${max} ${unit} 之间',
			'settings.shortcutAlreadyAssigned' => ({required Object action}) => '快捷键已被分配给 ${action}',
			'settings.shortcutUpdated' => ({required Object action}) => '快捷键已为 ${action} 更新',
			'settings.autoSkip' => '自动跳过',
			'settings.autoSkipIntro' => '自动跳过片头',
			'settings.autoSkipIntroDescription' => '几秒钟后自动跳过片头标记',
			'settings.enableExternalSubtitles' => 'Enable External Subtitles',
			'settings.enableExternalSubtitlesDescription' => 'Show external subtitle options in the player; they load when you select one.',
			'settings.alwaysBurnInSubtitleWhenTranscoding' => '转码时烧录字幕',
			'settings.alwaysBurnInSubtitleWhenTranscodingDescription' => '转码时将所选字幕烧录到视频中。与 jellyfin-web 相同。',
			'settings.enableTrickplay' => 'Enable trickplay thumbnails',
			'settings.enableTrickplayDescription' => 'Show timeline scrub thumbnails when seeking. Requires trickplay data on the server.',
			'settings.enableChapterImages' => 'Enable Chapter Images',
			'settings.enableChapterImagesDescription' => 'Show thumbnail images for chapters in the chapter list.',
			'settings.autoSkipOutro' => '自动跳过片尾',
			'settings.autoSkipOutroDescription' => '自动跳过片尾片段',
			'settings.autoSkipRecap' => '自动跳过回顾',
			'settings.autoSkipRecapDescription' => '自动跳过回顾片段',
			'settings.autoSkipPreview' => '自动跳过预告',
			'settings.autoSkipPreviewDescription' => '自动跳过预告片段',
			'settings.autoSkipCommercial' => '自动跳过广告',
			'settings.autoSkipCommercialDescription' => '自动跳过广告片段',
			'settings.autoSkipDelay' => '自动跳过延迟',
			'settings.autoSkipDelayDescription' => ({required Object seconds}) => '自动跳过前等待 ${seconds} 秒',
			'settings.showDownloads' => 'Show Downloads',
			'settings.showDownloadsDescription' => 'Show the Downloads section in the navigation menu',
			'settings.downloads' => '下载',
			'settings.downloadLocationDescription' => '选择下载内容的存储位置',
			'settings.downloadLocationDefault' => '默认（应用存储）',
			'settings.downloadsDefault' => '下载默认（应用存储）',
			'settings.libraryOrder' => '媒体库管理',
			'settings.downloadLocationCustom' => '自定义位置',
			'settings.selectFolder' => '选择文件夹',
			'settings.resetToDefault' => '重置为默认',
			'settings.currentPath' => ({required Object path}) => '当前: ${path}',
			'settings.downloadLocationChanged' => '下载位置已更改',
			'settings.downloadLocationReset' => '下载位置已重置为默认',
			'settings.downloadLocationInvalid' => '所选文件夹不可写入',
			'settings.downloadLocationSelectError' => '选择文件夹失败',
			'settings.downloadOnWifiOnly' => '仅在 WiFi 时下载',
			'settings.downloadOnWifiOnlyDescription' => '使用蜂窝数据时禁止下载',
			'settings.downloadQuality' => '下载质量',
			'settings.downloadQualityDescription' => '离线下载质量。原始保留源文件；其他选项转码以节省空间。',
			'settings.downloadQualityOriginal' => '原始',
			'settings.downloadQualityOriginalDescription' => '使用原文件。',
			'settings.playbackModeAutoDescription' => '由服务器决定。',
			'settings.playbackModeAuto' => '自动',
			'settings.playbackModeAutoDirect' => '自动 - Direct',
			'settings.playbackModeDirectPlayDescription' => '使用原文件。',
			'settings.playbackModeDirectPlay' => 'Direct',
			'settings.quality15Mbps' => '15 Mbps',
			'settings.quality10Mbps' => '10 Mbps',
			'settings.quality8Mbps' => '8 Mbps',
			'settings.quality6Mbps' => '6 Mbps',
			'settings.quality4Mbps' => '4 Mbps',
			'settings.quality3Mbps' => '3 Mbps',
			'settings.quality1_5Mbps' => '1.5 Mbps',
			'settings.quality720kbps' => '720 kbps',
			'settings.quality420kbps' => '420 kbps',
			'settings.cellularDownloadBlocked' => '蜂窝数据下已禁用下载。请连接 WiFi 或更改设置。',
			'settings.maxVolume' => '最大音量',
			'settings.maxVolumeDescription' => '允许音量超过 100% 以适应安静的媒体',
			'settings.maxVolumePercent' => ({required Object percent}) => '${percent}%',
			'settings.matchContentFrameRate' => '匹配内容帧率',
			'settings.matchContentFrameRateDescription' => '调整显示刷新率以匹配视频内容，减少画面抖动并节省电量',
			'settings.requireProfileSelectionOnOpen' => '打开应用时询问配置文件',
			'settings.requireProfileSelectionOnOpenDescription' => '每次打开应用时显示配置文件选择',
			'settings.confirmExitOnBack' => '退出前确认',
			'settings.confirmExitOnBackDescription' => '按返回键退出应用时显示确认对话框',
			'settings.performance' => '性能',
			'settings.performanceImageQuality' => '图像质量',
			'settings.performanceImageQualityDescription' => '较低质量加载更快。小 = 最快，大 = 最佳质量。',
			'settings.performancePosterSize' => '海报大小',
			'settings.performancePosterSizeDescription' => '网格中海报卡片的大小。小 = 更多项目，大 = 更大卡片。',
			'settings.performanceDisableAnimations' => '禁用动画',
			'settings.performanceDisableAnimationsDescription' => '关闭所有过渡以获得更灵敏的导航',
			'settings.performanceGridPreload' => '网格预加载',
			'settings.performanceGridPreloadDescription' => '加载多少屏幕外项目。低 = 更快，高 = 更流畅的滚动。',
			'settings.performanceSmall' => '小',
			'settings.performanceMedium' => '中',
			'settings.performanceLarge' => '大',
			'settings.performanceLow' => '低',
			'settings.performanceHigh' => '高',
			'settings.hideSupportDevelopment' => '隐藏支持开发',
			'settings.hideSupportDevelopmentDescription' => '在设置中隐藏支持开发部分',
			'search.hint' => '搜索电影、系列、音乐...',
			'search.tryDifferentTerm' => '尝试不同的搜索词',
			'search.searchYourMedia' => '搜索媒体',
			'search.enterTitleActorOrKeyword' => '输入标题、演员或关键词',
			'search.categories.movies' => 'Movies',
			'search.categories.shows' => 'Shows',
			'search.categories.episodes' => 'Episodes',
			'search.categories.people' => 'People',
			'search.categories.collections' => 'Collections',
			'search.categories.programs' => 'Programs',
			'search.categories.channels' => 'Channels',
			'hotkeys.setShortcutFor' => ({required Object actionName}) => '为 ${actionName} 设置快捷键',
			'hotkeys.clearShortcut' => '清除快捷键',
			'hotkeys.actions.playPause' => '播放/暂停',
			'hotkeys.actions.volumeUp' => '增大音量',
			'hotkeys.actions.volumeDown' => '减小音量',
			'hotkeys.actions.seekForward' => ({required Object seconds}) => '快进 (${seconds}秒)',
			'hotkeys.actions.seekBackward' => ({required Object seconds}) => '快退 (${seconds}秒)',
			'hotkeys.actions.fullscreenToggle' => '切换全屏',
			'hotkeys.actions.muteToggle' => '切换静音',
			'hotkeys.actions.subtitleToggle' => '切换字幕',
			'hotkeys.actions.audioTrackNext' => '下一音轨',
			'hotkeys.actions.subtitleTrackNext' => '下一字幕轨',
			'hotkeys.actions.chapterNext' => '下一章节',
			'hotkeys.actions.chapterPrevious' => '上一章节',
			'hotkeys.actions.speedIncrease' => '加速',
			'hotkeys.actions.speedDecrease' => '减速',
			'hotkeys.actions.speedReset' => '重置速度',
			'hotkeys.actions.subSeekNext' => '跳转到下一字幕',
			'hotkeys.actions.subSeekPrev' => '跳转到上一字幕',
			'hotkeys.actions.shaderToggle' => '切换着色器',
			'hotkeys.actions.skipMarker' => '跳过片头/片尾',
			'pinEntry.enterPin' => '输入 PIN',
			'pinEntry.showPin' => '显示 PIN',
			'pinEntry.hidePin' => '隐藏 PIN',
			'fileInfo.title' => '文件信息',
			'fileInfo.video' => '视频',
			'fileInfo.audio' => '音频',
			'fileInfo.file' => '文件',
			'fileInfo.advanced' => '高级',
			'fileInfo.codec' => '编解码器',
			'fileInfo.resolution' => '分辨率',
			'fileInfo.bitrate' => '比特率',
			'fileInfo.frameRate' => '帧率',
			'fileInfo.aspectRatio' => '宽高比',
			'fileInfo.profile' => '配置文件',
			'fileInfo.bitDepth' => '位深度',
			'fileInfo.colorSpace' => '色彩空间',
			'fileInfo.colorRange' => '色彩范围',
			'fileInfo.colorPrimaries' => '颜色原色',
			'fileInfo.chromaSubsampling' => '色度子采样',
			'fileInfo.channels' => '声道',
			'fileInfo.path' => '路径',
			'fileInfo.size' => '大小',
			'fileInfo.container' => '容器',
			'fileInfo.duration' => '时长',
			'fileInfo.optimizedForStreaming' => '已优化用于流媒体',
			'fileInfo.has64bitOffsets' => '64位偏移量',
			'mediaMenu.markAsWatched' => '标记为已观看',
			'mediaMenu.markAsUnwatched' => '标记为未观看',
			'mediaMenu.goToSeries' => '转到系列',
			'mediaMenu.goToSeason' => '转到季',
			'mediaMenu.shufflePlay' => '随机播放',
			'mediaMenu.fileInfo' => '文件信息',
			'mediaMenu.confirmDelete' => '确定要从文件系统中删除此项吗？',
			'mediaMenu.deleteMultipleWarning' => '可能会删除多个项目。',
			'mediaMenu.mediaDeletedSuccessfully' => '媒体项已成功删除',
			'mediaMenu.mediaFailedToDelete' => '删除媒体项失败',
			'mediaMenu.rate' => '评分',
			'accessibility.mediaCardMovie' => ({required Object title}) => '${title}, 电影',
			'accessibility.mediaCardShow' => ({required Object title}) => '${title}, 电视剧',
			'accessibility.mediaCardEpisode' => ({required Object title, required Object episodeInfo}) => '${title}, ${episodeInfo}',
			'accessibility.mediaCardSeason' => ({required Object title, required Object seasonInfo}) => '${title}, ${seasonInfo}',
			'accessibility.mediaCardWatched' => '已观看',
			'accessibility.mediaCardPartiallyWatched' => ({required Object percent}) => '已观看 ${percent} 百分比',
			'accessibility.mediaCardUnwatched' => '未观看',
			'accessibility.tapToPlay' => '点击播放',
			'tooltips.shufflePlay' => '随机播放',
			'tooltips.playTrailer' => '播放预告片',
			'tooltips.playFromStart' => '从头播放',
			'tooltips.markAsWatched' => '标记为已观看',
			'tooltips.markAsUnwatched' => '标记为未观看',
			'videoControls.audioLabel' => '音频',
			'videoControls.subtitlesLabel' => '字幕',
			'videoControls.resetToZero' => '重置为 0ms',
			'videoControls.addTime' => ({required Object amount, required Object unit}) => '+${amount}${unit}',
			'videoControls.minusTime' => ({required Object amount, required Object unit}) => '-${amount}${unit}',
			'videoControls.playsLater' => ({required Object label}) => '${label} 播放较晚',
			'videoControls.playsEarlier' => ({required Object label}) => '${label} 播放较早',
			'videoControls.noOffset' => '无偏移',
			'videoControls.letterbox' => '信箱模式（Letterbox）',
			'videoControls.fillScreen' => '填充屏幕',
			'videoControls.stretch' => '拉伸',
			'videoControls.lockRotation' => '锁定旋转',
			'videoControls.unlockRotation' => '解锁旋转',
			'videoControls.timerActive' => '定时器已激活',
			'videoControls.playbackWillPauseIn' => ({required Object duration}) => '播放将在 ${duration} 后暂停',
			'videoControls.sleepTimerCompleted' => '睡眠定时器已完成 - 播放已暂停',
			'videoControls.autoPlayNext' => '自动播放下一集',
			'videoControls.playNext' => '播放下一集',
			'videoControls.playButton' => '播放',
			'videoControls.pauseButton' => '暂停',
			'videoControls.seekBackwardButton' => ({required Object seconds}) => '后退 ${seconds} 秒',
			'videoControls.seekForwardButton' => ({required Object seconds}) => '前进 ${seconds} 秒',
			'videoControls.previousButton' => '上一集',
			'videoControls.nextButton' => '下一集',
			'videoControls.previousChapterButton' => '上一章节',
			'videoControls.nextChapterButton' => '下一章节',
			'videoControls.muteButton' => '静音',
			'videoControls.unmuteButton' => '取消静音',
			'videoControls.settingsButton' => '视频设置',
			'videoControls.audioTrackButton' => '音轨',
			'videoControls.subtitlesButton' => '字幕',
			'videoControls.chaptersButton' => '章节',
			'videoControls.versionsButton' => '视频版本',
			'videoControls.pipButton' => '画中画模式',
			'videoControls.aspectRatioButton' => '宽高比',
			'videoControls.ambientLighting' => '氛围灯光',
			'videoControls.ambientLightingOn' => '开启氛围灯光',
			'videoControls.ambientLightingOff' => '关闭氛围灯光',
			'videoControls.fullscreenButton' => '进入全屏',
			'videoControls.exitFullscreenButton' => '退出全屏',
			'videoControls.alwaysOnTopButton' => '置顶窗口',
			'videoControls.rotationLockButton' => '旋转锁定',
			'videoControls.timelineSlider' => '视频时间轴',
			'videoControls.volumeSlider' => '音量调节',
			'videoControls.endsAt' => ({required Object time}) => '${time} 结束',
			'videoControls.pipFailed' => '画中画启动失败',
			'videoControls.pipErrors.androidVersion' => '需要 Android 8.0 或更高版本',
			'videoControls.pipErrors.permissionDisabled' => '画中画权限已禁用。请在设置 > 应用 > Finzy > 画中画中启用',
			'videoControls.pipErrors.notSupported' => '此设备不支持画中画模式',
			'videoControls.pipErrors.failed' => '画中画启动失败',
			'videoControls.pipErrors.unknown' => ({required Object error}) => '发生错误：${error}',
			'videoControls.chapters' => '章节',
			'videoControls.noChaptersAvailable' => '没有可用的章节',
			'userStatus.admin' => '管理员',
			'userStatus.restricted' => '受限',
			'userStatus.protected' => '受保护',
			'userStatus.current' => '当前',
			'messages.markedAsWatched' => '已标记为已观看',
			'messages.markedAsUnwatched' => '已标记为未观看',
			'messages.markedAsWatchedOffline' => '已标记为已观看 (将在联网时同步)',
			'messages.markedAsUnwatchedOffline' => '已标记为未观看 (将在联网时同步)',
			'messages.errorLoading' => ({required Object error}) => '错误: ${error}',
			'messages.fileInfoNotAvailable' => '文件信息不可用',
			'messages.errorLoadingFileInfo' => ({required Object error}) => '加载文件信息时出错: ${error}',
			'messages.errorLoadingSeries' => '加载系列时出错',
			'messages.errorLoadingSeason' => '加载季时出错',
			'messages.musicNotSupported' => '尚不支持播放音乐',
			'messages.logsCleared' => '日志已清除',
			'messages.logsCopied' => '日志已复制到剪贴板',
			'messages.noLogsAvailable' => '没有可用日志',
			'messages.libraryScanning' => ({required Object title}) => '正在扫描 “${title}”...',
			'messages.libraryScanStarted' => ({required Object title}) => '已开始扫描 “${title}” 媒体库',
			'messages.libraryScanFailed' => ({required Object error}) => '无法扫描媒体库: ${error}',
			'messages.metadataRefreshing' => ({required Object title}) => '正在刷新 “${title}” 的元数据...',
			'messages.metadataRefreshStarted' => ({required Object title}) => '已开始刷新 “${title}” 的元数据',
			'messages.metadataRefreshFailed' => ({required Object error}) => '无法刷新元数据: ${error}',
			'messages.logoutConfirm' => '你确定要登出吗？',
			'messages.noSeasonsFound' => '未找到季',
			'messages.noEpisodesFound' => '在第一季中未找到剧集',
			'messages.noEpisodesFoundGeneral' => '未找到剧集',
			'messages.noResultsFound' => '未找到结果',
			'messages.sleepTimerSet' => ({required Object label}) => '睡眠定时器已设置为 ${label}',
			'messages.noItemsAvailable' => '没有可用的项目',
			'messages.failedToCreatePlayQueueNoItems' => '创建播放队列失败 - 没有项目',
			'messages.failedPlayback' => ({required Object action, required Object error}) => '无法${action}: ${error}',
			'messages.switchingToCompatiblePlayer' => '正在切换到兼容的播放器...',
			'messages.qualityRevertedOnError' => '因播放错误已恢复为之前的画质。',
			'subtitlingStyling.stylingOptions' => '样式选项',
			'subtitlingStyling.fontSize' => '字号',
			'subtitlingStyling.textColor' => '文本颜色',
			'subtitlingStyling.borderSize' => '边框大小',
			'subtitlingStyling.borderColor' => '边框颜色',
			'subtitlingStyling.backgroundOpacity' => '背景不透明度',
			'subtitlingStyling.backgroundColor' => '背景颜色',
			'subtitlingStyling.position' => 'Position',
			'mpvConfig.title' => 'MPV 配置',
			'mpvConfig.description' => '高级视频播放器设置',
			'mpvConfig.properties' => '属性',
			'mpvConfig.presets' => '预设',
			'mpvConfig.noProperties' => '未配置任何属性',
			'mpvConfig.noPresets' => '没有保存的预设',
			'mpvConfig.addProperty' => '添加属性',
			'mpvConfig.editProperty' => '编辑属性',
			'mpvConfig.deleteProperty' => '删除属性',
			'mpvConfig.propertyKey' => '属性键',
			'mpvConfig.propertyKeyHint' => '例如 hwdec, demuxer-max-bytes',
			'mpvConfig.propertyValue' => '属性值',
			'mpvConfig.propertyValueHint' => '例如 auto, 256000000',
			'mpvConfig.saveAsPreset' => '保存为预设...',
			'mpvConfig.presetName' => '预设名称',
			'mpvConfig.presetNameHint' => '输入此预设的名称',
			'mpvConfig.loadPreset' => '加载',
			'mpvConfig.deletePreset' => '删除',
			'mpvConfig.presetSaved' => '预设已保存',
			'mpvConfig.presetLoaded' => '预设已加载',
			'mpvConfig.presetDeleted' => '预设已删除',
			'mpvConfig.confirmDeletePreset' => '确定要删除此预设吗？',
			'mpvConfig.confirmDeleteProperty' => '确定要删除此属性吗？',
			'mpvConfig.entriesCount' => ({required Object count}) => '${count} 条目',
			'dialog.confirmAction' => '确认操作',
			'discover.title' => '发现',
			'discover.switchProfile' => '切换用户',
			'discover.noContentAvailable' => '没有可用内容',
			'discover.addMediaToLibraries' => '请向你的媒体库添加一些媒体',
			'discover.continueWatching' => '继续观看',
			'discover.playEpisode' => ({required Object season, required Object episode}) => 'S${season}E${episode}',
			'discover.overview' => '概述',
			'discover.cast' => '演员表',
			'discover.moreLikeThis' => '相似推荐',
			'discover.moviesAndShows' => 'Movies & Shows',
			'discover.noItemsFound' => 'No items found on this server',
			'discover.extras' => '预告片与花絮',
			'discover.seasons' => '季数',
			'discover.studio' => '制作公司',
			'discover.rating' => '年龄分级',
			'discover.episodeCount' => ({required Object count}) => '${count} 集',
			'discover.watchedProgress' => ({required Object watched, required Object total}) => '已观看 ${watched}/${total} 集',
			'discover.movie' => '电影',
			'discover.tvShow' => '电视剧',
			'discover.minutesLeft' => ({required Object minutes}) => '剩余 ${minutes} 分钟',
			'errors.searchFailed' => ({required Object error}) => '搜索失败: ${error}',
			'errors.connectionTimeout' => ({required Object context}) => '加载 ${context} 时连接超时',
			'errors.connectionFailed' => '无法连接到 Jellyfin 服务器',
			'errors.failedToLoad' => ({required Object context, required Object error}) => '无法加载 ${context}: ${error}',
			'errors.noClientAvailable' => '没有可用客户端',
			'errors.authenticationFailed' => ({required Object error}) => '验证失败: ${error}',
			'errors.couldNotLaunchUrl' => '无法打开授权 URL',
			'errors.pleaseEnterToken' => '请输入一个令牌',
			'errors.invalidToken' => '令牌无效',
			'errors.failedToVerifyToken' => ({required Object error}) => '无法验证令牌: ${error}',
			'errors.failedToSwitchProfile' => ({required Object displayName}) => '无法切换到 ${displayName}',
			_ => null,
		} ?? switch (path) {
			'libraries.title' => '媒体库',
			'libraries.scanLibraryFiles' => '扫描媒体库文件',
			'libraries.scanLibrary' => '扫描媒体库',
			'libraries.analyze' => '分析',
			'libraries.analyzeLibrary' => '分析媒体库',
			'libraries.refreshMetadata' => '刷新元数据',
			'libraries.emptyTrash' => '清空回收站',
			'libraries.emptyingTrash' => ({required Object title}) => '正在清空 “${title}” 的回收站...',
			'libraries.trashEmptied' => ({required Object title}) => '已清空 “${title}” 的回收站',
			'libraries.failedToEmptyTrash' => ({required Object error}) => '无法清空回收站: ${error}',
			'libraries.analyzing' => ({required Object title}) => '正在分析 “${title}”...',
			'libraries.analysisStarted' => ({required Object title}) => '已开始分析 “${title}”',
			'libraries.failedToAnalyze' => ({required Object error}) => '无法分析媒体库: ${error}',
			'libraries.noLibrariesFound' => '未找到媒体库',
			'libraries.thisLibraryIsEmpty' => '此媒体库为空',
			'libraries.all' => '全部',
			'libraries.clearAll' => '全部清除',
			'libraries.scanLibraryConfirm' => ({required Object title}) => '确定要扫描 “${title}” 吗？',
			'libraries.analyzeLibraryConfirm' => ({required Object title}) => '确定要分析 “${title}” 吗？',
			'libraries.refreshMetadataConfirm' => ({required Object title}) => '确定要刷新 “${title}” 的元数据吗？',
			'libraries.emptyTrashConfirm' => ({required Object title}) => '确定要清空 “${title}” 的回收站吗？',
			'libraries.manageLibraries' => '管理媒体库',
			'libraries.sort' => '排序',
			'libraries.sortBy' => '排序依据',
			'libraries.filters' => '筛选器',
			'libraries.confirmActionMessage' => '确定要执行此操作吗？',
			'libraries.showLibrary' => '显示媒体库',
			'libraries.hideLibrary' => '隐藏媒体库',
			'libraries.libraryOptions' => '媒体库选项',
			'libraries.content' => '媒体库内容',
			'libraries.selectLibrary' => '选择媒体库',
			'libraries.filtersWithCount' => ({required Object count}) => '筛选器（${count}）',
			'libraries.noRecommendations' => '暂无推荐',
			'libraries.noCollections' => '此媒体库中没有合集',
			'libraries.noFavorites' => '此媒体库中无收藏',
			'libraries.noGenres' => '此媒体库中无类型',
			'libraries.noFoldersFound' => '未找到文件夹',
			'libraries.folders' => '文件夹',
			'libraries.tabs.movies' => '电影',
			'libraries.tabs.shows' => '剧集',
			'libraries.tabs.suggestions' => '推荐',
			'libraries.tabs.browse' => '浏览',
			'libraries.tabs.genres' => '类型',
			'libraries.tabs.favorites' => '收藏',
			'libraries.tabs.collections' => '合集',
			'libraries.tabs.playlists' => '播放列表',
			'libraries.groupings.all' => '全部',
			'libraries.groupings.movies' => '电影',
			'libraries.groupings.shows' => '剧集',
			'libraries.groupings.seasons' => '季',
			'libraries.groupings.episodes' => '集',
			'libraries.groupings.folders' => '文件夹',
			'about.title' => '关于',
			'about.openSourceLicenses' => '开源许可证',
			'about.versionLabel' => ({required Object version}) => '版本 ${version}',
			'about.appDescription' => '一款精美的 Flutter Jellyfin 客户端',
			'about.viewLicensesDescription' => '查看第三方库的许可证',
			'serverSelection.allServerConnectionsFailed' => '无法连接到任何服务器。请检查你的网络并重试。',
			'serverSelection.noServersFoundForAccount' => ({required Object username, required Object email}) => '未找到 ${username} (${email}) 的服务器',
			'serverSelection.failedToLoadServers' => ({required Object error}) => '无法加载服务器: ${error}',
			'hubDetail.title' => '标题',
			'hubDetail.releaseYear' => '发行年份',
			'hubDetail.dateAdded' => '添加日期',
			'hubDetail.rating' => '评分',
			'hubDetail.noItemsFound' => '未找到项目',
			'logs.clearLogs' => '清除日志',
			'logs.copyLogs' => '复制日志',
			'logs.error' => '错误:',
			'logs.stackTrace' => '堆栈跟踪 (Stack Trace):',
			'licenses.relatedPackages' => '相关软件包',
			'licenses.license' => '许可证',
			'licenses.licenseNumber' => ({required Object number}) => '许可证 ${number}',
			'licenses.licensesCount' => ({required Object count}) => '${count} 个许可证',
			'navigation.libraries' => '媒体库',
			'navigation.downloads' => '下载',
			'navigation.liveTv' => '电视直播',
			'liveTv.title' => '电视直播',
			'liveTv.channels' => '频道',
			'liveTv.guide' => '节目指南',
			'liveTv.recordings' => '录制',
			'liveTv.subscriptions' => '录制规则',
			'liveTv.scheduled' => '已计划',
			'liveTv.seriesTimers' => 'Series Timers',
			'liveTv.noChannels' => '没有可用的频道',
			'liveTv.dvr' => 'DVR',
			'liveTv.noDvr' => '没有服务器配置了DVR',
			'liveTv.tuneFailed' => '无法调谐频道',
			'liveTv.loading' => '正在加载频道...',
			'liveTv.nowPlaying' => '正在播放',
			'liveTv.record' => '录制',
			'liveTv.recordSeries' => '录制系列',
			'liveTv.cancelRecording' => '取消录制',
			'liveTv.deleteSubscription' => '删除录制规则',
			'liveTv.deleteSubscriptionConfirm' => '确定要删除此录制规则吗？',
			'liveTv.subscriptionDeleted' => '录制规则已删除',
			'liveTv.noPrograms' => '没有可用的节目数据',
			'liveTv.noRecordings' => 'No recordings',
			'liveTv.noScheduled' => 'No scheduled recordings',
			'liveTv.noSubscriptions' => 'No series timers',
			'liveTv.cancelTimer' => 'Cancel Recording',
			'liveTv.cancelTimerConfirm' => 'Are you sure you want to cancel this scheduled recording?',
			'liveTv.timerCancelled' => 'Recording cancelled',
			'liveTv.editSeriesTimer' => '编辑',
			'liveTv.deleteSeriesTimer' => 'Delete Series Timer',
			'liveTv.deleteSeriesTimerConfirm' => 'Are you sure you want to delete this series timer? All associated scheduled recordings will also be removed.',
			'liveTv.seriesTimerDeleted' => 'Series timer deleted',
			'liveTv.seriesTimerUpdated' => 'Series timer updated',
			'liveTv.recordNewOnly' => 'Record new episodes only',
			'liveTv.keepUpTo' => 'Keep up to',
			'liveTv.keepAll' => 'Keep all',
			'liveTv.keepEpisodes' => ({required Object count}) => '${count} episodes',
			'liveTv.prePadding' => 'Start recording early',
			'liveTv.postPadding' => 'Continue recording after',
			'liveTv.minutes' => ({required Object count}) => '${count} min',
			'liveTv.days' => 'Days',
			'liveTv.priority' => 'Priority',
			'liveTv.channelNumber' => ({required Object number}) => '频道 ${number}',
			'liveTv.live' => '直播',
			'liveTv.hd' => '高清',
			'liveTv.premiere' => '新',
			'liveTv.reloadGuide' => '重新加载节目指南',
			'liveTv.guideReloaded' => '节目指南已重新加载',
			'liveTv.allChannels' => '所有频道',
			'liveTv.now' => '现在',
			'liveTv.today' => '今天',
			'liveTv.midnight' => '午夜',
			'liveTv.overnight' => '凌晨',
			'liveTv.morning' => '上午',
			'liveTv.daytime' => '白天',
			'liveTv.evening' => '晚上',
			'liveTv.lateNight' => '深夜',
			'liveTv.programs' => 'Programs',
			'liveTv.onNow' => 'On Now',
			'liveTv.upcomingShows' => 'Shows',
			'liveTv.upcomingMovies' => 'Movies',
			'liveTv.upcomingSports' => 'Sports',
			'liveTv.forKids' => 'For Kids',
			'liveTv.upcomingNews' => 'News',
			'liveTv.watchChannel' => '观看频道',
			'liveTv.recentlyAdded' => 'Recently Added',
			'liveTv.recordingScheduled' => 'Recording scheduled',
			'liveTv.seriesRecordingScheduled' => 'Series recording scheduled',
			'liveTv.recordingFailed' => 'Failed to schedule recording',
			'liveTv.cancelSeries' => 'Cancel Series',
			'liveTv.stopRecording' => 'Stop Recording',
			'liveTv.doNotRecord' => 'Do Not Record',
			'downloads.title' => '下载',
			'downloads.manage' => '管理',
			'downloads.tvShows' => '电视剧',
			'downloads.movies' => '电影',
			'downloads.noDownloads' => '暂无下载',
			'downloads.noDownloadsDescription' => '下载的内容将在此处显示以供离线观看',
			'downloads.downloadNow' => '下载',
			'downloads.deleteDownload' => '删除下载',
			'downloads.retryDownload' => '重试下载',
			'downloads.downloadQueued' => '下载已排队',
			'downloads.downloadStarting' => '正在启动...',
			'downloads.episodesQueued' => ({required Object count}) => '${count} 集已加入下载队列',
			'downloads.downloadDeleted' => '下载已删除',
			'downloads.deleteConfirm' => ({required Object title}) => '确定要删除 "${title}" 吗？下载的文件将从您的设备中删除。',
			'downloads.deletingWithProgress' => ({required Object title, required Object current, required Object total}) => '正在删除 ${title}... (${current}/${total})',
			'downloads.noDownloadsTree' => '暂无下载',
			'downloads.pauseAll' => '全部暂停',
			'downloads.resumeAll' => '全部继续',
			'downloads.deleteAll' => '全部删除',
			'playlists.title' => '播放列表',
			'playlists.noPlaylists' => '未找到播放列表',
			'playlists.create' => '创建播放列表',
			'playlists.playlistName' => '播放列表名称',
			'playlists.enterPlaylistName' => '输入播放列表名称',
			'playlists.delete' => '删除播放列表',
			'playlists.removeItem' => '从播放列表中移除',
			'playlists.smartPlaylist' => '智能播放列表',
			'playlists.itemCount' => ({required Object count}) => '${count} 个项目',
			'playlists.oneItem' => '1 个项目',
			'playlists.emptyPlaylist' => '此播放列表为空',
			'playlists.deleteConfirm' => '删除播放列表？',
			'playlists.deleteMessage' => ({required Object name}) => '确定要删除 "${name}" 吗？',
			'playlists.created' => '播放列表已创建',
			'playlists.deleted' => '播放列表已删除',
			'playlists.itemAdded' => '已添加到播放列表',
			'playlists.itemRemoved' => '已从播放列表中移除',
			'playlists.selectPlaylist' => '选择播放列表',
			'playlists.createNewPlaylist' => '创建新播放列表',
			'playlists.errorCreating' => '创建播放列表失败',
			'playlists.errorDeleting' => '删除播放列表失败',
			'playlists.errorLoading' => '加载播放列表失败',
			'playlists.errorAdding' => '添加到播放列表失败',
			'playlists.errorReordering' => '重新排序播放列表项目失败',
			'playlists.errorRemoving' => '从播放列表中移除失败',
			'playlists.playlist' => '播放列表',
			'playlists.addToPlaylist' => '添加到播放列表',
			'collections.title' => '合集',
			'collections.collection' => '合集',
			'collections.addToCollection' => '添加到合集',
			'collections.empty' => '合集为空',
			'collections.unknownLibrarySection' => '无法删除：未知的媒体库分区',
			'collections.deleteCollection' => '删除合集',
			'collections.deleteConfirm' => ({required Object title}) => '确定要删除"${title}"吗？此操作无法撤销。',
			'collections.deleted' => '已删除合集',
			'collections.deleteFailed' => '删除合集失败',
			'collections.deleteFailedWithError' => ({required Object error}) => '删除合集失败：${error}',
			'collections.failedToLoadItems' => ({required Object error}) => '加载合集项目失败：${error}',
			'collections.selectCollection' => '选择合集',
			'collections.createNewCollection' => '创建新合集',
			'collections.collectionName' => '合集名称',
			'collections.enterCollectionName' => '输入合集名称',
			'collections.addedToCollection' => '已添加到合集',
			'collections.errorAddingToCollection' => '添加到合集失败',
			'collections.created' => '已创建合集',
			'collections.removeFromCollection' => '从合集移除',
			'collections.removeFromCollectionConfirm' => ({required Object title}) => '将“${title}”从此合集移除？',
			'collections.removedFromCollection' => '已从合集移除',
			'collections.removeFromCollectionFailed' => '从合集移除失败',
			'collections.removeFromCollectionError' => ({required Object error}) => '从合集移除时出错：${error}',
			'shaders.title' => '着色器',
			'shaders.noShaderDescription' => '无视频增强',
			'shaders.nvscalerDescription' => 'NVIDIA 图像缩放，使视频更清晰',
			'shaders.qualityFast' => '快速',
			'shaders.qualityHQ' => '高质量',
			'shaders.mode' => '模式',
			'companionRemote.title' => 'Companion Remote',
			'companionRemote.connectToDevice' => '连接到设备',
			'companionRemote.hostRemoteSession' => '创建远程会话',
			'companionRemote.controlThisDevice' => '使用手机控制此设备',
			'companionRemote.remoteControl' => '远程控制',
			'companionRemote.controlDesktop' => '控制桌面设备',
			'companionRemote.connectedTo' => ({required Object name}) => '已连接到 ${name}',
			'companionRemote.session.creatingSession' => '正在创建远程会话...',
			'companionRemote.session.failedToCreate' => '创建远程会话失败：',
			'companionRemote.session.noSession' => '没有可用的会话',
			'companionRemote.session.scanQrCode' => '扫描 QR 码',
			'companionRemote.session.orEnterManually' => '或手动输入',
			'companionRemote.session.hostAddress' => '主机地址',
			'companionRemote.session.sessionId' => '会话 ID',
			'companionRemote.session.pin' => 'PIN',
			'companionRemote.session.connected' => '已连接',
			'companionRemote.session.waitingForConnection' => '等待连接中...',
			'companionRemote.session.usePhoneToControl' => '使用移动设备控制此应用',
			'companionRemote.session.copiedToClipboard' => ({required Object label}) => '${label}已复制到剪贴板',
			'companionRemote.session.copyToClipboard' => '复制到剪贴板',
			'companionRemote.session.newSession' => '新建会话',
			'companionRemote.session.minimize' => '最小化',
			'companionRemote.pairing.recent' => '最近',
			'companionRemote.pairing.scan' => '扫描',
			'companionRemote.pairing.manual' => '手动',
			'companionRemote.pairing.recentConnections' => '最近连接',
			'companionRemote.pairing.quickReconnect' => '快速重新连接之前配对的设备',
			'companionRemote.pairing.pairWithDesktop' => '与桌面配对',
			'companionRemote.pairing.enterSessionDetails' => '输入桌面设备上显示的会话信息',
			'companionRemote.pairing.hostAddressHint' => '192.168.1.100:48632',
			'companionRemote.pairing.sessionIdHint' => '输入8位会话 ID',
			'companionRemote.pairing.pinHint' => '输入6位 PIN',
			'companionRemote.pairing.connecting' => '连接中...',
			'companionRemote.pairing.tips' => '提示',
			'companionRemote.pairing.tipDesktop' => '在桌面上打开 Finzy，并从设置或菜单中启用 Companion Remote',
			'companionRemote.pairing.tipScan' => '使用扫描选项卡扫描桌面上的 QR 码以快速配对',
			'companionRemote.pairing.tipWifi' => '请确保两台设备连接到同一个 WiFi 网络',
			'companionRemote.pairing.cameraPermissionRequired' => '扫描 QR 码需要相机权限。\n请在设备设置中授予相机访问权限。',
			'companionRemote.pairing.cameraError' => ({required Object error}) => '无法启动相机：${error}',
			'companionRemote.pairing.scanInstruction' => '将相机对准桌面上显示的 QR 码',
			'companionRemote.pairing.noRecentConnections' => '没有最近的连接',
			'companionRemote.pairing.connectUsingManual' => '使用手动输入连接设备以开始使用',
			'companionRemote.pairing.invalidQrCode' => '无效的 QR 码格式',
			'companionRemote.pairing.removeRecentConnection' => '删除最近连接',
			'companionRemote.pairing.removeConfirm' => ({required Object name}) => '确定要从最近连接中删除 "${name}" 吗？',
			'companionRemote.pairing.validationHostRequired' => '请输入主机地址',
			'companionRemote.pairing.validationHostFormat' => '格式必须为 IP:端口（例如 192.168.1.100:48632）',
			'companionRemote.pairing.validationSessionIdRequired' => '请输入会话 ID',
			'companionRemote.pairing.validationSessionIdLength' => '会话 ID 必须为8个字符',
			'companionRemote.pairing.validationPinRequired' => '请输入 PIN',
			'companionRemote.pairing.validationPinLength' => 'PIN 必须为6位数字',
			'companionRemote.pairing.connectionTimedOut' => '连接超时。请检查会话 ID 和 PIN。',
			'companionRemote.pairing.sessionNotFound' => '找不到会话。请检查您的凭据。',
			'companionRemote.pairing.failedToConnect' => ({required Object error}) => '连接失败：${error}',
			'companionRemote.pairing.failedToLoadRecent' => ({required Object error}) => '加载最近会话失败：${error}',
			'companionRemote.remote.disconnectConfirm' => '是否要断开远程会话的连接？',
			'companionRemote.remote.reconnecting' => '重新连接中...',
			'companionRemote.remote.attemptOf' => ({required Object current}) => '第 ${current} 次尝试，共 5 次',
			'companionRemote.remote.retryNow' => '立即重试',
			'companionRemote.remote.connectionError' => '连接错误',
			'companionRemote.remote.notConnected' => '未连接',
			'companionRemote.remote.tabRemote' => '遥控',
			'companionRemote.remote.tabPlay' => '播放',
			'companionRemote.remote.tabMore' => '更多',
			'companionRemote.remote.menu' => '菜单',
			'companionRemote.remote.tabNavigation' => '标签导航',
			'companionRemote.remote.tabDiscover' => '发现',
			'companionRemote.remote.tabLibraries' => '媒体库',
			'companionRemote.remote.tabSearch' => '搜索',
			'companionRemote.remote.tabDownloads' => '下载',
			'companionRemote.remote.tabSettings' => '设置',
			'companionRemote.remote.previous' => '上一个',
			'companionRemote.remote.playPause' => '播放/暂停',
			'companionRemote.remote.next' => '下一个',
			'companionRemote.remote.seekBack' => '后退',
			'companionRemote.remote.stop' => '停止',
			'companionRemote.remote.seekForward' => '快进',
			'companionRemote.remote.volume' => '音量',
			'companionRemote.remote.volumeDown' => '减小',
			'companionRemote.remote.volumeUp' => '增大',
			'companionRemote.remote.fullscreen' => '全屏',
			'companionRemote.remote.subtitles' => '字幕',
			'companionRemote.remote.audio' => '音频',
			'companionRemote.remote.searchHint' => '在桌面上搜索...',
			'videoSettings.playbackSettings' => '播放设置',
			'videoSettings.quality' => '画质',
			'videoSettings.qualityDescription' => '流媒体画质。自动由服务器决定。',
			'videoSettings.playbackSpeed' => '播放速度',
			'videoSettings.sleepTimer' => '睡眠定时器',
			'videoSettings.audioSync' => '音频同步',
			'videoSettings.subtitleSync' => '字幕同步',
			'videoSettings.hdr' => 'HDR',
			'videoSettings.audioOutput' => '音频输出',
			'videoSettings.performanceOverlay' => '性能监控',
			'externalPlayer.title' => '外部播放器',
			'externalPlayer.useExternalPlayer' => '使用外部播放器',
			'externalPlayer.useExternalPlayerDescription' => '在外部应用中打开视频，而不是使用内置播放器',
			'externalPlayer.selectPlayer' => '选择播放器',
			'externalPlayer.systemDefault' => '系统默认',
			'externalPlayer.addCustomPlayer' => '添加自定义播放器',
			'externalPlayer.playerName' => '播放器名称',
			'externalPlayer.playerCommand' => '命令',
			'externalPlayer.playerPackage' => '包名',
			'externalPlayer.playerUrlScheme' => 'URL 方案',
			'externalPlayer.customPlayer' => '自定义播放器',
			'externalPlayer.off' => '关闭',
			'externalPlayer.launchFailed' => '无法打开外部播放器',
			'externalPlayer.appNotInstalled' => ({required Object name}) => '${name} 未安装',
			'externalPlayer.playInExternalPlayer' => '在外部播放器中播放',
			_ => null,
		};
	}
}
