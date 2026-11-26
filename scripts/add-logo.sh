#!/usr/bin/env bash
# Adds (or replaces) an issuer's logo in the app.
#
#   scripts/add-logo.sh <issuer-id> <logo.svg|logo.png>
#
# Example:   scripts/add-logo.sh synchrony ~/Downloads/synchrony.svg
#
# <issuer-id> is the issuer's ID in opencard-db (chase, capital-one, us-bank, ...). The list of IDs is in
# docs/issuer-logos.md. The script turns the file into a transparent PNG (512 pixels on the long side,
# shape kept) and creates the image set `logo-<issuer-id>` in the asset catalog. The app finds it by
# that name, so no Swift code changes.
#
# Needs one of: rsvg-convert (brew install librsvg) or ImageMagick (brew install imagemagick).
# A PNG input only needs ImageMagick (or macOS's built-in sips).

set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: scripts/add-logo.sh <issuer-id> <logo.svg|logo.png>" >&2
  exit 1
fi

id="$1"
source_file="$2"

if ! [[ "$id" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "Issuer ID '$id' should be lowercase letters, digits and dashes, like 'capital-one'." >&2
  exit 1
fi
if [ ! -f "$source_file" ]; then
  echo "Cannot find $source_file" >&2
  exit 1
fi

root="$(cd "$(dirname "$0")/.." && pwd)"
set_dir="$root/CreditCardTracker/Resources/Assets.xcassets/IssuerLogos/logo-$id.imageset"
png="$set_dir/logo-$id.png"
mkdir -p "$set_dir"

extension="$(printf '%s' "${source_file##*.}" | tr '[:upper:]' '[:lower:]')"

case "$extension" in
  svg)
    if command -v rsvg-convert >/dev/null 2>&1; then
      # Fits inside 512 x 512, keeps the shape, transparent background.
      rsvg-convert --keep-aspect-ratio --width 512 --height 512 "$source_file" -o "$png"
    elif command -v magick >/dev/null 2>&1; then
      magick -background none -density 384 "$source_file" -resize 512x512 "$png"
    elif command -v convert >/dev/null 2>&1; then
      convert -background none -density 384 "$source_file" -resize 512x512 "$png"
    else
      echo "Install rsvg-convert (brew install librsvg) or ImageMagick (brew install imagemagick)." >&2
      exit 1
    fi
    ;;
  png)
    if command -v magick >/dev/null 2>&1; then
      magick "$source_file" -resize 512x512 "$png"
    elif command -v convert >/dev/null 2>&1; then
      convert "$source_file" -resize 512x512 "$png"
    elif command -v sips >/dev/null 2>&1; then
      cp "$source_file" "$png"
      sips --resampleHeightWidthMax 512 "$png" >/dev/null
    else
      echo "Install ImageMagick (brew install imagemagick)." >&2
      exit 1
    fi
    ;;
  *)
    echo "Use an .svg or .png file (got .$extension)." >&2
    exit 1
    ;;
esac

cat > "$set_dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "logo-$id.png",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Added logo-$id."
echo "Next: add a line for it in docs/issuer-logos.md (where it came from and its license), then build."
