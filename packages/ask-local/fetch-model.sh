# shellcheck shell=bash
# Shared first-run model autofetch helper for user/system-scoped model wrappers.
# Large weights stay outside the Nix store by default, but land automatically on
# first invocation instead of failing with a curl hint.

# fetch_model DEST URL
#   If DEST is missing, curl URL -> DEST atomically (.part + mv) with a progress
#   bar. On failure, clean up and print the manual curl line as a copy-pasteable
#   fallback (offline / 404), then return 1 so `set -e` callers exit.
fetch_model() {
  local dest="$1" url="$2"
  if [[ -f $dest ]]; then return 0; fi
  mkdir -p "$(dirname "$dest")"
  echo "$(basename "$0"): fetching $(basename "$dest") (first run)..." >&2
  if curl -fL --progress-bar -o "$dest.part" "$url" && mv "$dest.part" "$dest"; then
    return 0
  fi
  rm -f "$dest.part"
  echo "$(basename "$0"): fetch failed; manual: curl -L -o '$dest' '$url'" >&2
  return 1
}
