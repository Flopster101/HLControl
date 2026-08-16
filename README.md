# <img src="assets/images/app_icon.png" width="36" height="36" align="absmiddle" alt="HLControl Logo" /> HLControl

An alternative multiplatform open-source controller app for Haylou Bluetooth headsets.

## Downloads

- **Nightly Builds**: Automated builds from the `main` branch are available on [nightly.link](https://nightly.link/Flopster101/HLControl/workflows/build/main?preview).

| Platform | Format | Description |
| :--- | :--- | :--- |
| **Android** | `.zip` (APKs) | Split-per-ABI signed release and debug APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`) |
| **Windows** | `.exe` / `.zip` | Inno Setup installer (`.exe`) and portable standalone archive (`.zip`) |
| **Linux** | `.AppImage` / `.pkg.tar.zst` / `.tar.gz` | Standalone AppImage, Arch Linux package, and generic tarball |

## Device Support

- **Haylou S40**: Fully tested and working.
- Other Haylou / Liesheng models are currently untested.

## Features (if supported by headset)

- **Noise Control**: Active Noise Cancellation (ANC), Transparency / Ambient Aware, Adaptive ANC, and intensity levels.
- **Graphic Equalizer**: 10-band custom graphic EQ with real-time response curve, stock presets (Default, Bass booster, Rock, Soft, Classical), and custom user preset management.
- **Audio Features**: Low-latency Game Mode, Wind Noise Reduction, Multipoint Connection, LDAC toggle, Wear Detection, and Spatial Audio (Dynamic / Static).
- **Power Management**: Auto-shutdown idle timer (30m, 1h, 3h, 5h, Never).
- **Device Management**: Rename headset, Find my headset (audio beacon), connection info, and auto-reconnect.
- **Desktop System Tray**: Background indicator with quick ANC controls, audio toggles, and dynamic menu.
- **Interface**: Material Design 3 interface with adaptive desktop/mobile layouts, dark/light/system theme modes, and dynamic Material You colors.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See [LICENSE](LICENSE) for details.
