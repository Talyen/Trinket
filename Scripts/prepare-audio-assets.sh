#!/usr/bin/env bash
set -euo pipefail
# Unified music + SFX preparation (merges prepare-music-assets.sh and
# prepare-sfx-assets.sh, which were 80%+ identical). Per-kind manifest
# validation and Swift rendering stay inline; encode, state, prune, and
# commit mechanics live in Scripts/lib/media-assets.sh.

cd "$(dirname "$0")/.."
# shellcheck source=lib/media-assets.sh
source "Scripts/lib/media-assets.sh"

GENERATOR="Scripts/prepare-audio-assets.sh"

kind="all"
if [[ $# -ge 1 ]]; then
  case "$1" in
    music|sfx|all)
      kind="$1"
      ;;
    --help|-h)
      echo "Usage: $0 [music|sfx|all]"
      exit 0
      ;;
    *)
      echo "Unknown kind '$1' (expected music|sfx|all)" >&2
      exit 1
      ;;
  esac
fi

tracks_temp=""
menu_temp=""
battle_temp=""
boss_temp=""
seen_ids_temp=""
seen_assets_temp=""
seen_boss_ids_temp=""
active_tracks_temp=""
clips_temp=""
ids_temp=""
seen_symbols_temp=""
seen_sfx_ids_temp=""
seen_sfx_assets_temp=""
active_clips_temp=""
generated_temp=""
music_state_temp=""
sfx_state_temp=""
cleanup() {
  rm -f "${tracks_temp:-}" "${menu_temp:-}" "${battle_temp:-}" "${boss_temp:-}" \
    "${seen_ids_temp:-}" "${seen_assets_temp:-}" "${seen_boss_ids_temp:-}" "${active_tracks_temp:-}" \
    "${clips_temp:-}" "${ids_temp:-}" "${seen_symbols_temp:-}" "${seen_sfx_ids_temp:-}" \
    "${seen_sfx_assets_temp:-}" "${active_clips_temp:-}" "${generated_temp:-}" \
    "${music_state_temp:-}" "${sfx_state_temp:-}" \
    "${music_state_temp:-}.next" "${music_state_temp:-}.sorted" \
    "${sfx_state_temp:-}.next" "${sfx_state_temp:-}.sorted" \
    Trinket/Media/Music/.*.tmp.$$.* Trinket/Media/SFX/.*.tmp.$$.* 2>/dev/null || true
}
trap cleanup EXIT

