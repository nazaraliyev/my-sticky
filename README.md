# Nota

A lightweight, native sticky-notes widget for macOS. Notes float on screen as dark glass windows,
Markdown renders live, and checkboxes toggle with a click. There is no Dock icon — the app lives
only as note windows plus a menu bar item.

Built with SwiftPM + AppKit, no external dependencies.

## Features

- **Multiple notes** — each note is its own window; open a new one with the `+` button or menu bar → "Yeni not".
- **Live Markdown** — syntax markers (`**`, `~~`, `#` …) are hidden and only appear on the line with the caret, so you can still edit them.
- **Interactive checkboxes** — type `[]` and it turns into a checkbox; click to toggle.
- **List continuation** — Enter continues checkbox, bullet, and numbered lists; Enter on an empty item exits the list.
- **Global hotkey** — `⌥⌘N` brings all notes to the front from anywhere.
- **Always on top** — keep notes above other windows and on every Space.
- **Launch at login** — starts automatically when you log in.
- **Autosave** — each note is a plain `.md` file; window position and size are remembered too.

## Requirements

- macOS 14 (Sonoma) or later
- Swift 6 toolchain (Xcode or Command Line Tools)

## Installation

```bash
git clone git@github.com:nazaraliyev/my-sticky.git
cd my-sticky
./scripts/install.sh
```

The script builds the app, copies it to `/Applications` (or `~/Applications` if `/Applications`
isn't writable), launches it, and registers it as a login item. Re-run it after changing the code —
it quits and replaces the running copy.

If you only need the `.app` bundle:

```bash
./scripts/make_app.sh   # creates dist/Nota.app
open dist/Nota.app
```

## Usage

The note icon in the menu bar is the app's main control. The UI is in Azerbaijani:

| Menu item                    | Meaning                         | What it does                                  |
| ---------------------------- | ------------------------------- | --------------------------------------------- |
| Yeni not                     | New note                        | Opens a new empty note                        |
| Bütün notları göstər (⌥⌘N)   | Show all notes                  | Brings every note forward, including hidden ones |
| Həmişə üstdə (bütün Spaces)  | Always on top (all Spaces)      | Keeps notes above other windows               |
| Login-da başlat              | Start at login                  | Toggles launching at login                    |
| Çıxış                        | Quit                            | Quits the app                                 |

Window buttons fade in when you hover over a note. Drag a note from any empty area to move it.
The red close button:

- **deletes** an empty note entirely;
- **hides** a note that has content — bring it back with `⌥⌘N`.

### Keyboard shortcuts

| Shortcut        | Action                                      |
| --------------- | ------------------------------------------- |
| `⌥⌘N`           | Show all notes (global, works anywhere)     |
| `⌘B` / `⌘I`     | Bold / italic                               |
| `⌘=` / `⌘-`     | Increase / decrease font size (all notes)   |
| `⌘Z` / `⇧⌘Z`    | Undo / redo                                 |
| `⌘Q`            | Quit                                        |

The global hotkey is registered with Carbon's `RegisterEventHotKey`, so it doesn't need
Accessibility permission.

### Supported Markdown

| You type                     | Result                      |
| ---------------------------- | --------------------------- |
| `# Heading` … `###### `      | Headings                    |
| `**bold**`                   | **bold**                    |
| `*italic*` or `_italic_`     | *italic*                    |
| `~~strikethrough~~`          | ~~strikethrough~~           |
| `` `code` ``                 | `code`                      |
| `<u>underline</u>`           | underlined text             |
| `> quote`                    | Indented, dimmed quote      |
| `- `, `* `, `+ `             | Bullet list                 |
| `1. `                        | Numbered list               |
| `[]`, `[ ]`, `[x]`           | Checkbox                    |

## Where data is stored

- **Notes:** `~/Library/Application Support/Nota/note-<id>.md` — plain Markdown you can open in any editor or sync.
- **Settings** (note list, window frames, font size, always-on-top): `UserDefaults`, bundle ID `com.nazar.nota`.

## Development

```bash
swift build
swift run Nota               # run the app directly
swift run Nota --selftest    # headless checks (Markdown round-trip, checkboxes, lists)
```

"Login-da başlat" (start at login) only works when running from a `.app` bundle (an `SMAppService`
requirement), so it has no effect under `swift run`.

The app icon is drawn in code. To change it, edit `scripts/make_icon.swift`, run
`swift scripts/make_icon.swift` to regenerate `packaging/Nota.icns`, then rebuild.

### Project layout

```
Sources/Nota/
├── main.swift                 # Entry point, --selftest
├── AppDelegate.swift          # Hidden main menu (shortcuts), startup
├── NoteManager.swift          # Manages all notes
├── NoteWindowController.swift # One note window: chrome, mode, autosave
├── NotePanel.swift            # NSPanel subclass
├── ChromeViews.swift          # Hover effect view, "paper" background
├── MarkdownTextView.swift     # Editor: live preview, checkboxes, list continuation
├── MarkdownRenderer.swift     # Markdown ⇄ NSAttributedString
├── CheckboxAttachment.swift   # Clickable checkbox
├── NoteDocument.swift         # A note's .md file
├── Storage.swift              # File locations, starter note
├── Settings.swift             # UserDefaults wrapper
├── StatusBarController.swift  # Menu bar icon and menu
├── GlobalHotKey.swift         # ⌥⌘N
├── LaunchAtLogin.swift        # SMAppService wrapper
└── SelfTest.swift             # Headless tests
packaging/Info.plist           # Bundle metadata (LSUIElement — no Dock icon)
packaging/Nota.icns            # App icon (generated by scripts/make_icon.swift)
scripts/make_app.sh            # Builds dist/Nota.app
scripts/make_icon.swift        # Draws the app icon in code → packaging/Nota.icns
scripts/install.sh             # Build + install + login item
```

## Uninstalling

1. Menu bar → turn off "Login-da başlat", then choose "Çıxış" (Quit).
2. Delete `/Applications/Nota.app`.
3. To remove your notes too: `~/Library/Application Support/Nota/`.
