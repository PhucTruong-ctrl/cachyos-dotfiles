pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

QtObject {
    id: root

    signal mediaStateChanged()

    property var activePlayer: null

    readonly property bool hasPlayer: activePlayer !== null
    readonly property string title: hasPlayer && activePlayer.trackTitle ? activePlayer.trackTitle : ""
    readonly property string artist: hasPlayer && activePlayer.trackArtist ? activePlayer.trackArtist : ""
    readonly property string albumArtUrl: hasPlayer && activePlayer.trackArtUrl ? activePlayer.trackArtUrl : ""
    readonly property string playerName: hasPlayer && activePlayer.identity ? activePlayer.identity : ""
    readonly property string playbackStatus: {
        if (!hasPlayer)
            return "Stopped";
        if (activePlayer.playbackState === MprisPlaybackState.Playing)
            return "Playing";
        if (activePlayer.playbackState === MprisPlaybackState.Paused)
            return "Paused";
        if (activePlayer.playbackState === MprisPlaybackState.Stopped)
            return "Stopped";
        return "Stopped";
    }

    function playerPriority(player): int {
        if (!player || !player.dbusName)
            return 0;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.spotify"))
            return 100;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.mpv"))
            return 90;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.vlc"))
            return 80;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.plasma-browser-integration"))
            return 10;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.firefox"))
            return 5;
        if (player.dbusName.startsWith("org.mpris.MediaPlayer2.chromium"))
            return 5;
        return 50;
    }

    function pickActivePlayer(): void {
        const players = Mpris.players.values;
        if (!players || players.length === 0) {
            activePlayer = null;
            root.mediaStateChanged();
            return;
        }

        let best = null;
        let bestScore = -1;

        for (const player of players) {
            const stateBonus = player.playbackState === MprisPlaybackState.Playing ? 1000 : player.playbackState === MprisPlaybackState.Paused ? 500 : 100;
            const score = stateBonus + playerPriority(player);
            if (score > bestScore) {
                best = player;
                bestScore = score;
            }
        }

        activePlayer = best;
        root.mediaStateChanged();
    }

    function playPause(): void {
        if (activePlayer && activePlayer.canTogglePlaying)
            activePlayer.togglePlaying();
    }

    function next(): void {
        if (activePlayer && activePlayer.canGoNext)
            activePlayer.next();
    }

    function previous(): void {
        if (activePlayer && activePlayer.canGoPrevious)
            activePlayer.previous();
    }

    property Instantiator _playerTracker: Instantiator {
        model: Mpris.players

        Connections {
            required property MprisPlayer modelData
            target: modelData

            Component.onCompleted: root.pickActivePlayer()
            Component.onDestruction: root.pickActivePlayer()

            function onPlaybackStateChanged() {
                root.pickActivePlayer();
                root.mediaStateChanged();
            }

            function onTrackChanged() {
                root.pickActivePlayer();
                root.mediaStateChanged();
            }

            function onPostTrackChanged() {
                root.pickActivePlayer();
                root.mediaStateChanged();
            }
        }
    }

    Component.onCompleted: {
        pickActivePlayer()
        root.mediaStateChanged()
    }
}
