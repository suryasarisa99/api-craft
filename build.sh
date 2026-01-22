flutter build macos --release \
&& APP=build/macos/Build/Products/Release/api_craft.app \
&& codesign --force --deep --sign - "$APP" \
&& xattr -cr "$APP" \
&& rm -f api_craft.dmg \
&& appdmg dmg.json api_craft.dmg