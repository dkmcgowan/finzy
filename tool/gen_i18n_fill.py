# -*- coding: utf-8 -*-
"""Generate tool/i18n_fill.json — run: python tool/gen_i18n_fill.py"""
import json

L = ("de", "es", "fr", "it", "ko", "nl", "sv", "zh")

def row(*vals):
    assert len(vals) == 8
    return {a: b for a, b in zip(L, vals)}

# English source (must match en.i18n.json exactly for replace to apply)
fill = {}

# --- common ---
fill["common.authorize"] = row(
    "Autorisieren", "Autorizar", "Autoriser", "Autorizza", "승인", "Autoriseren", "Godkänn", "授权"
)
fill["common.none"] = row(
    "Keine", "Ninguno", "Aucun", "Nessuno", "없음", "Geen", "Ingen", "无"
)
fill["common.pause"] = row(
    "Pause", "Pausa", "Pause", "Pausa", "일시정지", "Pauze", "Paus", "暂停"
)
fill["common.error"] = row(
    "Fehler", "Error", "Erreur", "Errore", "오류", "Fout", "Fel", "错误"
)
fill["common.home"] = row(
    "Start", "Inicio", "Accueil", "Home", "홈", "Home", "Hem", "主页"
)
fill["common.later"] = row(
    "Später", "Más tarde", "Plus tard", "Più tardi", "나중에", "Later", "Senare", "稍后"
)
fill["common.quickConnect"] = row(
    "Quick Connect", "Quick Connect", "Quick Connect", "Quick Connect", "퀵 커넥트", "Quick Connect", "Snabbanslutning", "快速连接"
)
fill["common.quickConnectCode"] = row(
    "Quick-Connect-Code", "Código Quick Connect", "Code Quick Connect", "Codice Quick Connect", "퀵 커넥트 코드", "Quick Connect-code", "Quick Connect-kod", "快速连接代码"
)
fill["common.quickConnectDescription"] = row(
    "Um dich mit Quick Connect anzumelden, tippe auf dem Gerät, von dem du dich anmeldest, auf „Quick Connect“, und gib den angezeigten Code unten ein.",
    "Para iniciar sesión con Quick Connect, pulsa el botón «Quick Connect» en el dispositivo desde el que inicias sesión e introduce el código que aparece abajo.",
    "Pour vous connecter avec Quick Connect, appuyez sur le bouton « Quick Connect » sur l’appareil depuis lequel vous vous connectez, puis saisissez le code affiché ci-dessous.",
    "Per accedere con Quick Connect, tocca il pulsante «Quick Connect» sul dispositivo da cui stai effettuando l’accesso e inserisci il codice mostrato qui sotto.",
    "Quick Connect로 로그인하려면 로그인하는 기기에서 ‘Quick Connect’ 버튼을 누르고 아래에 표시된 코드를 입력하세요.",
    "Om in te loggen met Quick Connect, tik je op het apparaat waar je mee inlogt op de knop ‘Quick Connect’ en voer je de getoonde code hieronder in.",
    "För att logga in med Quick Connect trycker du på knappen «Quick Connect» på enheten du loggar in från och anger koden som visas nedan.",
    "使用快速连接登录时，请在用于登录的设备上选择“快速连接”按钮，然后在下方输入显示的代码。"
)
fill["common.quickConnectError"] = row(
    "Quick-Connect-Code konnte nicht autorisiert werden",
    "No se pudo autorizar el código Quick Connect",
    "Échec de l’autorisation du code Quick Connect",
    "Autorizzazione del codice Quick Connect non riuscita",
    "Quick Connect 코드 승인에 실패했습니다",
    "Quick Connect-code autoriseren mislukt",
    "Det gick inte att auktorisera Quick Connect-koden",
    "快速连接代码授权失败"
)
fill["common.quickConnectSuccess"] = row(
    "Quick Connect erfolgreich autorisiert",
    "Quick Connect autorizado correctamente",
    "Quick Connect autorisé avec succès",
    "Quick Connect autorizzato correttamente",
    "Quick Connect가 성공적으로 승인되었습니다",
    "Quick Connect succesvol geautoriseerd",
    "Quick Connect har auktoriserats",
    "快速连接已成功授权"
)

