import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/controllers/headphone_controller.dart';
import '../../core/models/bluetooth_device.dart';
import '../theme/theme_controller.dart';
import '../widgets/anc_selector.dart';
import '../widgets/eq_selector.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeController,
    required this.headphoneController,
  });

  final ThemeController themeController;
  final HeadphoneController headphoneController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  int _versionTapCount = 0;

  // Getters from HeadphoneController
  bool get _isConnected => widget.headphoneController.isConnected;
  bool get _isConnecting => widget.headphoneController.isConnecting;
  String get _deviceName => widget.headphoneController.deviceName;
  bool get _isOverEar {
    final name = _deviceName.toLowerCase();
    return name.contains('s40') || name.contains('s35') || name.contains('s30');
  }
  int get _batteryPercent => widget.headphoneController.batteryPercent;

  String get _selectedAncMode {
    final mode = widget.headphoneController.status.ancMode;
    if (mode.contains('Normal') || mode.contains('Off')) return 'Normal';
    if (mode.contains('Adaptive')) return 'Adaptive';
    if (mode.contains('ANC')) return 'ANC On';
    if (mode.contains('Transparency') || mode.contains('Aware')) return 'Transparency';
    return 'Normal';
  }

  int _selectedAncIntensity = 0; // preserved locally for UI purposes

  String get _selectedEqPreset => widget.headphoneController.status.eqPreset;

  bool get _gameMode => widget.headphoneController.status.gameMode ?? false;
  bool get _windNoiseReduction => widget.headphoneController.status.windNoise ?? false;
  bool get _multipoint => widget.headphoneController.status.multipoint ?? false;

  String get _spatialAudioMode => widget.headphoneController.status.spatialAudioMode;
  String get _spatialScene => widget.headphoneController.status.spatialScene;

  bool get _wearDetection => widget.headphoneController.status.wearDetection ?? false;

  int get _autoShutdownIndex => widget.headphoneController.status.autoShutdownIndex ?? 4;
  final List<String> _shutdownOptions = ['30 Min', '1 Hour', '3 Hours', '5 Hours', 'Never'];

  // Custom EQ states (10-band slider values from -10 to +10 dB)
  final List<double> _eqValues = List.filled(10, 0.0);
  final List<String> _eqBands = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];

  // Custom EQ presets list
  final List<Map<String, dynamic>> _customPresets = [
    {
      'name': 'Vocal Booster',
      'values': [-2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0],
    },
    {
      'name': 'Electronic',
      'values': [5.0, 4.0, 1.0, -1.0, -2.0, 1.0, 3.0, 4.0, 5.0, 5.0],
    },
  ];

  static const Map<String, List<double>> _presetValues = {
    'Default': [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Subwoofer': [6.0, 5.0, 4.0, 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.0, 3.0, -1.0, -2.0, 0.0, 1.0, 2.0, 3.0, 4.0, 4.0],
    'Soft': [-2.0, -1.0, 0.0, 1.0, 2.0, 2.0, 1.0, 0.0, -1.0, -2.0],
    'Classical': [3.0, 2.0, 1.5, 1.0, -1.0, -1.5, 1.0, 2.0, 2.5, 3.0],
  };

  void _showSavePresetDialog() {
    if (!_isConnected) return;
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Custom Preset'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Preset Name (e.g. My Bass)',
            border: OutlineInputBorder(),
          ),
          maxLength: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _customPresets.removeWhere((p) => p['name'] == name);
                  _customPresets.add({
                    'name': name,
                    'values': List<double>.from(_eqValues),
                  });
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog() {
    if (!_isConnected) return;
    final textController = TextEditingController(text: _deviceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter new device name',
            border: OutlineInputBorder(),
          ),
          maxLength: 30,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                widget.headphoneController.renameDevice(textController.text.trim());
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: widget.headphoneController,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 650;

            return Scaffold(
              appBar: isWide
                  ? null // Hide appBar on desktop because Sidebar has the title header
                  : AppBar(
                      title: const Text('HL Control'),
                      elevation: 0,
                    ),
              body: isWide
                  ? Row(
                      children: [
                        _buildSidebar(theme),
                        const VerticalDivider(thickness: 1, width: 1),
                        Expanded(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _buildCurrentTabContent(theme),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _buildCurrentTabContent(theme),
                        ),
                      ),
                    ),
              bottomNavigationBar: isWide
                  ? null
                  : SafeArea(
                      child: NavigationBar(
                        selectedIndex: _currentTab,
                        onDestinationSelected: (index) {
                          setState(() {
                            _currentTab = index;
                          });
                        },
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.tune),
                            label: 'Control',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.equalizer),
                            label: 'Equalizer',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  void _connectDevice() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Scanning paired devices...'),
          ],
        ),
      ),
    );

    try {
      final List<BluetoothDevice> devices = await widget.headphoneController.getPairedDevices();
      if (!mounted) return;
      Navigator.pop(context); // close scanning dialog

      if (devices.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Headphones Found'),
            content: const Text(
              'No paired Haylou headphones were found on your system. '
              'Please pair your headphones in your OS Bluetooth settings first.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else if (devices.length == 1) {
        widget.headphoneController.connect(devices[0].macAddress);
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Select Device'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final dev = devices[index];
                  return ListTile(
                    leading: const Icon(Icons.bluetooth),
                    title: Text(dev.name),
                    subtitle: Text(dev.macAddress),
                    onTap: () {
                      Navigator.pop(context);
                      widget.headphoneController.connect(dev.macAddress);
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildSidebar(ThemeData theme) {
    return Container(
      width: 240,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HL Control',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_isConnected) ...[
                  const SizedBox(height: 4),
                  Text(
                    _deviceName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.tune,
            label: 'Control',
            index: 0,
            selectedIndex: _currentTab,
            onTap: () => setState(() => _currentTab = 0),
          ),
          _SidebarItem(
            icon: Icons.equalizer,
            label: 'Equalizer',
            index: 1,
            selectedIndex: _currentTab,
            onTap: () => setState(() => _currentTab = 1),
          ),
          _SidebarItem(
            icon: Icons.settings,
            label: 'Settings',
            index: 2,
            selectedIndex: _currentTab,
            onTap: () => setState(() => _currentTab = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTabContent(ThemeData theme) {
    switch (_currentTab) {
      case 0:
        return _buildControlTab(theme);
      case 1:
        return _buildEqualizerTab(theme);
      case 2:
        return _buildSettingsTab(theme);
      default:
        return _buildControlTab(theme);
    }
  }

  Widget _buildCenteredScrollable({
    required Key key,
    required List<Widget> children,
    required EdgeInsetsGeometry padding,
  }) {
    return Center(
      child: SingleChildScrollView(
        key: key,
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  // --- CONTROL TAB ---
  Widget _buildControlTab(ThemeData theme) {
    final status = widget.headphoneController.status;
    final isWearSupported = !_isOverEar && status.wearDetection != null;
    final hasAudioFeatures = !_isConnected ||
        status.gameMode != null ||
        status.windNoise != null ||
        status.multipoint != null ||
        isWearSupported ||
        status.spatialAudioMode != 'Unknown';
    return _buildCenteredScrollable(
      key: const ValueKey(0),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        _buildConnectionBanner(theme),
        const SizedBox(height: 24),

        // Premium Product Image & Battery Indicators
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeadphonesImage(theme),
              const SizedBox(height: 14),
              Text(
                _isConnected ? _deviceName : 'Disconnected',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildBatteryIndicator(theme),
            ],
          ),
        ),

        // Noise Control Section
        if (!_isConnected || status.ancMode != 'Unknown') ...[
          _buildSectionHeader(theme, 'Noise Control'),
          const SizedBox(height: 12),
          AncSelector(
            selectedMode: _selectedAncMode,
            enabled: _isConnected,
            onChanged: (mode) {
              int modeVal = 0;
              if (mode == 'ANC On') {
                modeVal = 1;
              } else if (mode == 'Transparency') {
                modeVal = 2;
              } else if (mode == 'Adaptive') {
                modeVal = 4;
              }
              widget.headphoneController.setAncMode(modeVal);
            },
          ),
          if (_isConnected && (_selectedAncMode == 'ANC On' || _selectedAncMode == 'Adaptive')) ...[
            const SizedBox(height: 12),
            _buildAncIntensityCard(theme),
          ],
          const SizedBox(height: 28),
        ],

        // Auto Shutdown Section
        if (!_isConnected || (status.autoShutdownIndex != null && !_isOverEar)) ...[
          _buildSectionHeader(theme, 'Auto Shutdown'),
          const SizedBox(height: 12),
          _buildAutoShutdownCard(theme),
          const SizedBox(height: 28),
        ],

        // Audio Features Section
        if (hasAudioFeatures) ...[
          _buildSectionHeader(theme, 'Audio Features'),
          const SizedBox(height: 12),
          _buildFeaturesCard(theme),
        ],
      ],
    );
  }

  Widget _buildHeadphonesImage(ThemeData theme) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 2,
        ),
        image: DecorationImage(
          image: const AssetImage('assets/images/headphones.png'),
          fit: BoxFit.cover,
          colorFilter: !_isConnected
              ? const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.saturation,
                )
              : null,
        ),
      ),
      child: !_isConnected
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
              ),
            )
          : null,
    );
  }

  Widget _buildBatteryIndicator(ThemeData theme) {
    if (!_isConnected) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Chip(
          avatar: Icon(
            _batteryPercent > 20 ? Icons.battery_5_bar : Icons.battery_alert,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          label: Text(
            '$_batteryPercent% Battery',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
          backgroundColor: theme.cardColor,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 140,
          height: 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _batteryPercent / 100.0,
              backgroundColor: theme.colorScheme.onSurface.withOpacity(0.16),
              valueColor: AlwaysStoppedAnimation<Color>(
                _batteryPercent > 25
                    ? theme.colorScheme.primary
                    : theme.colorScheme.error,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAncIntensityCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ANC Level',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _selectedAncIntensity == 2 ? 'Low' : (_selectedAncIntensity == 1 ? 'Medium' : 'High'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment<int>(
                    value: 2,
                    label: Text('Low'),
                  ),
                  ButtonSegment<int>(
                    value: 1,
                    label: Text('Medium'),
                  ),
                  ButtonSegment<int>(
                    value: 0,
                    label: Text('High'),
                  ),
                ],
                selected: {_selectedAncIntensity},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _selectedAncIntensity = newSelection.first;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- EQUALIZER TAB ---
  // --- EQUALIZER TAB ---
  Widget _buildEqualizerTab(ThemeData theme) {
    return _buildCenteredScrollable(
      key: const ValueKey(1),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        _buildSectionHeader(theme, 'Select Preset'),
        const SizedBox(height: 12),
        Opacity(
          opacity: _isConnected ? 1.0 : 0.4,
          child: EqSelector(
            selectedPreset: _selectedEqPreset,
            enabled: _isConnected,
            onChanged: (preset) {
              final presets = ['Default', 'Subwoofer', 'Rock', 'Soft', 'Classical'];
              final idx = presets.indexOf(preset);
              if (idx != -1) {
                widget.headphoneController.setEqPreset(idx);
                final vals = _presetValues[preset];
                if (vals != null) {
                  setState(() {
                    for (int i = 0; i < 10; i++) {
                      _eqValues[i] = vals[i];
                    }
                  });
                }
              }
            },
          ),
        ),
        const SizedBox(height: 32),
        _buildSectionHeader(theme, 'Custom Graphic EQ'),
        const SizedBox(height: 12),
        Opacity(
          opacity: _isConnected ? 1.0 : 0.4,
          child: _buildCustomEqCard(theme),
        ),
        if (_customPresets.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildSectionHeader(theme, 'My Custom Presets'),
          const SizedBox(height: 12),
          Opacity(
            opacity: _isConnected ? 1.0 : 0.4,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _customPresets.map((preset) {
                    final name = preset['name'] as String;
                    final values = preset['values'] as List<double>;

                    // Check if current sliders match these values
                    bool isMatch = true;
                    for (int i = 0; i < 10; i++) {
                      if ((_eqValues[i] - values[i]).abs() > 0.01) {
                        isMatch = false;
                        break;
                      }
                    }

                    return InputChip(
                      label: Text(name),
                      selected: isMatch,
                      onSelected: _isConnected
                          ? (selected) {
                              setState(() {
                                for (int i = 0; i < 10; i++) {
                                  _eqValues[i] = values[i];
                                }
                              });
                              widget.headphoneController.setEqPreset(15);
                            }
                          : null,
                      onDeleted: _isConnected
                          ? () {
                              setState(() {
                                _customPresets.remove(preset);
                              });
                            }
                          : null,
                      deleteIcon: const Icon(Icons.close, size: 16),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomEqCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '10-Band Graphic EQ',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _isConnected ? _showSavePresetDialog : null,
                      icon: const Icon(Icons.save),
                      tooltip: 'Save Preset',
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      onPressed: _isConnected
                          ? () {
                              setState(() {
                                _eqValues.fillRange(0, _eqValues.length, 0.0);
                              });
                              widget.headphoneController.setEqPreset(0);
                            }
                          : null,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Reset EQ',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Premium EQ curve visualizer
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _EqCurvePainter(
                    values: _eqValues,
                    primaryColor: theme.colorScheme.primary,
                    gridColor: theme.colorScheme.onSurfaceVariant.withOpacity(0.08),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // EQ Sliders distributed evenly using Expanded children inside a Row
            SizedBox(
              height: 220,
              child: Row(
                children: List.generate(_eqValues.length, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: theme.sliderTheme.copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                ),
                                child: Slider(
                                  value: _eqValues[index],
                                  min: -10,
                                  max: 10,
                                  divisions: 20,
                                  onChanged: _isConnected
                                      ? (val) {
                                          setState(() {
                                            _eqValues[index] = val;
                                          });
                                          widget.headphoneController.setEqPreset(15);
                                        }
                                      : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_eqValues[index].round() > 0 ? "+" : ""}${_eqValues[index].round()}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                              color: _eqValues[index] != 0.0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _eqBands[index],
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- SETTINGS TAB ---
  Widget _buildSettingsTab(ThemeData theme) {
    return _buildCenteredScrollable(
      key: const ValueKey(2),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        _buildSectionHeader(theme, 'Device Settings'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename Headset'),
                subtitle: Text(_isConnected ? _deviceName : 'Disconnected'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isConnected ? _showRenameDialog : null,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Connection Mode'),
                subtitle: Text(_isConnected ? 'Bluetooth Classic RFCOMM (Port 10)' : 'Not Connected'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _buildSectionHeader(theme, 'Theme Settings'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Theme Mode'),
                subtitle: Text(_getThemeModeName(widget.themeController.themeMode)),
                trailing: DropdownButton<ThemeMode>(
                  value: widget.themeController.themeMode,
                  underline: const SizedBox.shrink(),
                  onChanged: (mode) {
                    if (mode != null) {
                      widget.themeController.setThemeMode(mode);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System Default'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light Mode'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark Mode'),
                    ),
                  ],
                ),
              ),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                SwitchListTile(
                  secondary: const Icon(Icons.color_lens_outlined),
                  title: const Text('Dynamic Colors'),
                  subtitle: const Text('Use wallpaper-based Material You colors (Android 12+)'),
                  value: widget.themeController.useDynamicColor,
                  onChanged: (val) {
                    widget.themeController.setUseDynamicColor(val);
                  },
                ),
              ],
            ],
          ),
        ),
        if (widget.themeController.isDeveloperMode) ...[
          const SizedBox(height: 28),
          _buildSectionHeader(theme, 'Developer Settings'),
          const SizedBox(height: 12),
          _buildSimulatorCard(theme),
        ],
        const SizedBox(height: 28),
        _buildSectionHeader(theme, 'About App'),
        const SizedBox(height: 12),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              if (!widget.themeController.isDeveloperMode) {
                setState(() {
                  _versionTapCount++;
                  if (_versionTapCount >= 5) {
                    widget.themeController.setDeveloperMode(true);
                    _versionTapCount = 0;
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Developer options enabled!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HL Control v0.1.0',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'An open-source custom controller app for Haylou headphones, serving as a lightweight replacement for Haylou Sound.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimulatorCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mock Headphone Connection'),
                Switch(
                  value: _isConnected,
                  onChanged: (val) {
                    widget.themeController.setMockConnected(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Simulate Battery Percentage'),
            Slider(
              value: _batteryPercent.toDouble(),
              min: 0,
              max: 100,
              divisions: 100,
              label: '$_batteryPercent%',
              onChanged: _isConnected
                  ? (val) {
                      widget.themeController.setMockBatteryPercent(val.toInt());
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _versionTapCount = 0;
                });
                widget.themeController.setDeveloperMode(false);
                widget.themeController.setMockConnected(false);
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Developer options disabled.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.developer_mode),
              label: const Text('Disable Developer Mode'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error.withOpacity(0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  // --- GENERAL WIDGETS ---

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildConnectionBanner(ThemeData theme) {
    Color statusColor = Colors.red;
    if (_isConnected) {
      statusColor = Colors.green;
    } else if (_isConnecting) {
      statusColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          if (_isConnecting)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected
                      ? 'Connected via RFCOMM'
                      : (_isConnecting ? 'Connecting...' : 'Disconnected'),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _isConnected
                      ? 'Device: $_deviceName'
                      : (widget.headphoneController.status.error != null
                          ? 'Error: ${widget.headphoneController.status.error}'
                          : 'No device connected'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: widget.headphoneController.status.error != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (!_isConnected && !_isConnecting)
            TextButton.icon(
              onPressed: _connectDevice,
              icon: const Icon(Icons.bluetooth),
              label: const Text('Connect'),
            )
          else if (_isConnected)
            TextButton.icon(
              onPressed: () => widget.headphoneController.disconnect(),
              icon: const Icon(Icons.bluetooth_disabled),
              label: const Text('Disconnect'),
              style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildAutoShutdownCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Shut down when idle',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  _shutdownOptions[_autoShutdownIndex],
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: _autoShutdownIndex.toDouble(),
              min: 0,
              max: 4,
              divisions: 4,
              onChanged: _isConnected
                  ? (val) {
                      widget.headphoneController.setAutoShutdown(val.toInt());
                    }
                  : null,
            ),
            // Mathematically aligned labels using Stack layout
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                const double trackPadding = 24.0; // Margin at each end of the Slider track
                final double trackWidth = width - 2 * trackPadding;

                return SizedBox(
                  height: 20,
                  child: Stack(
                    children: List.generate(_shutdownOptions.length, (index) {
                      final String labelText = _shutdownOptions[index].split(' ')[0];
                      final double tickX = trackPadding + index * (trackWidth / 4);

                      return Positioned(
                        left: tickX - 30, // Center the 60px wide label on the tick mark
                        width: 60,
                        child: Text(
                          labelText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesCard(ThemeData theme) {
    final status = widget.headphoneController.status;
    final List<Widget> children = [];

    void addDividerIfNotEmpty() {
      if (children.isNotEmpty) {
        children.add(const Divider(height: 1, indent: 16, endIndent: 16));
      }
    }

    // Game Mode
    if (!_isConnected || status.gameMode != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.sports_esports),
        title: const Text('Game Mode'),
        subtitle: const Text('Low-latency audio channel'),
        value: _gameMode,
        onChanged: _isConnected
            ? (val) {
                widget.headphoneController.setGameMode(val);
              }
            : null,
      ));
    }

    // Wind Noise Reduction
    if (!_isConnected || status.windNoise != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.air),
        title: const Text('Wind Noise Reduction'),
        subtitle: const Text('Filters out outdoor wind noise'),
        value: _windNoiseReduction,
        onChanged: _isConnected
            ? (val) {
                widget.headphoneController.setWindNoise(val);
              }
            : null,
      ));
    }

    // Multipoint Connection
    if (!_isConnected || status.multipoint != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.link),
        title: const Text('Multipoint Connection'),
        subtitle: const Text('Dual simultaneous device connections'),
        value: _multipoint,
        onChanged: _isConnected
            ? (val) {
                widget.headphoneController.setMultipoint(val);
              }
            : null,
      ));
    }

    // Smart Wear Detection
    if (!_isConnected || (!_isOverEar && status.wearDetection != null)) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.hearing),
        title: const Text('Smart Wear Detection'),
        subtitle: const Text('Auto-pause audio on removal'),
        value: _wearDetection,
        onChanged: _isConnected
            ? (val) {
                widget.headphoneController.setWearDetection(val);
              }
            : null,
      ));
    }

    // Spatial Audio
    if (!_isConnected || status.spatialAudioMode != 'Unknown') {
      addDividerIfNotEmpty();
      children.add(_buildSpatialAudioTile(theme));
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSpatialAudioTile(ThemeData theme) {
    final spatialModeOptions = ['Off', 'Static', 'Dynamic'];
    final spatialSceneOptions = ['Music', 'Sport', 'Movie'];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.spatial_audio, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Spatial Audio',
                      style: theme.textTheme.bodyLarge,
                    ),
                    Text(
                      'Surround sound mode selection',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
              segments: spatialModeOptions.map((mode) {
                return ButtonSegment<String>(
                  value: mode,
                  label: Text(mode),
                );
              }).toList(),
              selected: {_spatialAudioMode},
              onSelectionChanged: _isConnected
                  ? (newSelection) {
                      final mode = newSelection.first;
                      widget.headphoneController.setSpatialAudio(mode);
                    }
                  : null,
            ),
          ),
        ),
        if (_isConnected && _spatialAudioMode != 'Off') ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spatial Preset Scene',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: spatialSceneOptions.map((scene) {
                      return ButtonSegment<String>(
                        value: scene,
                        label: Text(scene),
                      );
                    }).toList(),
                    selected: {_spatialScene},
                    onSelectionChanged: (newSelection) {
                      final scene = newSelection.first;
                      final idx = ['Music', 'Sport', 'Movie'].indexOf(scene);
                      if (idx != -1) {
                        widget.headphoneController.setSpatialScene(idx);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// Custom painter to draw a smooth curve representing the 10-band EQ
class _EqCurvePainter extends CustomPainter {
  _EqCurvePainter({
    required this.values,
    required this.primaryColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color primaryColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final points = <Offset>[];

    final paintCurve = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [primaryColor.withOpacity(0.2), primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Draw horizontal mid gridline
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), gridPaint);

    // Draw horizontal top & bottom reference lines
    canvas.drawLine(Offset(0, h * 0.1), Offset(w, h * 0.1), gridPaint);
    canvas.drawLine(Offset(0, h * 0.9), Offset(w, h * 0.9), gridPaint);

    final step = w / (values.length - 1);
    for (int i = 0; i < values.length; i++) {
      // Maps slider value [-10, 10] to screen coordinates [h*0.9, h*0.1]
      final mappedY = (h / 2) - (values[i] / 20) * (h * 0.8);
      points.add(Offset(i * step, mappedY));

      // Draw grid vertical markers
      canvas.drawLine(Offset(i * step, 0), Offset(i * step, h), gridPaint);
    }

    // Generate smooth bezier curve path
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2;
      final controlY2 = p1.dy;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    // Draw filled shadow under the curve
    final fillPath = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();

    canvas.drawPath(fillPath, paintArea);
    canvas.drawPath(path, paintCurve);
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.gridColor != gridColor;
  }
}

class _SidebarItem extends StatefulWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.selectedIndex == widget.index;

    Color? backgroundColor;
    if (isSelected) {
      backgroundColor = theme.colorScheme.primaryContainer;
    } else if (_isHovered) {
      backgroundColor = theme.colorScheme.primary.withOpacity(0.08);
    } else {
      backgroundColor = Colors.transparent;
    }

    final foregroundColor = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final textColor = isSelected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            hoverColor: Colors.transparent,
            highlightColor: theme.colorScheme.primary.withOpacity(0.12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: backgroundColor,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    widget.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