prepare_music() {
  local manifest="MusicManifest/music.tsv"
  local resources_dir="Trinket/Media/Music"
  local generated_dir="Packages/TrinketContent/Sources/TrinketContent/Generated"
  local generated_swift="$generated_dir/MusicCatalog.generated.swift"
  local state_file="$generated_dir/MusicSourceHashes.generated.tsv"
  local bitrate="${MUSIC_AAC_BITRATE:-96000}"
  local encode_profile="container=m4af;codec=aac;bitrate=$bitrate;soundcheck=true"

  if [[ ! -f "$manifest" ]]; then
    echo "Missing manifest: $manifest" >&2
    exit 1
  fi
  trinket_asset_require_afconvert

  mkdir -p "$resources_dir" "$generated_dir"

  tracks_temp=$(mktemp)
  menu_temp=$(mktemp)
  battle_temp=$(mktemp)
  boss_temp=$(mktemp)
  seen_ids_temp=$(mktemp)
  seen_assets_temp=$(mktemp)
  seen_boss_ids_temp=$(mktemp)
  active_tracks_temp=$(mktemp)
  local processed_count=0
  trinket_asset_begin_state_file "$state_file" "$GENERATOR"
  music_state_temp="$TRINKET_ASSET_STATE_TEMP"

  trinket_asset_begin_state_lookup "$state_file"

  local kind_col id asset_name source_path boss_enemy_id looping volume_gain
  while IFS=$'\t' read -r kind_col id asset_name source_path boss_enemy_id looping volume_gain || [[ -n "${kind_col:-}" ]]; do
    [[ -z "${kind_col:-}" || "$kind_col" == \#* ]] && continue
    [[ "$boss_enemy_id" == "none" ]] && boss_enemy_id=""

    if [[ "$kind_col" != "menu" && "$kind_col" != "battle" && "$kind_col" != "boss" ]]; then
      echo "Unsupported music kind '$kind_col' for id '$id'." >&2
      exit 1
    fi

    if [[ -z "$id" || -z "$asset_name" || -z "$source_path" || -z "$looping" || -z "$volume_gain" ]]; then
      echo "Manifest row is missing required fields for id '$id'." >&2
      exit 1
    fi

    trinket_asset_validate_identifier "Track id" "$id"
    trinket_asset_validate_identifier "Asset name" "$asset_name"

    trinket_asset_assert_unique "$seen_ids_temp" "music track id" "$id"
    trinket_asset_assert_unique "$seen_assets_temp" "music asset name" "$asset_name"

    if [[ ! -f "$source_path" ]]; then
      echo "Missing source file for '$id': $source_path" >&2
      exit 1
    fi

    case "$looping" in
      true|false) ;;
      *)
        echo "Looping value for '$id' must be true or false." >&2
        exit 1
        ;;
    esac

    if [[ ! "$volume_gain" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "Volume gain for '$id' must be numeric." >&2
      exit 1
    fi

    if [[ "$kind_col" == "boss" ]]; then
      if [[ -z "$boss_enemy_id" ]]; then
        echo "Boss music '$id' must include boss_enemy_id." >&2
        exit 1
      fi
      if ! awk -v id="$boss_enemy_id" '$0 ~ ("id: \"" id "\"") && $0 ~ /isBoss: true/ { found = 1 } END { exit !found }' Packages/TrinketContent/Sources/TrinketContent/Generated/GameContentEnemies.generated.swift; then
        echo "Boss music '$id' references missing or non-boss enemy '$boss_enemy_id'." >&2
        exit 1
      fi
      trinket_asset_assert_unique "$seen_boss_ids_temp" "boss music enemy id" "$boss_enemy_id"
    elif [[ -n "$boss_enemy_id" ]]; then
      echo "Only boss music may include boss_enemy_id; '$id' has '$boss_enemy_id'." >&2
      exit 1
    fi

    printf '%s\n' "$asset_name.m4a" >> "$active_tracks_temp"

    trinket_audio_encode_row "$source_path" "$resources_dir" "$asset_name" "$bitrate" "music '$id'" "$music_state_temp" "$encode_profile"

    local escaped_id escaped_asset escaped_boss
    escaped_id="$(trinket_asset_escape_swift_string "$id")"
    escaped_asset="$(trinket_asset_escape_swift_string "$asset_name")"
    escaped_boss="$(trinket_asset_escape_swift_string "$boss_enemy_id")"

    cat >> "$tracks_temp" <<SWIFT
        MusicTrack(
            id: "$escaped_id",
            kind: .$kind_col,
            resourceName: "$escaped_asset",
            fileExtension: "m4a",
            bossEnemyID: "$escaped_boss",
            isLooping: $looping,
            volumeGain: $volume_gain
        ),
SWIFT

    case "$kind_col" in
      menu)
        cat >> "$menu_temp" <<SWIFT
        "$escaped_id",
SWIFT
        ;;
      battle)
        cat >> "$battle_temp" <<SWIFT
        "$escaped_id",
SWIFT
        ;;
      boss)
        cat >> "$boss_temp" <<SWIFT
        "$escaped_boss": "$escaped_id",
SWIFT
        ;;
    esac

    processed_count=$((processed_count + 1))
  done < "$manifest"

  generated_temp=$(mktemp)
  cat > "$generated_temp" <<SWIFT
// Generated by $GENERATOR. Do not edit directly.

import Foundation

public enum MusicCatalog {
    public static let allTracks: [MusicTrack] = [
$(cat "$tracks_temp")
    ]

    public static let menuTrackIDs: [String] = [
$(cat "$menu_temp")
    ]

    public static let battleTrackIDs: [String] = [
$(cat "$battle_temp")
    ]

    public static let bossTrackIDByEnemyID: [String: String] = [
$(cat "$boss_temp")
    ]
}
SWIFT

  trinket_asset_commit_generated "$generated_temp" "$generated_swift"
  generated_temp=""

  trinket_asset_prune_orphans "$resources_dir" "$active_tracks_temp" "music track" "m4a"
  trinket_asset_sort_state "$music_state_temp" "$state_file"
  rm -f "$tracks_temp" "$menu_temp" "$battle_temp" "$boss_temp" "$seen_ids_temp" "$seen_assets_temp" "$seen_boss_ids_temp" "$active_tracks_temp" "$music_state_temp"
  tracks_temp=""; menu_temp=""; battle_temp=""; boss_temp=""
  seen_ids_temp=""; seen_assets_temp=""; seen_boss_ids_temp=""; active_tracks_temp=""
  music_state_temp=""

  echo "Prepared $processed_count music assets in $resources_dir and regenerated $generated_swift."
}

