#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
version="$1"
arch=$(uname -m)
target=$(rustc -vV | sed -n 's/^host: //p')
export ZED_BUNDLE=true
export ZED_UPDATE_EXPLANATION='Zed Custom updates are provided by sasha00123/tap/zed-custom or GitHub Releases.'
export ZED_RELEASE_CHANNEL=dev
export ZED_COMMIT_SHA
ZED_COMMIT_SHA=$(git rev-parse HEAD)
script/generate-licenses
cargo build --locked --release -p zed -p cli --target "$target"
cargo build --locked --release -p remote_server --target "$target"
# Select bundle metadata in a temporary manifest, restoring it even on failure.
manifest=$(mktemp)
cp crates/zed/Cargo.toml "$manifest"
trap 'cp "$manifest" crates/zed/Cargo.toml; rm -f "$manifest"' EXIT
python3 - <<'PY'
from pathlib import Path
p=Path('crates/zed/Cargo.toml')
s=p.read_text().replace('[package.metadata.bundle-dev]', '[package.metadata.bundle]')
p.write_text(s)
PY
(cd crates/zed && CARGO_BUNDLE_SKIP_BUILD=1 cargo bundle --release --target "$target" --select-workspace-root)
app="target/$target/release/bundle/osx/Zed Dev.app"
cp "target/$target/release/cli" "$app/Contents/MacOS/cli"
cp "target/$target/release/remote_server" "$app/Contents/MacOS/remote_server"
cp "$manifest" crates/zed/Cargo.toml
rm -f "$manifest"
trap - EXIT
python3 distribution/package.py "$app" "$version" "$arch"
