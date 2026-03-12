## Base Screenshots

16 source images (4 devices × 4 screens): `desktop-*`, `tablet-*`, `phone-*`, `tv-*` × `home`, `library`, `media-card`, `season`.

After updating these, run: `python scripts/generate_screenshot_assets.py` to regenerate all derived assets.

## Generated Assets

### webp/

WebP versions of all 16 base screenshots (same filenames). For web use.

### extras/

- **playstore-feature-graphic.png** — 1024×500, tablet-home resize to 1024×640 then center crop
- **tv-banner-1280x720.png** — 1280×720, letterbox from tv-home

### App Store (iPhone & iPad)

Resized from phone/tablet assets for App Store Connect upload.

- **appstore-iphone/** — 1284×2778 (4 screenshots, cover)
- **appstore-ipad/** — 2752×2064 (4 screenshots, letterbox)

### Amazon Fire Store

- **amazonfire-tablet/** — Screenshots (1920×1200, letterbox), icons (512×512, 114×114, unchanged)
- **amazonfire-tv/** — Screenshots (1920×1080, letterbox), background = copy of tv-home. TV banner (tv_banner-1280x720.png) is an icon—do not regenerate.

## Device Previews

### Desktop

![Desktop Home](desktop-home.png) ![Desktop Library](desktop-library.png) ![Desktop Media Card](desktop-media-card.png) ![Desktop Season](desktop-season.png)

### Tablet

![Tablet Home](tablet-home.png) ![Tablet Library](tablet-library.png) ![Tablet Media Card](tablet-media-card.png) ![Tablet Season](tablet-season.png)

### Phone

![Phone Home](phone-home.png) ![Phone Library](phone-library.png) ![Phone Media Card](phone-media-card.png) ![Phone Season](phone-season.png)

### TV

![TV Home](tv-home.png) ![TV Library](tv-library.png) ![TV Media Card](tv-media-card.png) ![TV Season](tv-season.png)