# --- liveTv (EN strings from en.i18n.json) ---
fill["liveTv.cancelSeries"] = row(
    "Serie abbrechen", "Cancelar serie", "Annuler la série", "Annulla serie", "시리즈 취소", "Serie annuleren", "Avbryt serie", "取消系列"
)
fill["liveTv.cancelTimer"] = row(
    "Aufnahme abbrechen", "Cancelar grabación", "Annuler l’enregistrement", "Annulla registrazione", "녹화 취소", "Opname annuleren", "Avbryt inspelning", "取消录制"
)
fill["liveTv.cancelTimerConfirm"] = row(
    "Möchten Sie diese geplante Aufnahme wirklich abbrechen?",
    "¿Seguro que quieres cancelar esta grabación programada?",
    "Voulez-vous vraiment annuler cet enregistrement planifié ?",
    "Annullare questa registrazione programmata?",
    "이 예약 녹화를 취소할까요?",
    "Weet je zeker dat je deze geplande opname wilt annuleren?",
    "Vill du verkligen avbryta den här schemalagda inspelningen?",
    "确定要取消此预约录制吗？"
)
fill["liveTv.days"] = row("Tage", "Días", "Jours", "Giorni", "일", "Dagen", "Dagar", "天")
fill["liveTv.deleteSeriesTimer"] = row(
    "Serien-Timer löschen", "Eliminar temporizador de serie", "Supprimer la minuterie de série", "Elimina timer serie", "시리즈 타이머 삭제", "Serietimer verwijderen", "Ta bort serietimer", "删除系列定时器"
)
fill["liveTv.deleteSeriesTimerConfirm"] = row(
    "Möchten Sie diesen Serien-Timer wirklich löschen? Alle zugehörigen geplanten Aufnahmen werden ebenfalls entfernt.",
    "¿Seguro que quieres eliminar este temporizador de serie? También se eliminarán todas las grabaciones programadas asociadas.",
    "Voulez-vous vraiment supprimer cette minuterie de série ? Tous les enregistrements planifiés associés seront également supprimés.",
    "Eliminare questo timer di serie? Verranno rimossi anche tutti gli eventi di registrazione associati.",
    "이 시리즈 타이머를 삭제할까요? 연결된 모든 예약 녹화도 제거됩니다.",
    "Weet je zeker dat je deze serietimer wilt verwijderen? Alle bijbehorende geplande opnames worden ook verwijderd.",
    "Vill du verkligen ta bort den här serietimern? Alla associerade schemalagda inspelningar tas också bort.",
    "确定要删除此系列定时器吗？所有关联的预约录制也将被移除。"
)
fill["liveTv.doNotRecord"] = row(
    "Nicht aufnehmen", "No grabar", "Ne pas enregistrer", "Non registrare", "녹화 안 함", "Niet opnemen", "Spela inte in", "不录制"
)
fill["liveTv.forKids"] = row(
    "Für Kinder", "Para niños", "Pour enfants", "Per bambini", "어린이용", "Voor kinderen", "För barn", "儿童"
)
fill["liveTv.keepAll"] = row(
    "Alle behalten", "Conservar todo", "Tout conserver", "Conserva tutto", "모두 보관", "Alles bewaren", "Behåll alla", "全部保留"
)
fill["liveTv.keepUpTo"] = row(
    "Behalten bis zu", "Conservar hasta", "Conserver jusqu’à", "Conserva fino a", "최대 보관", "Bewaar tot", "Behåll upp till", "最多保留"
)
fill["liveTv.noRecordings"] = row(
    "Keine Aufnahmen", "Sin grabaciones", "Aucun enregistrement", "Nessuna registrazione", "녹화 없음", "Geen opnames", "Inga inspelningar", "无录制"
)
fill["liveTv.noScheduled"] = row(
    "Keine geplanten Aufnahmen", "Sin grabaciones programadas", "Aucun enregistrement planifié", "Nessuna registrazione programmata", "예약된 녹화 없음", "Geen geplande opnames", "Inga schemalagda inspelningar", "无预约录制"
)
fill["liveTv.noSubscriptions"] = row(
    "Keine Serien-Timer", "Sin temporizadores de serie", "Aucune minuterie de série", "Nessun timer di serie", "시리즈 타이머 없음", "Geen serietimers", "Inga serietimers", "无系列定时器"
)
fill["liveTv.onNow"] = row(
    "Jetzt live", "En emisión", "En direct", "In onda", "생방송", "Nu live", "Sänds nu", "正在播出"
)
fill["liveTv.postPadding"] = row(
    "Nach Ende weiter aufnehmen", "Seguir grabando después", "Continuer après la fin", "Continua dopo la fine", "종료 후 계속 녹화", "Door opnemen na afloop", "Fortsätt spela in efter", "结束后继续录制"
)
fill["liveTv.prePadding"] = row(
    "Vor Beginn starten", "Empezar a grabar antes", "Commencer avant l’heure", "Inizia prima dell’orario", "시작 전에 녹화 시작", "Vroeger beginnen met opnemen", "Börja spela in i förväg", "提前开始录制"
)
fill["liveTv.priority"] = row(
    "Priorität", "Prioridad", "Priorité", "Priorità", "우선순위", "Prioriteit", "Prioritet", "优先级"
)
fill["liveTv.programs"] = row(
    "Sendungen", "Programas", "Programmes", "Programmi", "프로그램", "Programma’s", "Program", "节目"
)
fill["liveTv.recentlyAdded"] = row(
    "Kürzlich hinzugefügt", "Añadido recientemente", "Récemment ajouté", "Aggiunti di recente", "최근 추가", "Recent toegevoegd", "Nyligen tillagt", "最近添加"
)
fill["liveTv.recordNewOnly"] = row(
    "Nur neue Folgen aufnehmen", "Grabar solo episodios nuevos", "Enregistrer uniquement les nouveaux épisodes", "Registra solo i nuovi episodi", "새 에피소드만 녹화", "Alleen nieuwe afleveringen opnemen", "Spela in endast nya avsnitt", "仅录制新剧集"
)
fill["liveTv.recordingFailed"] = row(
    "Aufnahme konnte nicht geplant werden", "No se pudo programar la grabación", "Échec de la planification de l’enregistrement", "Impossibile pianificare la registrazione", "녹화 예약 실패", "Opname plannen mislukt", "Det gick inte att schemalägga inspelningen", "预约录制失败"
)
fill["liveTv.recordingScheduled"] = row(
    "Aufnahme geplant", "Grabación programada", "Enregistrement planifié", "Registrazione pianificata", "녹화 예약됨", "Opname gepland", "Inspelning schemalagd", "已预约录制"
)
fill["liveTv.seriesRecordingScheduled"] = row(
    "Serienaufnahme geplant", "Grabación de serie programada", "Enregistrement de série planifié", "Registrazione serie pianificata", "시리즈 녹화 예약됨", "Serie-opname gepland", "Serieinspelning schemalagd", "已预约系列录制"
)
fill["liveTv.seriesTimerDeleted"] = row(
    "Serien-Timer gelöscht", "Temporizador de serie eliminado", "Minuterie de série supprimée", "Timer di serie eliminato", "시리즈 타이머 삭제됨", "Serietimer verwijderd", "Serietimer borttagen", "系列定时器已删除"
)
fill["liveTv.seriesTimerUpdated"] = row(
    "Serien-Timer aktualisiert", "Temporizador de serie actualizado", "Minuterie de série mise à jour", "Timer di serie aggiornato", "시리즈 타이머 업데이트됨", "Serietimer bijgewerkt", "Serietimer uppdaterad", "系列定时器已更新"
)
fill["liveTv.seriesTimers"] = row(
    "Serien-Timer", "Temporizadores de série", "Minuteries de série", "Timer di serie", "시리즈 타이머", "Serietimers", "Serietimers", "系列定时器"
)
fill["liveTv.stopRecording"] = row(
    "Aufnahme stoppen", "Detener grabación", "Arrêter l’enregistrement", "Interrompi registrazione", "녹화 중지", "Opname stoppen", "Stoppa inspelning", "停止录制"
)
fill["liveTv.timerCancelled"] = row(
    "Aufnahme abgebrochen", "Grabación cancelada", "Enregistrement annulé", "Registrazione annullata", "녹화 취소됨", "Opname geannuleerd", "Inspelning avbruten", "录制已取消"
)
fill["liveTv.upcomingMovies"] = row("Filme", "Películas", "Films", "Film", "영화", "Films", "Filmer", "电影")
fill["liveTv.upcomingNews"] = row("Nachrichten", "Noticias", "Infos", "Notizie", "뉴스", "Nieuws", "Nyheter", "新闻")
fill["liveTv.upcomingShows"] = row("Serien", "Series", "Séries", "Serie TV", "시리즈", "Series", "Serier", "剧集")
fill["liveTv.upcomingSports"] = row("Sport", "Deportes", "Sport", "Sport", "스포츠", "Sport", "Sport", "体育")
fill["liveTv.guide"] = row(
    "TV-Programm", "Guía", "Guide", "Guida TV", "가이드", "Tv-gids", "Tablå", "节目指南"
)

