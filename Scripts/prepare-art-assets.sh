#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

manifest="ArtManifest/curated-assets.tsv"
asset_catalog="Trinket/Assets.xcassets"
generated_dir="Packages/TrinketContent/Sources/TrinketContent/Generated"
generated_swift="$generated_dir/ArtCatalog.generated.swift"

heic_quality="${ART_HEIC_QUALITY:-80}"
max_dimension="${ART_MAX_DIMENSION:-1600}"
thumb_dimension="${ART_THUMB_DIMENSION:-480}"

if [[ ! -f "$manifest" ]]; then
  echo "Missing manifest: $manifest" >&2
  exit 1
fi

mkdir -p "$asset_catalog" "$generated_dir"


cat > "$asset_catalog/Contents.json" <<'JSON'
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

combatants_temp=$(mktemp)
abilities_temp=$(mktemp)
items_temp=$(mktemp)
slot_backgrounds_temp=$(mktemp)
backgrounds_temp=$(mktemp)
encounters_temp=$(mktemp)
resources_temp=$(mktemp)
active_assets_temp=$(mktemp)
generated_temp=$(mktemp)
processed_count=0
full_count=0
thumb_count=0

escape_swift_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

heic_from_source() {
  local src="$1" dst="$2" sz="$3"
  sips -s format heic -s formatOptions "$heic_quality" -Z "$sz" "$src" --out "$dst" >/dev/null
  sips -d all "$dst" >/dev/null 2>&1 || true
}

write_imageset() {
  local imageset="$1"
  local asset_name="$2"
  local output_file="$3"
  local source_file="$4"
  local dimension="$5"

  rm -rf "$imageset"
  mkdir -p "$imageset"
  heic_from_source "$source_file" "$output_file" "$dimension"
  cat > "$imageset/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "$asset_name.heic",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON
}

# Catalog usage drives which variants we ship:
# - ability: thumb only (AbilityArtReference.imageName is the thumb)
# - background / resource / slot_background: full only
# - combatant / item / encounter: full + thumb
emit_full_for_kind() {
  case "$1" in
    ability) return 1 ;;
    *) return 0 ;;
  esac
}

emit_thumb_for_kind() {
  case "$1" in
    background|resource|slot_background) return 1 ;;
    *) return 0 ;;
  esac
}

