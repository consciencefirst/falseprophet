#!/bin/bash
# sync-from-downloads.sh
# Moves the latest downloaded falseprophet files from ~/Downloads to ~/Desktop/falseprophet,
# handling Mac's automatic " (1)", " (2)" rename pattern when a file already exists.
#
# Usage: ./sync-from-downloads.sh
# Or via Automator: shell action with command:  bash /path/to/sync-from-downloads.sh

set -e  # Exit on any error

DOWNLOADS="$HOME/Downloads"
TARGET="$HOME/Desktop/falseprophet"

# Make sure target exists
mkdir -p "$TARGET"

# Files we care about — base name (no path)
FILES=("index.html" "contact.html" "favicon.svg" "favicon.png" "apple-touch-icon.png" "deploy.py")

# Track what we did, so we can summarize at the end
moved_count=0
skipped_count=0
report=""

for filename in "${FILES[@]}"; do
  # Strip extension and base — e.g. "index.html" → base="index", ext="html"
  base="${filename%.*}"
  ext="${filename##*.}"

  # Find any matching files in Downloads:
  #   filename                   (e.g. index.html)
  #   filename with " (N)"       (e.g. index (1).html, index (12).html)
  # macOS uses "filename (N).ext" — note the space before the (
  #
  # Use find with maxdepth 1 so we don't recurse, and -type f for regular files only.
  # Use -print0 + read -d '' to safely handle any odd characters in filenames.
  candidates=()
  while IFS= read -r -d '' file; do
    candidates+=("$file")
  done < <(find "$DOWNLOADS" -maxdepth 1 -type f \
             \( -name "$filename" -o -name "$base ([0-9]*).$ext" \) \
             -print0 2>/dev/null)

  # If nothing found, skip this file silently
  if [ ${#candidates[@]} -eq 0 ]; then
    continue
  fi

  # Find the newest candidate by modification time
  newest=""
  newest_mtime=0
  for f in "${candidates[@]}"; do
    mtime=$(stat -f %m "$f")
    if [ "$mtime" -gt "$newest_mtime" ]; then
      newest_mtime=$mtime
      newest="$f"
    fi
  done

  # Detect whether the newest one was renamed (had a "(N)" suffix)
  newest_basename=$(basename "$newest")
  if [ "$newest_basename" != "$filename" ]; then
    report+="⚠️  Found renamed download: $newest_basename — you forgot to delete the previous one\n"
  fi

  # If the target already has this file, delete the stale copy
  if [ -f "$TARGET/$filename" ]; then
    rm "$TARGET/$filename"
    report+="🗑   Deleted stale $filename from $TARGET\n"
  fi

  # Move the newest download to the target, renaming if necessary
  mv "$newest" "$TARGET/$filename"
  report+="✅  Moved $newest_basename → $TARGET/$filename\n"
  moved_count=$((moved_count + 1))

  # Clean up any other older "(N)" copies of this file in Downloads
  for f in "${candidates[@]}"; do
    if [ -f "$f" ] && [ "$f" != "$newest" ]; then
      rm "$f"
      report+="🧹  Cleaned up older copy: $(basename "$f")\n"
    fi
  done
done

# Print summary
echo ""
echo "═══════════════════════════════════════════════════"
echo "  FalseProphet sync complete"
echo "═══════════════════════════════════════════════════"
if [ $moved_count -eq 0 ]; then
  echo "No files found in $DOWNLOADS to sync."
  echo "(If you just downloaded files, check ~/Downloads exists and contains them.)"
else
  echo -e "$report"
  echo "Synced $moved_count file(s) to $TARGET"
fi
echo "═══════════════════════════════════════════════════"
