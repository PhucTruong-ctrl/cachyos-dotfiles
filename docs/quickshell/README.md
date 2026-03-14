# Quickshell OSD Architecture

This document describes the rewritten OSD architecture for Quickshell with event-bus boundaries and end-4 parity behavior.

## Overview

The OSD pipeline is split into producers, a transport layer, and a presentation consumer:

- **Producers**: `OSDAudioService`, `OSDBrightnessService`, `OSDMediaService`
- **Transport**: `OSDEventBus`
- **Consumer/UI**: `components/OSD.qml`
- **State bridge**: `GlobalState.osdEvent`

`OSD.qml` no longer reads Pipewire or brightness streams directly. It only normalizes and renders received events.

## Event Bus Contract

`config/quickshell/services/OSDEventBus.qml` defines a normalized payload contract:

- `kind`: logical event type (`volume`, `brightness`, `media`)
- `value`: numeric value expected by OSD progress rendering
- `icon`: icon glyph for the OSD row
- `label`: optional display text
- `timestamp`: event publish time in milliseconds
- `metadata`: source-specific structured context

All producers emit through `OSDEventBus.publish*()` helpers to keep payload shape and routing consistent.

## Service Boundaries

### Audio: `OSDAudioService.qml`

- Owns Pipewire sink binding (`Pipewire.defaultAudioSink`)
- Applies readiness gating (`audioReady`) before reading sink state
- Deduplicates unchanged volume/mute values
- Emits only meaningful state transitions via `OSDEventBus.publishAudio(...)`

### Brightness: `OSDBrightnessService.qml`

- Owns `brightnessctl -m --watch` stream parsing
- Parses and clamps `%` from `(current,max)` values
- Resets state on device-key changes
- Applies DDC debounce and immediate backlight publishing
- Emits through `OSDEventBus.publishBrightness(...)`

### Media: `OSDMediaService.qml`

- Subscribes to `MediaService.mediaStateChanged`
- Normalizes icon/progress from playback state
- Deduplicates repeated signatures and rate-limits spam
- Emits through `OSDEventBus.publishMedia(...)`

### UI Consumer: `components/OSD.qml`

- Subscribes to `GlobalState.osdEvent`
- Accepts both `event.type` and `event.kind` during normalization
- Clamps value range to `0..100` for rendering safety
- Owns only display concerns (visibility timer, layout, styling)

## End-4 Parity Notes

The rewrite aligns with the end-4 direction:

- **Event-driven architecture**: producers publish events, UI consumes state
- **Service isolation**: device/runtime concerns stay in services, not in view components
- **Deduped emissions**: rapid repeated identical states are suppressed
- **Theming parity**: OSD sizing/timing/colors are centralized in `Appearance`/`GlobalState`

The current implementation keeps practical reliability guards where needed (e.g., brightness stream handling and audio readiness), while preserving the end-4 separation between event sources and presentation.

## Files

- `config/quickshell/components/OSD.qml`
- `config/quickshell/services/OSDEventBus.qml`
- `config/quickshell/services/OSDAudioService.qml`
- `config/quickshell/services/OSDBrightnessService.qml`
- `config/quickshell/services/OSDMediaService.qml`
- `config/quickshell/services/GlobalState.qml`
