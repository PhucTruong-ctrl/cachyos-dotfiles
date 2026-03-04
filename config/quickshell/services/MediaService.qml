// MediaService.qml — MPRIS media backend singleton
//
// Exposes currently playing media metadata from playerctl.
// Polls metadata on startup and after control actions.
// Uses a long-running --follow process for real-time playback status updates.
//
// Usage:
//   MediaService.title       — current track title
//   MediaService.artist      — current track artist
//   MediaService.albumArtUrl — album art URL (may be file:// or http://)
//   MediaService.playbackStatus — "Playing", "Paused", or "Stopped"
//   MediaService.playerName  — active player name (e.g. "spotify", "mpv")
//   MediaService.hasPlayer   — true when a player is running
//
// Controls:
//   MediaService.playPause() — toggle play/pause
//   MediaService.next()      — skip to next track
//   MediaService.previous()  — go to previous track

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Exposed properties ────────────────────────────────────────────────────
    readonly property string title:          _title
    readonly property string artist:         _artist
    readonly property string albumArtUrl:    _albumArtUrl
    readonly property string playbackStatus: _playbackStatus
    readonly property string playerName:     _playerName
    readonly property bool   hasPlayer:      _hasPlayer

    // ── Internal mutable backing ──────────────────────────────────────────────
    property string _title:          ""
    property string _artist:         ""
    property string _albumArtUrl:    ""
    property string _playbackStatus: "Stopped"
    property string _playerName:     ""
    property bool   _hasPlayer:      false

    // ── Metadata polling process ──────────────────────────────────────────────
    // Reads title, artist, album art, status, and player name using a tab-
    // delimited format instead of JSON. This avoids parse failures when track
    // metadata contains quotes, backslashes, or other JSON-special characters.
    //
    // Output format (one line, fields separated by ASCII US \x1F unit separator):
    //   <title>\x1F<artist>\x1F<artUrl>\x1F<status>\x1F<playerName>
    //
    // The unit separator (0x1F) is unlikely to appear in track metadata and
    // provides a safe delimiter that playerctl passes through verbatim.
    property Process _metadataProc: Process {
        id: metadataProc
        command: [
            "playerctl", "metadata",
            "--format",
            "{{title}}\x1f{{artist}}\x1f{{mpris:artUrl}}\x1f{{status}}\x1f{{playerName}}"
        ]
        running: false

        stdout: SplitParser {
            onRead: data => {
                const trimmed = data.trim();
                if (trimmed.length === 0) {
                    root._hasPlayer      = false;
                    root._title          = "";
                    root._artist         = "";
                    root._albumArtUrl    = "";
                    root._playbackStatus = "Stopped";
                    root._playerName     = "";
                    return;
                }
                // Split on ASCII unit separator (0x1F)
                const parts = trimmed.split("\x1f");
                if (parts.length < 5) {
                    // Unexpected format — clear state defensively
                    root._hasPlayer      = false;
                    root._title          = "";
                    root._artist         = "";
                    root._albumArtUrl    = "";
                    root._playbackStatus = "Stopped";
                    root._playerName     = "";
                    return;
                }
                root._hasPlayer      = true;
                root._title          = parts[0];
                root._artist         = parts[1];
                root._albumArtUrl    = parts[2];
                root._playbackStatus = parts[3] || "Stopped";
                root._playerName     = parts[4];
            }
        }

        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // No player running
                root._hasPlayer      = false;
                root._title          = "";
                root._artist         = "";
                root._albumArtUrl    = "";
                root._playbackStatus = "Stopped";
                root._playerName     = "";
            }
        }
    }

    // ── Long-running status follower ──────────────────────────────────────────
    // Listens for play/pause/stop events in real-time via `playerctl --follow status`.
    // When status changes, re-polls metadata to get the full updated state.
    property Process _statusFollower: Process {
        id: statusFollower
        command: ["playerctl", "--follow", "status"]
        running: true

        stdout: SplitParser {
            onRead: data => {
                const status = data.trim();
                if (status === "Playing" || status === "Paused" || status === "Stopped") {
                    root._playbackStatus = status;
                    root._hasPlayer      = (status !== "Stopped");
                    // Re-poll full metadata to pick up track changes
                    metadataProc.running = false;
                    metadataProc.running = true;
                }
            }
        }

        onExited: {
            // Restart follower after a brief delay so it survives player restarts
            statusRestartTimer.start();
        }
    }

    // Restart follower 2 s after it exits (player closed / crashed)
    property Timer _statusRestartTimer: Timer {
        id: statusRestartTimer
        interval: 2000
        repeat:   false
        onTriggered: {
            statusFollower.running = false;
            statusFollower.running = true;
        }
    }

    // ── Control processes ─────────────────────────────────────────────────────
    property Process _playPauseProc: Process {
        id: playPauseProc
        command: ["playerctl", "play-pause"]
        onExited: {
            metadataProc.running = false;
            metadataProc.running = true;
        }
    }

    property Process _nextProc: Process {
        id: nextProc
        command: ["playerctl", "next"]
        onExited: {
            metadataProc.running = false;
            metadataProc.running = true;
        }
    }

    property Process _previousProc: Process {
        id: previousProc
        command: ["playerctl", "previous"]
        onExited: {
            metadataProc.running = false;
            metadataProc.running = true;
        }
    }

    // ── Public control functions ──────────────────────────────────────────────
    function playPause(): void {
        playPauseProc.running = false;
        playPauseProc.running = true;
    }

    function next(): void {
        nextProc.running = false;
        nextProc.running = true;
    }

    function previous(): void {
        previousProc.running = false;
        previousProc.running = true;
    }

    // ── Initial metadata poll ─────────────────────────────────────────────────
    Component.onCompleted: {
        metadataProc.running = true;
    }
}
