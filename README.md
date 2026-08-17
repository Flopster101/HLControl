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

All modern Haylou / Liesheng Bluetooth headsets and earbuds using the unified protocol are supported. Available features adapt dynamically based on the connected device's capability matrix.

- **Over-Ear Headphones**:
  - **Haylou S40 (Confirmed working)**
  - Haylou S35 ANC
  - Haylou S30
  - Haylou FlowLoop S33 / HD01
- **Active Noise Cancelling (ANC) Earbuds**:
  - Haylou W1 ANC (X2)
  - Haylou Mori Pro (T016)
  - Haylou Flowbuds N55 (T021, with Smart Wear Detection)
  - Haylou Flowbuds N50 (HT02)
  - Haylou Flowbuds N70 (HT03)
  - Haylou Flowbuds N10 (HT06)
- **Standard & Gaming Earbuds**:
  - Haylou X1 2023
  - Haylou X1 Plus (T013)
  - Haylou X1 ACE (X1L)
- **Open-Ear & Bone Conduction**:
  - Haylou Purfree Lite (BC04, with Anti-Sound Leak)
  - Haylou Earhook 1 (OW02)
  - Haylou Airfree (OW03)

*Note: Only the **Haylou S40** has been physically tested and verified. Other models have complete protocol mappings and capability profiles based on official firmware definitions.*

## Features (if supported by headset)

- **Noise Control**: Active Noise Cancellation (ANC), Transparency / Ambient Aware, Adaptive ANC, and intensity levels.
- **Graphic Equalizer**: 10-band custom graphic EQ with real-time response curve, adaptive stock presets (9 standard presets / 5 S40 presets), and custom user preset management.
- **Audio Features**: Low-latency Game Mode, Wind Noise Reduction, Multipoint Connection, LDAC toggle, Smart Wear Detection, Anti-Sound Leak, and Spatial Audio (Dynamic / Static).
- **Capacitive Touch Gestures**: Customizable Double Tap, Triple Tap, and Long Press actions independently per earbud (on supported TWS models).
- **Power Management**: Auto-shutdown idle timer and discrete Left / Right / Case battery indicators for TWS models.
- **Device Management**: Rename headset, Find my headset (audio beacon), connection info, and auto-reconnect.
- **Desktop System Tray**: Background indicator with quick ANC controls, audio toggles, and dynamic menu.
- **Interface**: Material Design 3 interface with adaptive desktop/mobile layouts, dark/light/system theme modes, and dynamic Material You colors.

## License

This project is licensed under the GNU General Public License v3.0 (GPL-3.0). See [LICENSE](LICENSE) for details.
