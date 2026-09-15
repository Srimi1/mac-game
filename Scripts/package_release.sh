#!/bin/bash

set -euo pipefail

release_version="${1:-}"
if [[ ! "$release_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: Scripts/package_release.sh <major.minor.patch>" >&2
  exit 64
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
release_work_dir="$(mktemp -d "${TMPDIR:-/tmp}/break-the-quiet-days-release.XXXXXX")"
derived_data="$release_work_dir/DerivedData"
stage_dir="$release_work_dir/Break the Quiet Days $release_version"
output_dir="$repository_root/dist"
archive_name="Break-the-Quiet-Days-$release_version-macOS-Apple-Silicon.zip"
archive_path="$output_dir/$archive_name"

cleanup() {
  rm -rf -- "$release_work_dir"
}
trap cleanup EXIT

mkdir -p "$stage_dir" "$output_dir"

xcodebuild \
  -project "$repository_root/BreakTheQuietDays.xcodeproj" \
  -scheme BreakTheQuietDays \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

source_app="$derived_data/Build/Products/Release/Break the Quiet Days.app"
staged_app="$stage_dir/Break the Quiet Days.app"

if [[ ! -d "$source_app" ]]; then
  echo "Release app was not produced at: $source_app" >&2
  exit 1
fi

ditto --norsrc --noextattr --noqtn --noacl "$source_app" "$staged_app"
xattr -cr "$staged_app"
codesign --force --deep --sign - "$staged_app"
codesign --verify --deep --strict --verbose=2 "$staged_app"

cp "$repository_root/Distribution/HOW-TO-PLAY.txt" "$stage_dir/HOW TO PLAY.txt"
rm -f "$archive_path" "$archive_path.sha256"
ditto -c -k --norsrc --noextattr "$stage_dir" "$archive_path"

(
  cd "$output_dir"
  shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

echo "Created: $archive_path"
echo "Checksum: $archive_path.sha256"