# --- discover ---
fill["discover.moviesAndShows"] = row(
    "Filme & Serien", "Películas y series", "Films et séries", "Film e serie", "영화 및 시리즈", "Films en series", "Filmer och serier", "电影和节目"
)
fill["discover.noItemsFound"] = row(
    "Auf diesem Server wurden keine Elemente gefunden",
    "No se encontraron elementos en este servidor",
    "Aucun élément trouvé sur ce serveur",
    "Nessun elemento trovato su questo server",
    "이 서버에서 항목을 찾을 수 없습니다",
    "Geen items gevonden op deze server",
    "Inga objekt hittades på den här servern",
    "此服务器上未找到任何项目"
)
fill["discover.studio"] = row("Studio", "Estudio", "Studio", "Studio", "스튜디오", "Studio", "Studio", "工作室")
fill["discover.cast"] = row("Besetzung", "Reparto", "Distribution", "Cast", "출연", "Cast", "Ensemble", "演职员")

# --- companion remote ---
fill["companionRemote.title"] = row(
    "Begleitfernbedienung", "Control remoto compañero", "Télécommande compagnon", "Telecomando companion", "동반 리모컨", "Companion-afstandsbediening", "Följande fjärrkontroll", "伴侣遥控器"
)
fill["companionRemote.remote.tabDownloads"] = row(
    "Herunterladungen", "Descargas", "Téléchargements", "Download", "다운로드", "Downloads", "Hämtningar", "下载"
)
fill["companionRemote.pairing.manual"] = row(
    "Manuell", "Manual", "Manuel", "Manuale", "수동", "Handmatig", "Manuellt", "手动"
)
fill["companionRemote.pairing.tips"] = row(
    "Tipps", "Consejos", "Astuces", "Suggerimenti", "팁", "Tips", "Tips", "提示"
)
fill["companionRemote.pairing.recent"] = row(
    "Zuletzt", "Recientes", "Récent", "Recenti", "최근", "Recent", "Senaste", "最近"
)
fill["companionRemote.remote.menu"] = row("Menü", "Menú", "Menu", "Menu", "메뉴", "Menu", "Meny", "菜单")
fill["companionRemote.remote.volume"] = row(
    "Lautstärke", "Volumen", "Volume", "Volume", "음량", "Volume", "Volym", "音量"
)