prepare_sfx() {
  local manifest="SoundManifest/sfx.tsv"
  local resources_dir="Trinket/Media/SFX"
  local generated_dir="Packages/TrinketContent/Sources/TrinketContent/Generated"
  local generated_swift="$generated_dir/SFXCatalog.generated.swift"
  local state_file="$generated_dir/SFXSourceHashes.generated.tsv"
  local bitrate="${SFX_AAC_BITRATE:-64000}"
  local encode_profile="container=m4af;codec=aac;bitrate=$bitrate;soundcheck=true"

  if [[ ! -f "$manifest" ]]; then
    echo "Missing manifest: $manifest" >&2
    exit 1
  fi
  trinket_asset_require_afconvert

  mkdir -p "$resources_dir" "$generated_dir"

  clips_temp=$(mktemp)
  ids_temp=$(mktemp)
  seen_sfx_ids_temp=$(mktemp)
  seen_symbols_temp=$(mktemp)
  seen_sfx_assets_temp=$(mktemp)
  active_clips_temp=$(mktemp)
  local processed_count=0
  trinket_asset_begin_state_file "$state_file" "$GENERATOR"
  sfx_state_temp="$TRINKET_ASSET_STATE_TEMP"

  trinket_asset_begin_state_lookup "$state_file"

  local id swift_symbol asset_name source_path volume_gain
  while IFS=$'\t' read -r id swift_symbol asset_name source_path volume_gain || [[ -n "${id:-}" ]]; do
    [[ -z "${id:-}" || "$id" == \#* ]] && continue

    if [[ -z "$swift_symbol" || -z "$asset_name" || -z "$source_path" || -z "$volume_gain" ]]; then
      echo "Manifest row is missing required fields for id '$id'." >&2
      exit 1
    fi

    trinket_asset_validate_identifier "SFX id" "$id"
    trinket_asset_validate_swift_identifier "SFX Swift symbol" "$swift_symbol"
    trinket_asset_validate_identifier "Asset name" "$asset_name"

    trinket_asset_assert_unique "$seen_sfx_ids_temp" "SFX id" "$id"
    trinket_asset_assert_unique "$seen_symbols_temp" "SFX Swift symbol" "$swift_symbol"
    trinket_asset_assert_unique "$seen_sfx_assets_temp" "SFX asset name" "$asset_name"

    if [[ ! -f "$source_path" ]]; then
      echo "Missing source file for '$id': $source_path" >&2
      exit 1
    fi

    if [[ ! "$volume_gain" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      echo "Volume gain for '$id' must be numeric." >&2
      exit 1
    fi

    printf '%s\n' "$asset_name.m4a" >> "$active_clips_temp"

    trinket_audio_encode_row "$source_path" "$resources_dir" "$asset_name" "$bitrate" "SFX '$id'" "$sfx_state_temp" "$encode_profile"

    local escaped_id escaped_asset
    escaped_id="$(trinket_asset_escape_swift_string "$id")"
    escaped_asset="$(trinket_asset_escape_swift_string "$asset_name")"

    printf '    public static let %s = "%s"\n' "$swift_symbol" "$escaped_id" >> "$ids_temp"

    cat >> "$clips_temp" <<SWIFT
        SFXClip(
            id: "$escaped_id",
            resourceName: "$escaped_asset",
            fileExtension: "m4a",
            volumeGain: $volume_gain
        ),
SWIFT

    processed_count=$((processed_count + 1))
  done < "$manifest"

  generated_temp=$(mktemp)
  cat > "$generated_temp" <<SWIFT
// Generated by $GENERATOR. Do not edit directly.

import Foundation

public enum SFXID {
$(cat "$ids_temp")
}

public struct SFXClip: Identifiable, Hashable, Sendable {
    public let id: String
    public let resourceName: String
    public let fileExtension: String
    public let volumeGain: Double
}

public enum SFXCatalog {
    public static let clips: [SFXClip] = [
$(cat "$clips_temp")
    ]

    public static let clipsByID: [String: SFXClip] = {
        Dictionary(uniqueKeysWithValues: clips.map { (\$0.id, \$0) })
    }()
}
SWIFT

  trinket_asset_commit_generated "$generated_temp" "$generated_swift"
  generated_temp=""

  trinket_asset_prune_orphans "$resources_dir" "$active_clips_temp" "SFX clip" "m4a"
  trinket_asset_sort_state "$sfx_state_temp" "$state_file"
  rm -f "$clips_temp" "$ids_temp" "$seen_sfx_ids_temp" "$seen_symbols_temp" "$seen_sfx_assets_temp" "$active_clips_temp" "$sfx_state_temp"
  clips_temp=""; ids_temp=""; seen_sfx_ids_temp=""; seen_symbols_temp=""
  seen_sfx_assets_temp=""; active_clips_temp=""; sfx_state_temp=""

  echo "Prepared $processed_count SFX assets in $resources_dir and regenerated $generated_swift."
}

case "$kind" in
  music) prepare_music ;;
  sfx) prepare_sfx ;;
  all) prepare_music; prepare_sfx ;;
esac