while IFS=$'\t' read -r kind id asset_name source_path focal_x focal_y || [[ -n "${kind:-}" ]]; do
  [[ -z "${kind:-}" || "$kind" == \#* ]] && continue

  if [[ "$kind" != "combatant" && "$kind" != "ability" && "$kind" != "item" && "$kind" != "slot_background" && "$kind" != "background" && "$kind" != "encounter" && "$kind" != "resource" ]]; then
    echo "Unsupported art kind '$kind' for id '$id'." >&2
    exit 1
  fi

  if [[ -z "$id" || -z "$asset_name" || -z "$source_path" || -z "$focal_x" || -z "$focal_y" ]]; then
    echo "Manifest row is missing required fields for id '$id'." >&2
    exit 1
  fi

  if [[ ! "$asset_name" =~ ^[A-Za-z0-9_]+$ ]]; then
    echo "Asset name '$asset_name' should use only letters, numbers, and underscores." >&2
    exit 1
  fi

  if [[ ! "$focal_x" =~ ^[0-9]+([.][0-9]+)?$ || ! "$focal_y" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    echo "Focal values for '$id' must be numeric." >&2
    exit 1
  fi

  want_full=false
  want_thumb=false
  if emit_full_for_kind "$kind"; then
    want_full=true
  fi
  if emit_thumb_for_kind "$kind"; then
    want_thumb=true
  fi

  imageset="$asset_catalog/$asset_name.imageset"
  output_file="$imageset/$asset_name.heic"
  thumb_asset="${asset_name}_thumb"
  thumb_imageset="$asset_catalog/${thumb_asset}.imageset"
  thumb_output_file="$thumb_imageset/${thumb_asset}.heic"

  if $want_full; then
    printf '%s\n' "$asset_name" >> "$active_assets_temp"
  fi
  if $want_thumb; then
    printf '%s\n' "$thumb_asset" >> "$active_assets_temp"
  fi

  source_file="$source_path"
  if [[ ! -f "$source_file" ]]; then
    echo "Missing source file for '$id': $source_path" >&2
    exit 1
  fi

  needs_convert=false
  if $want_full; then
    if [[ ! -f "$output_file" || "$source_file" -nt "$output_file" ]]; then
      needs_convert=true
    fi
  fi
  if $want_thumb; then
    if [[ ! -f "$thumb_output_file" || "$source_file" -nt "$thumb_output_file" ]]; then
      needs_convert=true
    fi
  fi

  if $needs_convert; then
    if $want_full; then
      write_imageset "$imageset" "$asset_name" "$output_file" "$source_file" "$max_dimension"
      full_count=$((full_count + 1))
    fi
    if $want_thumb; then
      write_imageset "$thumb_imageset" "$thumb_asset" "$thumb_output_file" "$source_file" "$thumb_dimension"
      thumb_count=$((thumb_count + 1))
    fi
  fi

  # Remove the variant we no longer ship for this kind (e.g. leftover ability fulls).
  if ! $want_full && [[ -d "$imageset" ]]; then
    rm -rf "$imageset"
  fi
  if ! $want_thumb && [[ -d "$thumb_imageset" ]]; then
    rm -rf "$thumb_imageset"
  fi

  escaped_id="$(escape_swift_string "$id")"
  escaped_asset="$(escape_swift_string "$asset_name")"
  escaped_thumb="$(escape_swift_string "$thumb_asset")"
  if [[ "$kind" == "combatant" ]]; then
    cat >> "$combatants_temp" <<SWIFT
        "$escaped_id": CombatantArtReference(
            imageName: "$escaped_asset",
            thumbnailImageName: "$escaped_thumb",
            focalPoint: ArtFocalPoint(x: $focal_x, y: $focal_y)
        ),
SWIFT
  elif [[ "$kind" == "ability" ]]; then
    cat >> "$abilities_temp" <<SWIFT
        "$escaped_id": AbilityArtReference(
            imageName: "$escaped_thumb"
        ),
SWIFT
  elif [[ "$kind" == "item" ]]; then
    cat >> "$items_temp" <<SWIFT
        "$escaped_id": ItemArtReference(
            imageName: "$escaped_asset",
            thumbnailImageName: "$escaped_thumb"
        ),
SWIFT
  elif [[ "$kind" == "slot_background" ]]; then
    case "$id" in
      weapon|armor|trinket) ;;
      *)
        echo "Slot background id '$id' must be one of: weapon, armor, trinket." >&2
        exit 1
        ;;
    esac
    cat >> "$slot_backgrounds_temp" <<SWIFT
        .$id: SlotBackgroundArtReference(
            imageName: "$escaped_asset"
        ),
SWIFT
  elif [[ "$kind" == "background" ]]; then
    cat >> "$backgrounds_temp" <<SWIFT
        "$escaped_id": BackgroundArtReference(
            imageName: "$escaped_asset",
            focalPoint: ArtFocalPoint(x: $focal_x, y: $focal_y)
        ),
SWIFT
  elif [[ "$kind" == "resource" ]]; then
    cat >> "$resources_temp" <<SWIFT
        "$escaped_id": ResourceArtReference(
            imageName: "$escaped_asset"
        ),
SWIFT
  elif [[ "$kind" == "encounter" ]]; then
    cat >> "$encounters_temp" <<SWIFT
        "$escaped_id": EncounterArtReference(
            imageName: "$escaped_asset",
            thumbnailImageName: "$escaped_thumb"
        ),
SWIFT
  fi

  processed_count=$((processed_count + 1))
done < "$manifest"

{
  cat <<'SWIFT_HEADER'
// Generated by Scripts/prepare-art-assets.sh. Do not edit directly.

import TrinketCore

/// Normalized art crop anchor. Kept as Doubles so the catalog stays Sendable
/// without relying on SwiftUI `UnitPoint` Sendable conformance.
public struct ArtFocalPoint: Hashable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}
SWIFT_HEADER

  cat <<SWIFT

public struct CombatantArtReference: Hashable, Sendable {
    public let imageName: String
    public let thumbnailImageName: String?
    public let focalPoint: ArtFocalPoint
}

public struct AbilityArtReference: Hashable, Sendable {
    public let imageName: String
}

public struct ItemArtReference: Hashable, Sendable {
    public let imageName: String
    public let thumbnailImageName: String?
}

public struct SlotBackgroundArtReference: Hashable, Sendable {
    public let imageName: String
}

public struct BackgroundArtReference: Hashable, Sendable {
    public let imageName: String
    public let focalPoint: ArtFocalPoint
}

public struct ResourceArtReference: Hashable, Sendable {
    public let imageName: String
}

public struct EncounterArtReference: Hashable, Sendable {
    public let imageName: String
    public let thumbnailImageName: String?
}


public enum ArtCatalog {
    public static let combatantArtByID: [String: CombatantArtReference] = [
$(cat "$combatants_temp")
    ]

    public static let abilityArtByID: [String: AbilityArtReference] = [
$(cat "$abilities_temp")
    ]

    public static let itemArtByID: [String: ItemArtReference] = [
$(cat "$items_temp")
    ]

    public static let slotBackgroundArtByID: [ItemSlot: SlotBackgroundArtReference] = [
$(cat "$slot_backgrounds_temp")
    ]

    public static let backgroundArtByID: [String: BackgroundArtReference] = [
$(cat "$backgrounds_temp")
    ]

    public static let encounterArtByID: [String: EncounterArtReference] = [
$(cat "$encounters_temp")
    ]

    public static let resourceArtByID: [String: ResourceArtReference] = [
$(cat "$resources_temp")
    ]

}

extension Combatant {
    public var artReference: CombatantArtReference? {
        ArtCatalog.combatantArtByID[id]
    }
}

extension Ability {
    public var artReference: AbilityArtReference? {
        ArtCatalog.abilityArtByID[id]
    }
}

SWIFT

  # Quoted heredoc so Swift interpolations and comments are not shell-expanded.
  cat <<'SWIFT_EXTENSIONS'
extension InventoryItem {
    public var artReference: ItemArtReference? {
        // Catalog keys are template ids (e.g. crossbow-basic), not per-instance ids.
        ArtCatalog.itemArtByID[templateID]
            ?? ArtCatalog.itemArtByID["\(baseType.id)-\(rarity.rawValue)"]
    }
}

extension ItemSlot {
    public var slotBackgroundReference: SlotBackgroundArtReference? {
        ArtCatalog.slotBackgroundArtByID[self]
    }
}
SWIFT_EXTENSIONS
} > "$generated_temp"

if [[ -f "$generated_swift" ]] && cmp -s "$generated_temp" "$generated_swift"; then
  rm -f "$generated_temp"
else
  mv "$generated_temp" "$generated_swift"
fi

# Prune orphaned assets
shopt -s nullglob
for dir in "$asset_catalog"/*/*.imageset "$asset_catalog"/*.imageset; do
  [[ -d "$dir" ]] || continue
  foldername=$(basename "$dir")
  name="${foldername%.imageset}"

  case "$name" in
    hero_*|companion_*|enemy_*|ability_*|item_*|slot_*|bg_*|encounter_*|resource_*)
      if ! grep -qx "$name" "$active_assets_temp"; then
        echo "Pruning orphaned asset: $foldername"
        rm -rf "$dir"
      fi
      ;;
  esac
done
shopt -u nullglob

rm -f "$combatants_temp" "$abilities_temp" "$items_temp" "$slot_backgrounds_temp" "$backgrounds_temp" "$encounters_temp" "$resources_temp" "$active_assets_temp"

echo "Prepared $processed_count curated art asset(s) (converted $full_count full / $thumb_count thumb this run; kind-aware variants)."
