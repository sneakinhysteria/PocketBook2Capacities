# PocketBook2Capacities

Sync your reading highlights from PocketBook Cloud to Capacities.

![Menu Bar App](https://img.shields.io/badge/macOS-14.0+-blue) ![License](https://img.shields.io/badge/license-MIT-green)

## Features

- Sync highlights and notes from PocketBook e-readers to Capacities
- **Menu bar app** for easy access and background syncing
- **CLI tool** for automation and scripting
- Automatic highlight merging (combines split multi-page highlights)
- Page numbers included with each highlight
- Author extraction from book metadata/filenames
- Bookmark filtering (only syncs actual highlights, not bookmarks)
- Auto-sync on configurable intervals
- Incremental sync (only new highlights)

## Installation

### Download

Download the latest DMG from [Releases](../../releases).

1. Open the DMG
2. Drag `PocketBook2Capacities.app` to Applications
3. Right-click the app and select "Open" (required for unsigned apps)

### Build from Source

Requires macOS 14.0+ and Swift 5.9+.

```bash
git clone https://github.com/yourusername/PocketBook2Capacities.git
cd PocketBook2Capacities
swift build --disable-sandbox
```

## Setup

### Menu Bar App

1. Launch the app (it appears in your menu bar)
2. Click the menu bar icon → Settings
3. **Accounts tab:**
   - Click "Login..." for PocketBook Cloud
   - Click "Configure..." for Capacities (requires API token from Capacities Desktop → Settings → API)
4. Click "Sync Now" to sync your highlights

### CLI

```bash
# Login to both services
pocketbook2capacities login

# Check status
pocketbook2capacities status

# Sync highlights
pocketbook2capacities sync

# Dry run (preview without syncing)
pocketbook2capacities sync --dry-run

# Force full resync
pocketbook2capacities sync --force
```

## How It Works

1. Fetches all books from your PocketBook Cloud library
2. For each book with highlights:
   - Retrieves all highlights and notes
   - Merges split highlights (when a highlight spans multiple pages)
   - Sorts by position in book
   - Filters out bookmarks (keeps only text highlights)
3. Creates/updates a Weblink in Capacities with:
   - Book title and author
   - All highlights formatted as markdown with page numbers
   - Tags: #book, #pocketbook

### Example Output in Capacities

```markdown
## Highlights

### 🟢 Highlight 1 (p. 36)
> This 'necessary distance', as we might call it, is not the same as
> detachment. Distance can yield detachment, as when we coldly calculate...

### 🟡 Highlight 2 (p. 42)
> The evolution of the frontal lobes prepares us at the same time to be
> exploiters of the world and of one another...

*Note: This relates to the earlier point about consciousness.*
```

## Configuration

Credentials are stored in `~/.config/pocketbook2capacities/credentials.json` (owner-only permissions).

Sync state is stored in `~/.config/pocketbook2capacities/sync-state.json`.

### Auto-Sync

In the menu bar app Settings → Sync tab:
- Enable/disable auto-sync
- Set interval (15min, 30min, 1hr, 2hr)
- Toggle sync notifications

## Building the DMG

```bash
./scripts/package-dmg.sh
```

This creates `PocketBook2Capacities-1.0.0.dmg` with:
- Universal binary (Intel + Apple Silicon)
- App icon
- Applications folder shortcut

## Requirements

- macOS 14.0 or later
- PocketBook Cloud account (with a PocketBook e-reader synced to cloud)
- Capacities Pro account (required for API access)

## Privacy

- All data stays on your machine
- Credentials stored locally with restricted permissions
- No analytics or telemetry
- Direct API communication with PocketBook Cloud and Capacities only

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [obsidian-pocketbook-cloud-highlight-importer](https://github.com/lenalebt/obsidian-pocketbook-cloud-highlight-importer) - Inspiration for this project; Obsidian plugin for PocketBook highlights
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper
- [swift-argument-parser](https://github.com/apple/swift-argument-parser) - CLI argument parsing