# --- navigation / downloads ---
fill["navigation.downloads"] = row(
    "Herunterladungen", "Descargas", "Téléchargements", "Download", "다운로드", "Downloads", "Hämtningar", "下载"
)
fill["downloads.title"] = row(
    "Herunterladungen", "Descargas", "Téléchargements", "Download", "다운로드", "Downloads", "Hämtningar", "下载"
)
fill["downloads.downloadNow"] = row(
    "Herunterladen", "Descargar", "Télécharger", "Scarica", "다운로드", "Downloaden", "Ladda ner", "下载"
)
fill["navigation.liveTv"] = row(
    "Live-TV", "TV en vivo", "TV en direct", "TV in diretta", "라이브 TV", "Live tv", "Live-TV", "直播电视"
)
fill["liveTv.title"] = row(
    "Live-TV", "TV en vivo", "TV en direct", "TV in diretta", "라이브 TV", "Live tv", "Live-TV", "直播电视"
)

# --- search categories ---
for key, de, es, fr, it, ko, nl, sv, zh in [
    ("channels", "Sender", "Canales", "Chaînes", "Canali", "채널", "Kanalen", "Kanaler", "频道"),
    ("collections", "Sammlungen", "Colecciones", "Collections", "Collezioni", "컬렉션", "Collecties", "Samlingar", "合集"),
    ("episodes", "Episoden", "Episodios", "Épisodes", "Episodi", "에피소드", "Afleveringen", "Avsnitt", "剧集"),
    ("movies", "Filme", "Películas", "Films", "Film", "영화", "Films", "Filmer", "电影"),
    ("people", "Personen", "Personas", "Personnes", "Persone", "인물", "Personen", "Personer", "人物"),
    ("programs", "Sendungen", "Programas", "Programmes", "Programmi", "프로그램", "Programma’s", "Program", "节目"),
    ("shows", "Serien", "Series", "Séries", "Serie TV", "시리즈", "Series", "Serier", "节目"),
]:
    fill[f"search.categories.{key}"] = row(de, es, fr, it, ko, nl, sv, zh)

