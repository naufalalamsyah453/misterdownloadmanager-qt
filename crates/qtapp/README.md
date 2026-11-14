# mdm-qt: Mister Download Manager's Qt edition

The desktop window rebuilt with **Qt 6 / QML**, through [cxx-qt](https://github.com/KDAB/cxx-qt).
The download engine ([`mdm-engine`](../engine)) is the same one the egui app uses and is not
touched: this crate only draws the window and drives the engine.

```
cargo run -p mdm-qt                     # the window
cargo test -p mdm-qt                    # the engine layer, against the lab server
tools/qt/shots.sh <dir> [light|dark]    # screenshots on a virtual X server (needs xvfb, imagemagick)
```

Needs Qt 6.4+ (Core, Gui, Qml, Quick, Quick Controls 2), CMake and libclang. The workspace asks
for Rust 1.98; with an older compiler, add `--ignore-rust-version` (the Qt crate itself doesn't
need 1.98, the engine's `browser-connection` feature does).

## Layout

| Path | What it is |
|---|---|
| `src/engine.rs` | The list's state with no Qt in it: `Manager` owns a tokio runtime and one `Entry` per download, starts, pauses (cancels, keeping the state file), resumes and removes them, and turns engine snapshots into rows (status, progress, speed, time left, category). Tested end to end against the lab server. |
| `src/model.rs` | `DownloadModel`, a `QAbstractListModel` written in Rust. QML's `ListView` reads its roles (`name`, `size`, `progress`, `status`…) and calls `add`, `pause`, `resume`, `remove` and `poll` (a 250 ms timer). |
| `qml/Main.qml` | The window: tool bar, sidebar, list, status bar, menus, shortcuts. |
| `qml/Theme.qml` | Every colour, size and text format; colours come from the system palette (light or dark). |
| `qml/Sidebar.qml`, `qml/DownloadRow.qml`, `qml/AddUrlDialog.qml` | The sidebar's categories, one row of the list, the Add URL window. |
| `build.rs` | cxx-qt's build: the QML module `org.misterdownloadmanager` and the bridge in `model.rs`. |

Command line: `--add=<url>` starts a download at launch, `--dialog` opens Add URL.
Keys: Ctrl+N add, Ctrl+F search, Delete remove.

## Status

Done:

- The main window: tool bar (Add URL, Pause, Resume, Remove, search), category sidebar with
  counts (All, In progress, Finished and the six file categories), a download list with progress
  bar, size, speed and time left, a right-click menu, a status bar with the total speed.
- Add URL (the clipboard's text is offered), pause, resume from the state file, remove (with or
  without the file), double click opens the folder.
- Light and dark, following the system palette.

Not yet (the egui app has them; they come over one by one):

- The progress window with per-connection detail, Options, the scheduler and queues, the link
  grabber, torrents and magnet links, videos and galleries, RSS, debrid accounts.
- The system tray, browser integration (native messaging host, single instance), the remote
  control, drag and drop, file-type icons, sounds.
- **Translations.** Texts are in `qsTr()` for now; the app's 86 languages (`crate::i18n`,
  `i18n/*.tsv`) are not connected to Qt yet, nor right-to-left mirroring checks.
- The theme system (`palette.rs`, theme files), Windows and macOS builds, installers.
