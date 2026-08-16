import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_version.dart';
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
  bool _isRailExpanded = true;
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

  // Optimistic UI state overrides and in-flight lock tracking
  final Map<String, dynamic> _optimisticOverrides = {};
  final Set<String> _inFlightControls = {};

  Future<void> _executeOptimisticAction<T>({
    required String controlKey,
    required String controlName,
    required T newValue,
    required T currentValue,
    required Future<void> Function() action,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (_inFlightControls.contains(controlKey)) return;

    setState(() {
      _inFlightControls.add(controlKey);
      _optimisticOverrides[controlKey] = newValue;
    });

    try {
      await action().timeout(timeout);
      // Brief debounce window to prevent rapid serial command flooding
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticOverrides.remove(controlKey);
        });

        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $controlName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _inFlightControls.remove(controlKey);
          _optimisticOverrides.remove(controlKey);
        });
      }
    }
  }

  String get _selectedAncMode {
    if (_optimisticOverrides.containsKey('anc_mode')) {
      return _optimisticOverrides['anc_mode'] as String;
    }
    final mode = widget.headphoneController.status.ancMode;
    if (mode.contains('Normal') || mode.contains('Off')) return 'Normal';
    if (mode.contains('Adaptive')) return 'Adaptive';
    if (mode.contains('ANC')) return 'ANC On';
    if (mode.contains('Transparency') || mode.contains('Aware')) return 'Transparency';
    return 'Normal';
  }

  int get _selectedAncIntensity {
    if (_optimisticOverrides.containsKey('anc_intensity')) {
      return _optimisticOverrides['anc_intensity'] as int;
    }
    return widget.headphoneController.status.ancIntensity;
  }

  String get _selectedEqPreset {
    if (_optimisticOverrides.containsKey('eq_preset')) {
      return _optimisticOverrides['eq_preset'] as String;
    }
    return widget.headphoneController.status.eqPreset;
  }

  bool get _gameMode {
    if (_optimisticOverrides.containsKey('game_mode')) {
      return _optimisticOverrides['game_mode'] as bool;
    }
    return widget.headphoneController.status.gameMode ?? false;
  }

  bool get _windNoiseReduction {
    if (_optimisticOverrides.containsKey('wind_noise')) {
      return _optimisticOverrides['wind_noise'] as bool;
    }
    return widget.headphoneController.status.windNoise ?? false;
  }

  bool get _multipoint {
    if (_optimisticOverrides.containsKey('multipoint')) {
      return _optimisticOverrides['multipoint'] as bool;
    }
    return widget.headphoneController.status.multipoint ?? false;
  }

  bool get _ldac {
    if (_optimisticOverrides.containsKey('ldac')) {
      return _optimisticOverrides['ldac'] as bool;
    }
    return widget.headphoneController.status.ldac ?? false;
  }

  String get _spatialAudioMode {
    if (_optimisticOverrides.containsKey('spatial_audio')) {
      return _optimisticOverrides['spatial_audio'] as String;
    }
    final mode = widget.headphoneController.status.spatialAudioMode;
    if (mode.contains('Dynamic')) return 'Dynamic';
    if (mode.contains('Static')) return 'Static';
    return 'Off';
  }

  String get _spatialScene {
    if (_optimisticOverrides.containsKey('spatial_scene')) {
      return _optimisticOverrides['spatial_scene'] as String;
    }
    final scene = widget.headphoneController.status.spatialScene;
    if (scene.contains('Sport')) return 'Sport';
    if (scene.contains('Movie')) return 'Movie';
    return 'Music';
  }

  bool get _wearDetection {
    if (_optimisticOverrides.containsKey('wear_detection')) {
      return _optimisticOverrides['wear_detection'] as bool;
    }
    return widget.headphoneController.status.wearDetection ?? false;
  }

  int get _autoShutdownIndex {
    if (_optimisticOverrides.containsKey('auto_shutdown')) {
      return _optimisticOverrides['auto_shutdown'] as int;
    }
    return widget.headphoneController.status.autoShutdownIndex ?? 4;
  }
  final List<String> _shutdownOptions = ['30 min', '1 hour', '3 hours', '5 hours', 'Never'];
  static const List<String> _shutdownTickLabels = ['30m', '1h', '3h', '5h', 'Never'];

  // Custom EQ states (10-band slider values from -12 to +12 dB)
  final List<double> _eqValues = List.filled(10, 0.0);
  final List<String> _eqBands = [
    '31Hz', '62Hz', '125Hz', '250Hz', '500Hz',
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];
  bool _showEqSliders = false;

  // Custom EQ presets list
  final List<Map<String, dynamic>> _customPresets = [
    {
      'name': 'Vocal booster',
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

  @override
  void initState() {
    super.initState();
    _loadCustomPresets();
  }

  Future<void> _loadCustomPresets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('custom_eq_presets');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        if (mounted) {
          setState(() {
            _customPresets.clear();
            for (final item in decoded) {
              if (item is Map) {
                _customPresets.add({
                  'name': item['name'] as String,
                  'values': (item['values'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
                });
              }
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _saveCustomPresetsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(_customPresets);
      await prefs.setString('custom_eq_presets', jsonStr);
    } catch (_) {}
  }

  void _showSavePresetDialog() {
    if (!_isConnected) return;
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Save custom preset'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Preset name (e.g. My bass)',
              border: OutlineInputBorder(),
            ),
            maxLength: 20,
          ),
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
                _saveCustomPresetsToPrefs();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeletePresetDialog(Map<String, dynamic> preset) {
    if (!_isConnected) return;
    final name = preset['name'] as String;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error, size: 28),
        title: const Text('Delete preset'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Text(
            'Are you sure you want to delete the custom preset "$name"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              setState(() {
                _customPresets.remove(preset);
              });
              _saveCustomPresetsToPrefs();
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  bool _isFindingDevice = false;

  void _showRenameDialog() {
    if (!_isConnected) return;
    final textController = TextEditingController(text: _deviceName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Rename device'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Enter new device name',
              border: OutlineInputBorder(),
            ),
            maxLength: 30,
          ),
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

  void _toggleFindDevice() async {
    if (!_isConnected) return;
    final newPlaying = !_isFindingDevice;
    setState(() {
      _isFindingDevice = newPlaying;
    });
    await widget.headphoneController.findDevice(newPlaying);
    if (mounted && newPlaying) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ringing headphones... Tap to stop.'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Stop',
            onPressed: () {
              _toggleFindDevice();
            },
          ),
        ),
      );
    }
  }

  void _showRebootWarningDialog({
    required String title,
    required String message,
    required String confirmLabel,
    IconData icon = Icons.restart_alt,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          scrollable: true,
          icon: Icon(icon, color: theme.colorScheme.primary, size: 28),
          title: Text(title, textAlign: TextAlign.center),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'The headphones will disconnect and restart (~3–5 sec) to apply changes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onConfirm();
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  void _handleAncModeChanged(String mode) {
    if (!_isConnected || _inFlightControls.contains('anc_mode')) return;
    int modeVal = 0;
    if (mode == 'ANC On') {
      modeVal = 1;
    } else if (mode == 'Transparency') {
      modeVal = 2;
    } else if (mode == 'Adaptive') {
      modeVal = 4;
    }
    _executeOptimisticAction<String>(
      controlKey: 'anc_mode',
      controlName: 'ANC mode',
      newValue: mode,
      currentValue: _selectedAncMode,
      action: () => widget.headphoneController.setAncMode(modeVal),
    );
  }

  void _handleAncIntensityChanged(int level) {
    if (!_isConnected || _inFlightControls.contains('anc_intensity')) return;
    _executeOptimisticAction<int>(
      controlKey: 'anc_intensity',
      controlName: 'ANC level',
      newValue: level,
      currentValue: _selectedAncIntensity,
      action: () => widget.headphoneController.setAncLevel(level),
    );
  }

  void _handleEqPresetChanged(String preset) {
    if (!_isConnected || _inFlightControls.contains('eq_preset')) return;
    final presets = ['Default', 'Subwoofer', 'Rock', 'Soft', 'Classical'];
    final idx = presets.indexOf(preset);
    if (idx != -1) {
      final vals = _presetValues[preset];
      if (vals != null) {
        setState(() {
          for (int i = 0; i < 10; i++) {
            _eqValues[i] = vals[i];
          }
        });
      }
      _executeOptimisticAction<String>(
        controlKey: 'eq_preset',
        controlName: 'EQ preset',
        newValue: preset,
        currentValue: _selectedEqPreset,
        action: () => widget.headphoneController.setEqPreset(idx),
      );
    }
  }

  void _handleAutoShutdownChanged(int choiceIdx) {
    if (!_isConnected || _inFlightControls.contains('auto_shutdown')) return;
    _executeOptimisticAction<int>(
      controlKey: 'auto_shutdown',
      controlName: 'auto shutdown timer',
      newValue: choiceIdx,
      currentValue: _autoShutdownIndex,
      action: () => widget.headphoneController.setAutoShutdown(choiceIdx),
    );
  }

  void _handleWindNoiseChanged(bool val) {
    if (!_isConnected || _inFlightControls.contains('wind_noise')) return;
    _executeOptimisticAction<bool>(
      controlKey: 'wind_noise',
      controlName: 'wind noise reduction',
      newValue: val,
      currentValue: _windNoiseReduction,
      action: () => widget.headphoneController.setWindNoise(val),
    );
  }

  void _handleWearDetectionChanged(bool val) {
    if (!_isConnected || _inFlightControls.contains('wear_detection')) return;
    _executeOptimisticAction<bool>(
      controlKey: 'wear_detection',
      controlName: 'smart wear detection',
      newValue: val,
      currentValue: _wearDetection,
      action: () => widget.headphoneController.setWearDetection(val),
    );
  }

  void _handleSpatialSceneChanged(String scene) {
    if (!_isConnected || _inFlightControls.contains('spatial_scene')) return;
    final idx = ['Music', 'Sport', 'Movie'].indexOf(scene);
    if (idx != -1) {
      _executeOptimisticAction<String>(
        controlKey: 'spatial_scene',
        controlName: 'spatial scene',
        newValue: scene,
        currentValue: _spatialScene,
        action: () => widget.headphoneController.setSpatialScene(idx),
      );
    }
  }

  void _handleLdacChanged(bool val) {
    if (!_isConnected || _inFlightControls.contains('ldac')) return;
    if (val) {
      final List<String> conflicts = [];
      if (_multipoint) conflicts.add('multipoint connection');
      if (_gameMode) conflicts.add('game mode');
      if (_spatialAudioMode != 'Off') conflicts.add('spatial audio');

      String explanation = 'Enabling LDAC high-resolution audio provides maximum audio fidelity (up to 990 kbps).';
      if (conflicts.isNotEmpty) {
        explanation += '\n\nNote: LDAC cannot run simultaneously with ${conflicts.join(', ')}. Enabling LDAC will turn off ${conflicts.join(' and ')}.';
      }

      _showRebootWarningDialog(
        title: 'Enable LDAC audio codec?',
        message: explanation,
        confirmLabel: 'Enable & restart',
        icon: Icons.high_quality,
        onConfirm: () {
          _executeOptimisticAction<bool>(
            controlKey: 'ldac',
            controlName: 'LDAC audio codec',
            newValue: true,
            currentValue: _ldac,
            action: () => widget.headphoneController.setLdac(true),
          );
        },
      );
    } else {
      _showRebootWarningDialog(
        title: 'Disable LDAC audio codec?',
        message: 'Disabling LDAC will switch streaming back to standard audio codecs (AAC/SBC).',
        confirmLabel: 'Disable & restart',
        icon: Icons.high_quality,
        onConfirm: () {
          _executeOptimisticAction<bool>(
            controlKey: 'ldac',
            controlName: 'LDAC audio codec',
            newValue: false,
            currentValue: _ldac,
            action: () => widget.headphoneController.setLdac(false),
          );
        },
      );
    }
  }

  void _handleMultipointChanged(bool val) {
    if (!_isConnected || _inFlightControls.contains('multipoint')) return;
    if (val && _ldac) {
      _showRebootWarningDialog(
        title: 'Enable multipoint connection?',
        message: 'Multipoint (dual-device connection) cannot be used simultaneously with LDAC high-resolution audio.\n\nEnabling multipoint will disable LDAC.',
        confirmLabel: 'Turn off LDAC & enable',
        icon: Icons.link,
        onConfirm: () {
          _executeOptimisticAction<bool>(
            controlKey: 'multipoint',
            controlName: 'multipoint connection',
            newValue: true,
            currentValue: _multipoint,
            action: () => widget.headphoneController.setMultipoint(true),
          );
        },
      );
    } else {
      _executeOptimisticAction<bool>(
        controlKey: 'multipoint',
        controlName: 'multipoint connection',
        newValue: val,
        currentValue: _multipoint,
        action: () => widget.headphoneController.setMultipoint(val),
      );
    }
  }

  void _handleGameModeChanged(bool val) {
    if (!_isConnected || _inFlightControls.contains('game_mode')) return;
    if (val && _ldac) {
      _showRebootWarningDialog(
        title: 'Enable game mode?',
        message: 'Low-latency game mode cannot be used simultaneously with LDAC high-resolution audio.\n\nEnabling game mode will disable LDAC.',
        confirmLabel: 'Turn off LDAC & enable',
        icon: Icons.sports_esports,
        onConfirm: () {
          _executeOptimisticAction<bool>(
            controlKey: 'game_mode',
            controlName: 'game mode',
            newValue: true,
            currentValue: _gameMode,
            action: () => widget.headphoneController.setGameMode(true),
          );
        },
      );
    } else {
      _executeOptimisticAction<bool>(
        controlKey: 'game_mode',
        controlName: 'game mode',
        newValue: val,
        currentValue: _gameMode,
        action: () => widget.headphoneController.setGameMode(val),
      );
    }
  }

  void _handleSpatialAudioChanged(String mode) {
    if (!_isConnected || _inFlightControls.contains('spatial_audio')) return;
    if (mode != 'Off' && _ldac) {
      _showRebootWarningDialog(
        title: 'Enable spatial audio ($mode)?',
        message: 'Spatial audio DSP processing cannot be used simultaneously with LDAC high-resolution audio.\n\nEnabling spatial audio will disable LDAC.',
        confirmLabel: 'Turn off LDAC & enable',
        icon: Icons.spatial_audio,
        onConfirm: () {
          _executeOptimisticAction<String>(
            controlKey: 'spatial_audio',
            controlName: 'spatial audio',
            newValue: mode,
            currentValue: _spatialAudioMode,
            action: () => widget.headphoneController.setSpatialAudio(mode),
          );
        },
      );
    } else {
      _executeOptimisticAction<String>(
        controlKey: 'spatial_audio',
        controlName: 'spatial audio',
        newValue: mode,
        currentValue: _spatialAudioMode,
        action: () => widget.headphoneController.setSpatialAudio(mode),
      );
    }
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
              backgroundColor: theme.colorScheme.surface,
              body: isWide
                  ? Row(
                      children: [
                        _buildSidebar(theme),
                        VerticalDivider(
                          thickness: 1,
                          width: 1,
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                        Expanded(
                          child: Container(
                            color: theme.colorScheme.surface,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _buildCurrentTabContent(theme, isWide: true),
                            ),
                          ),
                        ),
                      ],
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildCurrentTabContent(theme, isWide: false),
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

  void _connectDevice() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _DeviceSelectionDialog(
        headphoneController: widget.headphoneController,
      ),
    );
  }

  Widget _buildSidebar(ThemeData theme) {
    final sidebarWidth = _isRailExpanded ? 240.0 : 76.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      clipBehavior: Clip.hardEdge,
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          maxWidth: 240.0,
          child: SizedBox(
            width: _isRailExpanded ? 240.0 : 76.0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
              child: SizedBox(
                height: 48,
                child: _isRailExpanded
                    ? Row(
                        children: [
                          Container(
                            width: 56,
                            height: 48,
                            alignment: Alignment.center,
                            child: IconButton(
                              icon: const Icon(Icons.menu_open_rounded),
                              tooltip: 'Collapse sidebar',
                              onPressed: () => setState(() => _isRailExpanded = false),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'HL Control',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Container(
                          width: 56,
                          height: 48,
                          alignment: Alignment.center,
                          child: IconButton(
                            icon: const Icon(Icons.menu_rounded),
                            tooltip: 'Expand sidebar',
                            onPressed: () => setState(() => _isRailExpanded = true),
                          ),
                        ),
                      ),
              ),
            ),
            _SidebarItem(
              icon: _currentTab == 0 ? Icons.tune_rounded : Icons.tune_outlined,
              label: 'Control',
              index: 0,
              selectedIndex: _currentTab,
              isExpanded: _isRailExpanded,
              onTap: () => setState(() => _currentTab = 0),
            ),
            _SidebarItem(
              icon: _currentTab == 1 ? Icons.equalizer_rounded : Icons.equalizer_outlined,
              label: 'Equalizer',
              index: 1,
              selectedIndex: _currentTab,
              isExpanded: _isRailExpanded,
              onTap: () => setState(() => _currentTab = 1),
            ),
            _SidebarItem(
              icon: _currentTab == 2 ? Icons.settings_rounded : Icons.settings_outlined,
              label: 'Settings',
              index: 2,
              selectedIndex: _currentTab,
              isExpanded: _isRailExpanded,
              onTap: () => setState(() => _currentTab = 2),
            ),
            const Spacer(),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: (_isConnected && _currentTab != 0)
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _isRailExpanded
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _deviceName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        if (_batteryPercent > 0)
                                          Text(
                                            '$_batteryPercent% battery',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Center(
                              child: Tooltip(
                                message: '$_deviceName (${_batteryPercent > 0 ? '$_batteryPercent%' : 'Connected'})',
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.headphones_rounded,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildCurrentTabContent(ThemeData theme, {required bool isWide}) {
    switch (_currentTab) {
      case 0:
        return _buildControlTab(theme, isWide: isWide);
      case 1:
        return _buildEqualizerTab(theme, isWide: isWide);
      case 2:
        return _buildSettingsTab(theme, isWide: isWide);
      default:
        return _buildControlTab(theme, isWide: isWide);
    }
  }

  Widget _buildCenteredScrollable({
    required Key key,
    required String title,
    List<Widget>? actions,
    required List<Widget> children,
    required EdgeInsetsGeometry padding,
    required bool isWide,
    double maxWidth = 580,
  }) {
    final effectivePadding = isWide
        ? const EdgeInsets.fromLTRB(24, 40, 24, 36)
        : padding;

    return CustomScrollView(
      key: key,
      slivers: [
        if (!isWide)
          SliverAppBar.large(
            title: Text(title),
            pinned: true,
            scrolledUnderElevation: 3.0,
            actions: actions,
          ),
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: effectivePadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- CONTROL TAB ---
  Widget _buildControlTab(ThemeData theme, {required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final is2Pane = constraints.maxWidth >= 720;
        final status = widget.headphoneController.status;
        final isWearSupported = !_isOverEar && status.wearDetection != null;
        final hasAudioFeatures = !_isConnected ||
            status.gameMode != null ||
            status.windNoise != null ||
            status.multipoint != null ||
            status.ldac != null ||
            isWearSupported ||
            status.spatialAudioMode != 'Unknown';

        final actions = [
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_searching),
              tooltip: 'Connect device',
              onPressed: _connectDevice,
            ),
        ];

        if (is2Pane) {
          return _buildCenteredScrollable(
            key: const ValueKey(0),
            title: 'HL Control',
            isWide: isWide,
            maxWidth: 1000,
            actions: actions,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // Top Hero (Full-width / Centered)
              Center(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      _buildHeadphonesImage(theme),
                      const SizedBox(height: 20),
                      Text(
                        _isConnected ? _deviceName : 'Disconnected',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildStatusCluster(theme),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 2 Equal Side-by-Side Cards Below Hero
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isConnected ? 1.0 : 0.45,
                child: IgnorePointer(
                  ignoring: !_isConnected,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Card: Noise Control
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(theme, 'Noise control'),
                            const SizedBox(height: 12),
                            _buildNoiseControlCard(theme),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Card: Audio Features & Secondary Controls
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_isConnected && status.autoShutdownIndex != null && !_isOverEar) ...[
                              _buildSectionHeader(theme, 'Auto shutdown'),
                              const SizedBox(height: 12),
                              _buildAutoShutdownCard(theme),
                              const SizedBox(height: 24),
                            ],
                            if (hasAudioFeatures) ...[
                              _buildSectionHeader(theme, 'Audio features'),
                              const SizedBox(height: 12),
                              _buildFeaturesCard(theme),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // 1-Column Layout (< 720dp)
        return _buildCenteredScrollable(
          key: const ValueKey(0),
          title: 'HL Control',
          isWide: isWide,
          maxWidth: 580,
          actions: actions,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            // Premium Product Image & Status Cluster
            Center(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeInOutCubic,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    _buildHeadphonesImage(theme),
                    const SizedBox(height: 24),
                    Text(
                      _isConnected ? _deviceName : 'Disconnected',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStatusCluster(theme),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Interactive Controls Column (Dimmed & Locked when Disconnected)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _isConnected ? 1.0 : 0.45,
              child: IgnorePointer(
                ignoring: !_isConnected,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Noise Control Section
                    _buildSectionHeader(theme, 'Noise control'),
                    const SizedBox(height: 12),
                    _buildNoiseControlCard(theme),
                    const SizedBox(height: 28),

                    // Auto Shutdown Section (only rendered when connected and confirmed)
                    if (_isConnected && status.autoShutdownIndex != null && !_isOverEar) ...[
                      _buildSectionHeader(theme, 'Auto shutdown'),
                      const SizedBox(height: 12),
                      _buildAutoShutdownCard(theme),
                      const SizedBox(height: 28),
                    ],

                    // Audio Features Section
                    if (hasAudioFeatures) ...[
                      _buildSectionHeader(theme, 'Audio features'),
                      const SizedBox(height: 12),
                      _buildFeaturesCard(theme),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getDeviceImageAsset(String deviceName) {
    final name = deviceName.toLowerCase();
    if (name.contains('s40')) {
      if (name.contains('white') || name.contains('beige') || name.contains('silver')) {
        return 'assets/images/devices/tws_img_earbud_s40_white.webp';
      }
      return 'assets/images/devices/tws_img_earbud_s40_black.webp';
    }
    if (name.contains('s35')) {
      return 'assets/images/devices/tws_img_earbud_s35_black.webp';
    }
    if (name.contains('s30')) {
      return 'assets/images/devices/tws_img_earbud_s30_black.webp';
    }
    if (name.contains('bc04') || name.contains('purfree')) {
      return 'assets/images/devices/tws_img_earbud_bc04_black.webp';
    }
    if (name.contains('x1') || name.contains('x1l') || name.contains('t003')) {
      return 'assets/images/devices/tws_img_earbud_t003_black.webp';
    }
    if (name.contains('x2') || name.contains('w1') || name.contains('t007')) {
      return 'assets/images/devices/tws_img_earbud_t007_blue.webp';
    }
    if (name.contains('t013')) {
      return 'assets/images/devices/tws_img_earbud_t013.webp';
    }
    if (name.contains('t016') || name.contains('mori')) {
      return 'assets/images/devices/tws_img_earbud_t016.webp';
    }
    if (name.contains('t021') || name.contains('ht06') || name.contains('ht03') || name.contains('flowbuds')) {
      return 'assets/images/devices/tws_img_earbud_t021_black.webp';
    }
    if (name.contains('ht02')) {
      return 'assets/images/devices/tws_img_earbud_ht02_black.png';
    }
    if (name.contains('ow02') || name.contains('earhook')) {
      return 'assets/images/devices/tws_img_earbud_ow02.webp';
    }
    if (name.contains('ow03') || name.contains('airfree')) {
      return 'assets/images/devices/tws_img_earbud_ow03.webp';
    }
    return 'assets/images/devices/tws_img_earbud_s40_black.webp';
  }

  Widget _buildHeadphonesImage(ThemeData theme) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
              child: child,
            ),
          );
        },
        child: !_isConnected
            ? Container(
                key: const ValueKey('disconnected_hero_avatar'),
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.6),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.headphones_rounded,
                    size: 68,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                  ),
                ),
              )
            : Container(
                key: ValueKey('connected_hero_$_deviceName'),
                width: 190,
                height: 190,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    _getDeviceImageAsset(_deviceName),
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        Icons.headphones_rounded,
                        size: 76,
                        color: theme.colorScheme.primary,
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCluster(ThemeData theme) {
    if (!_isConnected) {
      if (_isConnecting) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(
                'Connecting...',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      return FilledButton.tonalIcon(
        onPressed: _connectDevice,
        icon: const Icon(Icons.bluetooth_searching, size: 18),
        label: const Text('Connect device'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      );
    }

    final isLow = _batteryPercent <= 20;

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        // Badge 1: Battery
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isLow
                ? theme.colorScheme.errorContainer.withOpacity(0.5)
                : theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLow
                  ? theme.colorScheme.error.withOpacity(0.3)
                  : theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLow ? Icons.battery_alert_rounded : Icons.battery_full_rounded,
                size: 18,
                color: isLow ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                '$_batteryPercent%',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isLow ? theme.colorScheme.onErrorContainer : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Badge 2: Protocol status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.bluetooth_connected_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'RFCOMM',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Disconnect Action
        IconButton(
          onPressed: () {
            widget.headphoneController.disconnect();
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Disconnected from $_deviceName'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.link_off_rounded, size: 20),
          tooltip: 'Disconnect headset',
          visualDensity: VisualDensity.compact,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildNoiseControlCard(ThemeData theme) {
    final showAncLevel = _isConnected && (_selectedAncMode == 'ANC On' || _selectedAncMode == 'Adaptive');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AncSelector(
              selectedMode: _selectedAncMode,
              enabled: _isConnected,
              onChanged: _handleAncModeChanged,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: showAncLevel
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'ANC level',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              _selectedAncIntensity == 2
                                  ? 'Low'
                                  : (_selectedAncIntensity == 1 ? 'Medium' : 'High'),
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
                            onSelectionChanged: _isConnected
                                ? (newSelection) {
                                    _handleAncIntensityChanged(newSelection.first);
                                  }
                                : null,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // --- EQUALIZER TAB ---
  Widget _buildEqualizerTab(ThemeData theme, {required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final is2Pane = constraints.maxWidth >= 720;

        if (is2Pane) {
          return _buildCenteredScrollable(
            key: const ValueKey(1),
            title: 'Equalizer',
            isWide: isWide,
            maxWidth: 1040,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // Top Presets Bar (Horizontally centered)
              Center(
                child: Column(
                  children: [
                    _buildSectionHeader(theme, 'Select preset'),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _isConnected ? 1.0 : 0.4,
                      child: EqSelector(
                        selectedPreset: _selectedEqPreset,
                        enabled: _isConnected,
                        onChanged: _handleEqPresetChanged,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 2-Pane Content Split (Left: Graphic EQ, Right: Custom Presets)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _isConnected ? 1.0 : 0.45,
                child: IgnorePointer(
                  ignoring: !_isConnected,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left (Wider Pane, flex: 7): 10-band Graphic EQ with curve and expanded sliders
                      Expanded(
                        flex: 7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(theme, 'Custom graphic EQ'),
                            const SizedBox(height: 12),
                            _buildCustomEqCard(theme, isDesktop: true),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right (Sidebar Pane, flex: 4): Dedicated Custom Presets card
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSectionHeader(theme, 'User presets'),
                            const SizedBox(height: 12),
                            _buildCustomPresetsCard(theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // 1-Column Layout (< 720dp)
        return _buildCenteredScrollable(
          key: const ValueKey(1),
          title: 'Equalizer',
          isWide: isWide,
          maxWidth: 580,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _buildSectionHeader(theme, 'Select preset'),
            const SizedBox(height: 12),
            Opacity(
              opacity: _isConnected ? 1.0 : 0.4,
              child: EqSelector(
                selectedPreset: _selectedEqPreset,
                enabled: _isConnected,
                onChanged: _handleEqPresetChanged,
              ),
            ),
            const SizedBox(height: 28),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _isConnected ? 1.0 : 0.45,
              child: IgnorePointer(
                ignoring: !_isConnected,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(theme, 'Custom graphic EQ'),
                    const SizedBox(height: 12),
                    _buildCustomEqCard(theme, isDesktop: false),
                    const SizedBox(height: 28),
                    _buildSectionHeader(theme, 'My custom presets'),
                    const SizedBox(height: 12),
                    _buildCustomPresetsCard(theme),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCustomPresetsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My custom presets',
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_customPresets.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_customPresets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.tune_outlined,
                        size: 32,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No custom presets saved yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _customPresets.map((preset) {
                  final name = preset['name'] as String;
                  final values = preset['values'] as List<double>;

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
                    showCheckmark: false,
                    onSelected: _isConnected
                        ? (selected) {
                            setState(() {
                              for (int i = 0; i < 10; i++) {
                                _eqValues[i] = values[i];
                              }
                            });
                            widget.headphoneController.setCustomEq(_eqValues);
                          }
                        : null,
                    onDeleted: _isConnected
                        ? () => _showDeletePresetDialog(preset)
                        : null,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    tooltip: 'Select $name',
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _isConnected ? _showSavePresetDialog : null,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Save current preset'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomEqCard(ThemeData theme, {bool isDesktop = false}) {
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
                    '10-band graphic EQ',
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
                      tooltip: 'Save custom preset',
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
                      tooltip: 'Reset EQ sliders',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Premium EQ curve visualizer
            Container(
              height: 110,
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
            if (isDesktop) ...[
              const SizedBox(height: 20),
              _buildEqSlidersRow(theme),
            ] else ...[
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showEqSliders
                    ? Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildEqSlidersRow(theme),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: 4),
              Center(
                child: IconButton(
                  onPressed: _isConnected
                      ? () {
                          setState(() {
                            _showEqSliders = !_showEqSliders;
                          });
                        }
                      : null,
                  icon: Icon(
                    _showEqSliders ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 26,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: _showEqSliders ? 'Collapse sliders' : 'Expand sliders',
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEqSlidersRow(ThemeData theme) {
    return SizedBox(
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
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withOpacity(0.12),
                        ),
                        child: Slider(
                          value: _eqValues[index],
                          min: -12,
                          max: 12,
                          divisions: 24,
                          onChanged: _isConnected
                              ? (val) {
                                  setState(() {
                                    _eqValues[index] = val;
                                  });
                                }
                              : null,
                          onChangeEnd: _isConnected
                              ? (val) {
                                  widget.headphoneController.setCustomEq(_eqValues);
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
                      color: _eqValues[index] != 0.0 ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eqBands[index],
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showRepoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Repository'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Source code:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              SelectableText(
                'https://github.com/Flopster101/HLControl',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // --- SETTINGS TAB ---
  Widget _buildSettingsTab(ThemeData theme, {required bool isWide}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final is2Pane = constraints.maxWidth >= 720;

        if (is2Pane) {
          return _buildCenteredScrollable(
            key: const ValueKey(2),
            title: 'Settings',
            isWide: isWide,
            maxWidth: 1040,
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Device settings
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(theme, 'Device settings'),
                        const SizedBox(height: 12),
                        _buildDeviceSettingsCard(theme),
                        if (_isConnected) ...[
                          const SizedBox(height: 20),
                          FilledButton.tonalIcon(
                            onPressed: () => _showRebootWarningDialog(
                              title: 'Disconnect headset',
                              message: 'Are you sure you want to disconnect from $_deviceName?',
                              confirmLabel: 'Disconnect',
                              onConfirm: () {
                                widget.headphoneController.disconnect();
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Disconnected from $_deviceName'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('Disconnect headset'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Appearance and About stacked
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader(theme, 'Appearance'),
                        const SizedBox(height: 12),
                        _buildAppearanceCard(theme),
                        if (widget.themeController.isDeveloperMode) ...[
                          const SizedBox(height: 24),
                          _buildSectionHeader(theme, 'Developer settings'),
                          const SizedBox(height: 12),
                          _buildSimulatorCard(theme),
                        ],
                        const SizedBox(height: 24),
                        _buildSectionHeader(theme, 'About'),
                        const SizedBox(height: 12),
                        _buildAboutCard(theme),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        // 1-Column Layout (< 720dp)
        return _buildCenteredScrollable(
          key: const ValueKey(2),
          title: 'Settings',
          isWide: isWide,
          maxWidth: 580,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          children: [
            _buildSectionHeader(theme, 'Device settings'),
            const SizedBox(height: 12),
            _buildDeviceSettingsCard(theme),
            const SizedBox(height: 28),
            _buildSectionHeader(theme, 'Appearance'),
            const SizedBox(height: 12),
            _buildAppearanceCard(theme),
            if (widget.themeController.isDeveloperMode) ...[
              const SizedBox(height: 28),
              _buildSectionHeader(theme, 'Developer settings'),
              const SizedBox(height: 12),
              _buildSimulatorCard(theme),
            ],
            const SizedBox(height: 28),
            _buildSectionHeader(theme, 'About'),
            const SizedBox(height: 12),
            _buildAboutCard(theme),
            if (_isConnected) ...[
              const SizedBox(height: 32),
              FilledButton.tonalIcon(
                onPressed: () => _showRebootWarningDialog(
                  title: 'Disconnect headset',
                  message: 'Are you sure you want to disconnect from $_deviceName?',
                  confirmLabel: 'Disconnect',
                  onConfirm: () {
                    widget.headphoneController.disconnect();
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Disconnected from $_deviceName'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect headset'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDeviceSettingsCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Rename headset'),
            subtitle: Text(_isConnected ? _deviceName : 'Disconnected'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isConnected ? _showRenameDialog : null,
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
            indent: 16,
            endIndent: 16,
          ),
          ListTile(
            leading: Icon(_isFindingDevice ? Icons.volume_up : Icons.search),
            title: const Text('Find my headset'),
            subtitle: Text(
              _isFindingDevice
                  ? 'Ringing active — tap to stop'
                  : 'Play sound tone to locate headphones',
            ),
            trailing: _isFindingDevice
                ? FilledButton.tonal(
                    onPressed: _isConnected ? _toggleFindDevice : null,
                    child: const Text('Stop'),
                  )
                : OutlinedButton(
                    onPressed: _isConnected ? _toggleFindDevice : null,
                    child: const Text('Ring'),
                  ),
            onTap: _isConnected ? _toggleFindDevice : null,
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
            indent: 16,
            endIndent: 16,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Connection mode'),
            subtitle: Text(_isConnected ? 'Bluetooth Classic RFCOMM (Port 10)' : 'Not connected'),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
            indent: 16,
            endIndent: 16,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.autorenew),
            title: const Text('Auto-connect to last headphones'),
            subtitle: Text(
              widget.themeController.lastConnectedName.isNotEmpty
                  ? 'Automatically link to: ${widget.themeController.lastConnectedName}'
                  : 'Automatically connect on startup',
            ),
            value: widget.themeController.autoConnectLastHeadphones,
            onChanged: (val) {
              widget.themeController.setAutoConnectLastHeadphones(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceCard(ThemeData theme) {
    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Theme mode',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                        label: Text('System'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Light'),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {widget.themeController.themeMode},
                    onSelectionChanged: (modes) {
                      widget.themeController.setThemeMode(modes.first);
                    },
                  ),
                ),
              ],
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withOpacity(0.35),
              indent: 16,
              endIndent: 16,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.color_lens_outlined),
              title: const Text('Dynamic colors'),
              subtitle: const Text('Use wallpaper-based Material You colors (Android 12+)'),
              value: widget.themeController.useDynamicColor,
              onChanged: (val) {
                widget.themeController.setUseDynamicColor(val);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutCard(ThemeData theme) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
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
                        content: Text('Developer settings unlocked! 🎉'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.headphones,
                      color: theme.colorScheme.onPrimaryContainer,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HL Control',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppVersion.displayVersion,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'An open-source alternative to the official Haylou app for Bluetooth headsets.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withOpacity(0.35),
            indent: 16,
            endIndent: 16,
          ),
          ListTile(
            leading: const Icon(Icons.code_rounded),
            title: const Text('Repository'),
            subtitle: const Text('GitHub source code and issue tracker'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _showRepoDialog,
          ),
        ],
      ),
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
                const Text('Mock headphone connection'),
                Switch(
                  value: _isConnected,
                  onChanged: (val) {
                    widget.themeController.setMockConnected(val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Simulate battery percentage'),
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
              label: const Text('Disable developer mode'),
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

  // --- GENERAL WIDGETS ---

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleSmall,
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
                  ? (val) => _handleAutoShutdownChanged(val.toInt())
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
                    children: List.generate(_shutdownTickLabels.length, (index) {
                      final String labelText = _shutdownTickLabels[index];
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
        title: const Text('Game mode'),
        subtitle: const Text('Low-latency audio channel'),
        value: _gameMode,
        onChanged: _isConnected ? _handleGameModeChanged : null,
      ));
    }

    // Wind Noise Reduction
    if (!_isConnected || status.windNoise != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.air),
        title: const Text('Wind noise reduction'),
        subtitle: const Text('Filters out outdoor wind noise'),
        value: _windNoiseReduction,
        onChanged: _isConnected ? _handleWindNoiseChanged : null,
      ));
    }

    // Multipoint Connection
    if (!_isConnected || status.multipoint != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.link),
        title: const Text('Multipoint connection'),
        subtitle: const Text('Dual simultaneous device connections'),
        value: _multipoint,
        onChanged: _isConnected ? _handleMultipointChanged : null,
      ));
    }

    // LDAC High-Resolution Audio
    if (!_isConnected || status.ldac != null) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.high_quality),
        title: const Text('LDAC high-resolution audio'),
        subtitle: const Text('High-definition Bluetooth audio codec'),
        value: _ldac,
        onChanged: _isConnected ? _handleLdacChanged : null,
      ));
    }

    // Smart Wear Detection
    if (!_isConnected || (!_isOverEar && status.wearDetection != null)) {
      addDividerIfNotEmpty();
      children.add(SwitchListTile(
        secondary: const Icon(Icons.hearing),
        title: const Text('Smart wear detection'),
        subtitle: const Text('Auto-pause audio on removal'),
        value: _wearDetection,
        onChanged: _isConnected ? _handleWearDetectionChanged : null,
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
                      'Spatial audio',
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
                      _handleSpatialAudioChanged(newSelection.first);
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
                  'Spatial preset scene',
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
                    onSelectionChanged: _isConnected
                        ? (newSelection) {
                            _handleSpatialSceneChanged(newSelection.first);
                          }
                        : null,
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
      // Maps slider value [-12, 12] to screen coordinates [h*0.9, h*0.1]
      final mappedY = (h / 2) - (values[i] / 24) * (h * 0.8);
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
    required this.isExpanded,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int index;
  final int selectedIndex;
  final bool isExpanded;
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
      backgroundColor = theme.colorScheme.secondaryContainer;
    } else if (_isHovered) {
      backgroundColor = theme.colorScheme.onSurface.withOpacity(0.08);
    } else {
      backgroundColor = Colors.transparent;
    }

    final foregroundColor = isSelected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    final textColor = isSelected
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurface;

    if (widget.isExpanded) {
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
              borderRadius: BorderRadius.circular(28),
              hoverColor: Colors.transparent,
              highlightColor: theme.colorScheme.secondaryContainer.withOpacity(0.24),
              splashColor: theme.colorScheme.onSecondaryContainer.withOpacity(0.12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: backgroundColor,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Icon(
                          widget.icon,
                          color: foregroundColor,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Tooltip(
            message: widget.label,
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
                  highlightColor: theme.colorScheme.secondaryContainer.withOpacity(0.24),
                  splashColor: theme.colorScheme.onSecondaryContainer.withOpacity(0.12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 56,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: backgroundColor,
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        color: foregroundColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}

class _DeviceSelectionDialog extends StatefulWidget {
  final HeadphoneController headphoneController;

  const _DeviceSelectionDialog({required this.headphoneController});

  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  bool _isLoading = false;
  List<BluetoothDevice> _devices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First get immediately cached/paired devices so the user doesn't see an empty screen
      final cached = await widget.headphoneController.getPairedDevices();
      if (mounted) {
        setState(() {
          _devices = cached;
        });
      }

      // Then run a full bluetooth discovery scan
      final fresh = await widget.headphoneController.scanDevices();
      if (mounted) {
        setState(() {
          _devices = fresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  bool _isRecommended(String name) {
    final n = name.toLowerCase();
    return n.contains('haylou') ||
        n.contains('s40') ||
        n.contains('s35') ||
        n.contains('s30') ||
        n.contains('purfree') ||
        n.contains('bc04') ||
        n.contains('ow02') ||
        n.contains('x1') ||
        n.contains('t021');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter devices
    final recommended = _devices.where((d) => _isRecommended(d.name)).toList();
    final other = _devices.where((d) => !_isRecommended(d.name)).toList();

    return AlertDialog(
      title: Text(
        'Connect headset',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
      content: SizedBox(
        width: 400,
        height: 350,
        child: _devices.isEmpty && _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Scanning for devices...'),
                  ],
                ),
              )
            : _devices.isEmpty && _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error: $_error',
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        if (recommended.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Text(
                              'Recommended',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...recommended.map((dev) => ListTile(
                            leading: Icon(
                              Icons.headphones,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              widget.headphoneController.themeController.getDeviceName(dev.macAddress, dev.name),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(dev.macAddress),
                            onTap: () {
                              Navigator.pop(context);
                              widget.headphoneController.connect(dev.macAddress);
                            },
                          )),
                          const Divider(),
                        ],
                        if (other.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Text(
                              'Other devices',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...other.map((dev) => ListTile(
                            leading: const Icon(Icons.bluetooth),
                            title: Text(widget.headphoneController.themeController.getDeviceName(dev.macAddress, dev.name)),
                            subtitle: Text(dev.macAddress),
                            onTap: () {
                              Navigator.pop(context);
                              widget.headphoneController.connect(dev.macAddress);
                            },
                          )),
                        ],
                        if (_devices.isEmpty && !_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: Text('No devices found nearby.'),
                            ),
                          ),
                      ],
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton.icon(
          onPressed: _isLoading ? null : _startScan,
          icon: _isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}