# --- settings (feature flags / descriptions) ---
fill["settings.enableChapterImages"] = row(
    "Kapitelbilder aktivieren", "Activar imágenes de capítulos", "Activer les images de chapitres", "Abilita immagini dei capitoli", "챕터 이미지 사용", "Hoofdstukafbeeldingen inschakelen", "Aktivera kapitelbilder", "启用章节图像"
)
fill["settings.enableChapterImagesDescription"] = row(
    "Zeigt Vorschaubilder für Kapitel in der Kapitelliste.",
    "Muestra miniaturas de capítulos en la lista de capítulos.",
    "Affiche des miniatures de chapitres dans la liste des chapitres.",
    "Mostra le anteprime dei capitoli nell’elenco dei capitoli.",
    "챕터 목록에서 챕터 미리보기 썸네일을 표시합니다.",
    "Toont miniatuurafbeeldingen voor hoofdstukken in de hoofdstukkenlijst.",
    "Visar miniatyrbilder för kapitel i kapitellistan.",
    "在章节列表中显示章节缩略图。"
)
fill["settings.enableExternalSubtitles"] = row(
    "Externe Untertitel aktivieren", "Activar subtítulos externos", "Activer les sous-titres externes", "Abilita sottotitoli esterni", "외부 자막 사용", "Externe ondertitels inschakelen", "Aktivera externa undertexter", "启用外部字幕"
)
fill["settings.enableExternalSubtitlesDescription"] = row(
    "Zeigt externe Untertiteloptionen im Player; sie werden geladen, wenn du eine auswählst.",
    "Muestra opciones de subtítulos externos en el reproductor; se cargan al seleccionar una.",
    "Affiche les options de sous-titres externes dans le lecteur ; ils se chargent lorsque vous en sélectionnez un.",
    "Mostra le opzioni dei sottotitoli esterni nel lettore; vengono caricati quando ne selezioni uno.",
    "플레이어에서 외부 자막 옵션을 표시하며, 선택 시 로드됩니다.",
    "Toont externe ondertitelopties in de speler; ze worden geladen wanneer je er een kiest.",
    "Visar externa undertextalternativ i spelaren; de laddas när du väljer en.",
    "在播放器中显示外部字幕选项；选择后才会加载。"
)
fill["settings.enableTrickplay"] = row(
    "Trickplay-Vorschaubilder aktivieren", "Activar miniaturas Trickplay", "Activer les miniatures Trickplay", "Abilita anteprime Trickplay", "트릭플레이 썸네일 사용", "Trickplay-miniaturen inschakelen", "Aktivera trickplay-miniatyrer", "启用 Trickplay 缩略图"
)
fill["settings.enableTrickplayDescription"] = row(
    "Zeigt beim Suchen Vorschaubilder in der Zeitleiste. Erfordert Trickplay-Daten auf dem Server.",
    "Muestra miniaturas en la línea de tiempo al buscar. Requiere datos Trickplay en el servidor.",
    "Affiche des miniatures sur la timeline lors du défilement. Nécessite des données Trickplay sur le serveur.",
    "Mostra le anteprime sulla timeline durante la ricerca. Richiede dati Trickplay sul server.",
    "탐색 시 타임라인에 썸네일을 표시합니다. 서버에 트릭플레이 데이터가 있어야 합니다.",
    "Toont tijdlijnvoorbeelden tijdens zoeken. Vereist trickplay-gegevens op de server.",
    "Visar tidslinjeminiatyrer vid skrubbning. Kräver trickplay-data på servern.",
    "拖动时间轴时显示预览缩略图。需要服务器上有 Trickplay 数据。"
)
fill["settings.showDownloads"] = row(
    "Downloads aktivieren", "Activar descargas", "Activer les téléchargements", "Abilita download", "다운로드 사용", "Downloads inschakelen", "Aktivera nedladdningar", "启用下载"
)
fill["settings.showDownloadsDescription"] = row(
    "Ermöglicht das Herunterladen von Filmen und Serien für die Offline-Wiedergabe.",
    "Permite descargar películas y series para ver sin conexión.",
    "Permet de télécharger films et séries pour une lecture hors ligne.",
    "Consente di scaricare film e serie per la visione offline.",
    "영화와 시리즈를 다운로드해 오프라인으로 시청할 수 있게 합니다.",
    "Maakt het mogelijk om films en series te downloaden voor offline kijken.",
    "Gör det möjligt att ladda ner filmer och serier för offlinevisning.",
    "允许下载电影和节目以供离线观看。"
)
fill["settings.downloads"] = row(
    "Downloads", "Descargas", "Téléchargements", "Download", "다운로드", "Downloads", "Hämtningar", "下载"
)
fill["settings.downloadQualityOriginal"] = row(
    "Original", "Original", "Original", "Originale", "원본", "Origineel", "Original", "原始"
)
fill["settings.normal"] = row("Normal", "Normal", "Normal", "Normale", "보통", "Normaal", "Normal", "正常")
fill["settings.playbackModeAuto"] = row("Auto", "Auto", "Auto", "Auto", "자동", "Auto", "Auto", "自动")
fill["settings.playbackModeAutoDirect"] = row(
    "Auto – Direkt", "Auto - Directo", "Auto - Direct", "Auto - Diretta", "자동 - 직접", "Auto - Direct", "Auto - Direkt", "自动 - 直接"
)
fill["settings.playbackModeDirectPlay"] = row(
    "Direkt", "Directo", "Direct", "Diretta", "직접", "Direct", "Direkt", "直接播放"
)
fill["settings.liveTvMpv"] = row(
    "MPV (empfohlen)", "MPV (recomendado)", "MPV (recommandé)", "MPV (consigliato)", "MPV(권장)", "MPV (aanbevolen)", "MPV (rekommenderas)", "MPV（推荐）"
)
fill["settings.system"] = row("System", "Sistema", "Système", "Sistema", "시스템", "Systeem", "System", "系统")
fill["settings.systemTheme"] = row(
    "System", "Sistema", "Système", "Sistema", "시스템", "Systeem", "System", "跟随系统"
)
fill["settings.updates"] = row(
    "Updates", "Actualizaciones", "Mises à jour", "Aggiornamenti", "업데이트", "Updates", "Uppdateringar", "更新"
)
fill["settings.compact"] = row(
    "Kompakt", "Compacto", "Compact", "Compatto", "콤팩트", "Compact", "Kompakt", "紧凑"
)
fill["settings.animations"] = row(
    "Animationen", "Animaciones", "Animations", "Animazioni", "애니메이션", "Animaties", "Animationer", "动画"
)
fill["settings.darkTheme"] = row(
    "Dunkel", "Oscuro", "Sombre", "Scuro", "다크", "Donker", "Mörkt", "深色"
)
fill["settings.lightTheme"] = row(
    "Hell", "Claro", "Clair", "Chiaro", "라이트", "Licht", "Ljust", "浅色"
)
fill["settings.minutesLabel"] = row(
    "Minuten", "Minutos", "Minutes", "Minuti", "분", "Minuten", "Minuter", "分钟"
)
fill["settings.largeSkipDuration"] = row(
    "Großer Sprung", "Salto grande", "Grand saut", "Salto grande", "긴 건너뛰기", "Grote sprong", "Långt hopp", "大幅跳过"
)
fill["settings.smallSkipDuration"] = row(
    "Kleiner Sprung", "Salto pequeño", "Petit saut", "Salto piccolo", "짧은 건너뛰기", "Kleine sprong", "Kort hopp", "小幅跳过"
)
fill["settings.performanceMedium"] = row(
    "Mittel", "Medio", "Moyen", "Medio", "중간", "Gemiddeld", "Medium", "中等"
)

