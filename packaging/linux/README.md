# Linux packaging

Desktop file and AppStream metadata live in `linux/`:

- `linux/com.happycolor.app.desktop` — FreeDesktop entry
- `linux/com.happycolor.app.metainfo.xml` — AppStream metadata

Icons (hicolor) are in `packaging/icons/` — install them to `/usr/share/icons/hicolor/<size>/apps/` or bundle them.

## Manual build

```bash
flutter build linux --release
tar -czf HappyColor-Linux.tar.gz -C build/linux/x64/release/bundle .
```

## Debian package (requires `fpm`)

```bash
sudo apt install ruby-dev build-essential
sudo gem install --no-document fpm
VERSION=$(grep '^version:' pubspec.yaml | sed 's/.*: //; s/+.*//')
fpm -s dir -t deb -n happy-color -v "$VERSION" \
  -C build/linux/x64/release/bundle . \
  --description "Happy Color — numbers hidden but detectable for coloring" \
  --prefix /opt/happy-color
```
