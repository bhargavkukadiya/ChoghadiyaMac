# Choghadiya icons

Editable vector artwork: [Figma icon file](https://www.figma.com/design/Cj38vuhwShEoc84x4VF0o6).

The sunrise and eight dial segments represent the eight periods in each day/night
cycle. Deep teal, warm gold, and mint complement the app's existing colors.
The artwork is original to this project and covered by the repository MIT license.

- `AppIcon.svg`: editable source with transparent macOS margins.
- `AppIcon.png`: 1024-pixel Figma export used to generate the macOS icon sizes.
- `BrandMark.svg`: standalone mark used in the sidebar and unavailable widget state.
- `DayIcon.svg` / `NightIcon.svg`: monochrome template symbols for the period picker.

The app icon lives in `App/Resources/Assets.xcassets/AppIcon.appiconset`; the other
assets live in `Shared/Assets.xcassets` for both app and widget targets.
Standard controls and the existing auspiciousness symbols continue to use SF Symbols.

After editing the app icon in Figma, export AppIcon at 1024 × 1024 as a PNG with
transparency, replace `AppIcon.png`, then regenerate the catalog images with:

```bash
bash script/generate_app_icons.sh
```

The script generates every required representation from 16 to 1024 pixels.
Copy changed companion SVGs to their corresponding shared imagesets.
Regenerate the Xcode project with `xcodegen generate` after changing asset structure.