# --- libraries / collections / playlists ---
fill["libraries.tabs.genres"] = row(
    "Genres", "Géneros", "Genres", "Generi", "장르", "Genres", "Genrer", "类型"
)
fill["libraries.tabs.collections"] = row(
    "Sammlungen", "Colecciones", "Collections", "Collezioni", "컬렉션", "Collecties", "Samlingar", "合集"
)
fill["libraries.tabs.playlists"] = row(
    "Wiedergabelisten", "Listas de reproducción", "Listes de lecture", "Playlist", "재생목록", "Afspeellijsten", "Spellistor", "播放列表"
)
fill["libraries.tabs.suggestions"] = row(
    "Vorschläge", "Sugerencias", "Suggestions", "Suggerimenti", "추천", "Suggesties", "Förslag", "建议"
)
fill["libraries.filters"] = row(
    "Filter", "Filtros", "Filtres", "Filtri", "필터", "Filters", "Filter", "筛选"
)
fill["collections.collection"] = row(
    "Sammlung", "Colección", "Collection", "Collezione", "컬렉션", "Collectie", "Samling", "合集"
)
fill["collections.title"] = row(
    "Sammlungen", "Colecciones", "Collections", "Collezioni", "컬렉션", "Collecties", "Samlingar", "合集"
)
fill["playlists.playlist"] = row(
    "Wiedergabeliste", "Lista de reproducción", "Liste de lecture", "Playlist", "재생목록", "Afspeellijst", "Spellista", "播放列表"
)
fill["playlists.title"] = row(
    "Wiedergabelisten", "Listas de reproducción", "Listes de lecture", "Playlist", "재생목록", "Afspeellijsten", "Spellistor", "播放列表"
)
fill["playlists.selectPlaylist"] = row(
    "Wiedergabeliste wählen", "Seleccionar lista", "Choisir une liste", "Seleziona playlist", "재생목록 선택", "Afspeellijst kiezen", "Välj spellista", "选择播放列表"
)
fill["playlists.oneItem"] = row(
    "1 Element", "1 elemento", "1 élément", "1 elemento", "1개 항목", "1 onderdeel", "1 objekt", "1 项"
)

