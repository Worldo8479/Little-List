# Little List

Native macOS menu bar to-do app, with School and Personal lists. Built locally with SwiftUI and AppKit; no third-party libraries.

Open `/Users/marcoanderson2011/Applications/Little List.app`. Click the checklist in the menu bar. Add a task in either list, check it off, or restore it from Done. Source links open the underlying request. Completion is local only. The gear menu offers Open at login and Quit.

## Sync

A Codex heartbeat named **Refresh Little List** is scheduled every 15 minutes. It reads SYNC.md and updates data/feed.json. The app rereads the feed every five seconds. This is periodic sync, not real-time push. Codex must be available and the Mac awake; browser/native sources additionally need a signed-in accessible session. Those checks may activate windows. It does not run independently of Codex.

Personal Gmail and school Google Calendar use connected tools. School Gmail, Teamie LMS, Google Chat and WhatsApp can use signed-in UI access. At creation the Gmail connector pointed to personal Gmail, even after the school account was added. The initial scan covers recent LMS assignments and Rec Crew; it does not claim full historical/account coverage. See the Sources tab for actual coverage/freshness.

Private runtime feed and completion data are in `~/Library/Application Support/LittleList/`. The initial snapshot under data/ is excluded from Git. No credentials are stored by the app. To stop background checks, pause/delete Refresh Little List in Codex. Quitting the menu bar app does not stop the scheduled check.

## Build

Run `./build.sh` using Apple Command Line Tools. Builds an Apple Silicon macOS 14+ app and signs it locally (ad-hoc, not notarized). Rebuilding can require re-enabling Open at login.

## Verification
The installed build passes codesign verification. Live UI verified School tasks load (11 initial tasks), Personal is separate, and completion plus restoration works. The scheduled heartbeat was created successfully; its first unattended run has not yet been verified. Open at login is available in the gear menu; registration has not been independently verified.
