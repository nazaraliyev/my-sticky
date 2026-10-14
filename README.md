# Nota

macOS üçün yüngül, native sticky-notes widget-i. Notlar ekranda tünd "şüşə" pəncərələr kimi durur,
Markdown canlı render olunur, checkbox-lar kliklə işarələnir. Dock-da ikon yoxdur — tətbiq yalnız
not pəncərələri və menu bar ikonu kimi yaşayır.

SwiftPM + AppKit ilə yazılıb, heç bir xarici asılılığı yoxdur.

## Xüsusiyyətlər

- **Bir neçə not** — hər not ayrıca pəncərədir; `+` düyməsi və ya menu bar → "Yeni not" ilə yenisini aç.
- **Canlı Markdown** — sintaksis işarələri (`**`, `~~`, `#` …) gizlənir, yalnız kursorun olduğu sətirdə görünür ki, redaktə edə biləsən.
- **İnteraktiv checkbox-lar** — `[]` yaz, avtomatik checkbox-a çevrilir; klik edəndə işarələnir.
- **Siyahı davamı** — Enter checkbox, bullet və nömrəli siyahını davam etdirir; boş maddədə Enter siyahıdan çıxır.
- **Qlobal qısayol** — `⌥⌘N` istənilən yerdən bütün notları önə gətirir.
- **Həmişə üstdə** — notları bütün pəncərələrin üstündə və bütün Spaces-də saxla.
- **Login-da başlat** — kompüter açılanda avtomatik işə düşür.
- **Avtomatik yadda saxlama** — hər not adi `.md` faylıdır; pəncərənin yeri və ölçüsü də yadda qalır.

## Tələblər

- macOS 14 (Sonoma) və ya daha yeni
- Swift 6 toolchain (Xcode və ya Command Line Tools)

## Quraşdırma

```bash
git clone git@github.com:nazaraliyev/my-sticky.git
cd my-sticky
./scripts/install.sh
```

Skript tətbiqi build edir, `/Applications`-a (yazma icazəsi yoxdursa `~/Applications`-a) köçürür,
işə salır və login item kimi qeydiyyatdan keçirir. Kodu dəyişəndən sonra yenidən işə sal — köhnə
versiyanı özü bağlayıb əvəz edir.

Yalnız `.app` bundle lazımdırsa:

```bash
./scripts/make_app.sh   # dist/Nota.app yaradır
open dist/Nota.app
```

## İstifadə

Menu bar-dakı not ikonu tətbiqin əsas idarəetməsidir:

| Menyu                        | Nə edir                                              |
| ---------------------------- | ---------------------------------------------------- |
| Yeni not                     | Yeni boş not açır                                    |
| Bütün notları göstər (⌥⌘N)   | Gizlədilmiş notlar da daxil, hamısını önə gətirir   |
| Həmişə üstdə (bütün Spaces)  | Notları digər pəncərələrin üstündə saxlayır          |
| Login-da başlat              | Avtomatik başlamağı yandırıb-söndürür                |
| Çıxış                        | Tətbiqdən çıxır                                      |

Pəncərə düymələri siçanı notun üzərinə gətirəndə görünür. Notu istənilən boş yerindən sürüşdürüb
daşıya bilərsən. Qırmızı düymə:

- **boş** notu tamamilə silir;
- **məzmunlu** notu sadəcə gizlədir — `⌥⌘N` ilə geri qaytarılır.

### Qısayollar

| Qısayol         | Əməliyyat                                   |
| --------------- | ------------------------------------------- |
| `⌥⌘N`           | Bütün notları göstər (qlobal, hər yerdən)   |
| `⌘B` / `⌘I`     | Qalın / əyri                                |
| `⌘=` / `⌘-`     | Şrifti böyüt / kiçilt (bütün notlarda)      |
| `⌘Z` / `⇧⌘Z`    | Geri al / təkrarla                          |
| `⌘Q`            | Çıxış                                       |

Qlobal qısayol Carbon `RegisterEventHotKey` ilə qeyd olunur, ona görə Accessibility icazəsi tələb etmir.

### Dəstəklənən Markdown

| Yazırsan                 | Nəticə                     |
| ------------------------ | -------------------------- |
| `# Başlıq` … `###### `   | Başlıqlar                  |
| `**qalın**`              | **qalın**                  |
| `*əyri*` və ya `_əyri_`  | *əyri*                     |
| `~~xətli~~`              | ~~xətli~~                  |
| `` `kod` ``              | `kod`                      |
| `<u>altı xətli</u>`      | altı xətli                 |
| `> sitat`                | Girintili, solğun sitat    |
| `- `, `* `, `+ `         | Bullet siyahı              |
| `1. `                    | Nömrəli siyahı             |
| `[]`, `[ ]`, `[x]`       | Checkbox                   |

## Məlumatlar harada saxlanılır

- **Notlar:** `~/Library/Application Support/Nota/note-<id>.md` — adi Markdown, istənilən redaktorla açıla və sinxronlaşdırıla bilər.
- **Ayarlar** (notların siyahısı, pəncərə yerləri, şrift ölçüsü, "həmişə üstdə"): `UserDefaults`, bundle ID `com.nazar.nota`.

## Development

```bash
swift build
swift run Nota               # tətbiqi birbaşa işə salır
swift run Nota --selftest    # pəncərəsiz yoxlamalar (Markdown round-trip, checkbox, siyahılar)
```

"Login-da başlat" yalnız `.app` bundle-dan işləyəndə işləyir (`SMAppService` tələbi), ona görə
`swift run` ilə test edəndə bu seçim təsirsizdir.

### Struktur

```
Sources/Nota/
├── main.swift                 # Giriş nöqtəsi, --selftest
├── AppDelegate.swift          # Gizli main menu (qısayollar), başlanğıc
├── NoteManager.swift          # Bütün notların idarəsi
├── NoteWindowController.swift # Bir not pəncərəsi: chrome, rejim, autosave
├── NotePanel.swift            # NSPanel alt sinfi
├── ChromeViews.swift          # Hover effekti, "kağız" fon
├── MarkdownTextView.swift     # Redaktor: canlı preview, checkbox, siyahı davamı
├── MarkdownRenderer.swift     # Markdown ⇄ NSAttributedString
├── CheckboxAttachment.swift   # Kliklənən checkbox
├── NoteDocument.swift         # Bir notun .md faylı
├── Storage.swift              # Fayl yerləri, başlanğıc not
├── Settings.swift             # UserDefaults wrapper
├── StatusBarController.swift  # Menu bar ikonu və menyu
├── GlobalHotKey.swift         # ⌥⌘N
├── LaunchAtLogin.swift        # SMAppService wrapper
└── SelfTest.swift             # Headless testlər
packaging/Info.plist           # Bundle metadata (LSUIElement — Dock ikonu yoxdur)
scripts/make_app.sh            # dist/Nota.app yaradır
scripts/install.sh             # Build + quraşdırma + login item
```

## Silmək

1. Menu bar → "Login-da başlat" seçimini söndür, sonra "Çıxış".
2. `/Applications/Nota.app`-ı sil.
3. Notları da silmək istəyirsənsə: `~/Library/Application Support/Nota/`.