# --- fileInfo (translate where not universal) ---
fill["fileInfo.bitrate"] = row(
    "Bitrate", "Bitrate", "Débit", "Bitrate", "비트레이트", "Bitrate", "Bitrate", "码率"
)
fill["fileInfo.codec"] = row(
    "Codec", "Códec", "Codec", "Codec", "코덱", "Codec", "Codec", "编解码器"
)
fill["fileInfo.container"] = row(
    "Container", "Contenedor", "Conteneur", "Contenitore", "컨테이너", "Container", "Container", "容器"
)
fill["fileInfo.aspectRatio"] = row(
    "Seitenverhältnis", "Relación de aspecto", "Format d’image", "Proporzioni", "화면 비율", "Beeldverhouding", "Bildförhållande", "宽高比"
)
fill["fileInfo.file"] = row("Datei", "Archivo", "Fichier", "File", "파일", "Bestand", "Fil", "文件")
fill["fileInfo.frameRate"] = row(
    "Bildrate", "Velocidad de fotogramas", "Images par seconde", "Frequenza fotogrammi", "프레임 속도", "Framesnelheid", "Bildfrekvens", "帧率"
)
fill["fileInfo.has64bitOffsets"] = row(
    "64-Bit-Offsets", "Offsets de 64 bits", "Offsets 64 bits", "Offset 64 bit", "64비트 오프셋", "64-bits offsets", "64-bitars offset", "64 位偏移"
)
fill["fileInfo.channels"] = row(
    "Kanäle", "Canales", "Canaux", "Canali", "채널", "Kanalen", "Kanaler", "声道"
)

# --- video controls / shaders / logs ---
fill["videoControls.letterbox"] = row(
    "Letterbox", "Bandas negras", "Lettrebox", "Letterbox", "레터박스", "Letterbox", "Letterbox", "黑边"
)
fill["videoControls.pauseButton"] = row(
    "Pause", "Pausa", "Pause", "Pausa", "일시정지", "Pauze", "Paus", "暂停"
)
fill["videoControls.muteButton"] = row(
    "Stummschalten", "Silenciar", "Couper le son", "Disattiva audio", "음소거", "Dempen", "Ljud av", "静音"
)
fill["videoControls.alwaysOnTopButton"] = row(
    "Immer im Vordergrund", "Siempre encima", "Toujours au premier plan", "Sempre in primo piano", "항상 위에", "Altijd bovenop", "Alltid överst", "置顶"
)
fill["subtitlingStyling.position"] = row(
    "Position", "Posición", "Position", "Posizione", "위치", "Positie", "Position", "位置"
)
fill["shaders.title"] = row(
    "Shader", "Sombreadores", "Shaders", "Shader", "셰이더", "Shaders", "Shader", "着色器"
)
fill["shaders.mode"] = row("Modus", "Modo", "Mode", "Modalità", "모드", "Modus", "Läge", "模式")
fill["screens.logs"] = row("Protokolle", "Registros", "Journaux", "Log", "로그", "Logboeken", "Loggar", "日志")
fill["screens.licenses"] = row("Lizenzen", "Licencias", "Licences", "Licenze", "라이선스", "Licenties", "Licenser", "许可证")
fill["logs.error"] = row("Fehler:", "Error:", "Erreur :", "Errore:", "오류:", "Fout:", "Fel:", "错误：")
fill["userStatus.admin"] = row("Admin", "Admin", "Admin", "Admin", "관리자", "Beheerder", "Admin", "管理员")
fill["auth.jellyfinPassword"] = row(
    "Passwort", "Contraseña", "Mot de passe", "Password", "비밀번호", "Wachtwoord", "Lösenord", "密码"
)
fill["auth.jellyfinServerUrlHint"] = row(
    "https://dein-jellyfin.beispiel.de",
    "https://tu-jellyfin.ejemplo.com",
    "https://votre-jellyfin.exemple.com",
    "https://tuo-jellyfin.esempio.com",
    "https://your-jellyfin.example.com",
    "https://jouw-jellyfin.voorbeeld.nl",
    "https://din-jellyfin.exempel.se",
    "https://your-jellyfin.example.com"
)

fill["mpvConfig.propertyKeyHint"] = row(
    "z. B. hwdec, demuxer-max-bytes",
    "p. ej., hwdec, demuxer-max-bytes",
    "p. ex. hwdec, demuxer-max-bytes",
    "es. hwdec, demuxer-max-bytes",
    "예: hwdec, demuxer-max-bytes",
    "bijv. hwdec, demuxer-max-bytes",
    "t.ex. hwdec, demuxer-max-bytes",
    "例如 hwdec、demuxer-max-bytes"
)
fill["mpvConfig.propertyValueHint"] = row(
    "z. B. auto, 256000000",
    "p. ej. auto, 256000000",
    "p. ex. auto, 256000000",
    "es. auto, 256000000",
    "예: auto, 256000000",
    "bijv. auto, 256000000",
    "t.ex. auto, 256000000",
    "例如 auto、256000000"
)

# Note: settings.quality*Mbps left English (international units) — script only replaces == en

with open("tool/i18n_fill.json", "w", encoding="utf-8") as f:
    json.dump(fill, f, ensure_ascii=False, indent=2)
print("Wrote", len(fill), "keys to tool/i18n_fill.json")
