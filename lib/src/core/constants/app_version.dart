import 'dart:io';
import 'package:flutter/foundation.dart';

class AppVersion {
  static const String version = String.fromEnvironment('APP_VERSION', defaultValue: 'Unknown');

  static String _cachedDisplayVersion = '';

  static String get displayVersion {
    if (_cachedDisplayVersion.isNotEmpty) return _cachedDisplayVersion;

    String ver = version;
    String hash = const String.fromEnvironment('GIT_HASH', defaultValue: '');
    String branch = const String.fromEnvironment('GIT_BRANCH', defaultValue: '');

    if (!kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows)) {
      try {
        // Read pubspec.yaml version if available in local development
        if (ver == 'Unknown') {
          final pubspecFile = File('pubspec.yaml');
          if (pubspecFile.existsSync()) {
            final lines = pubspecFile.readAsLinesSync();
            for (final line in lines) {
              if (line.startsWith('version:')) {
                final raw = line.replaceFirst('version:', '').trim();
                ver = raw.split('+').first;
                break;
              }
            }
          }
        }

        // Discover git commit hash
        if (hash.isEmpty) {
          final hashResult = Process.runSync('git', ['rev-parse', '--short', 'HEAD']);
          if (hashResult.exitCode == 0) {
            final output = (hashResult.stdout as String).trim();
            if (output.isNotEmpty) {
              hash = output;
            }
          }
        }

        // Discover git branch name
        if (branch.isEmpty) {
          final branchResult = Process.runSync('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
          if (branchResult.exitCode == 0) {
            final output = (branchResult.stdout as String).trim();
            if (output.isNotEmpty) {
              branch = output;
            }
          }
        }
      } catch (_) {}
    }

    final String prefix = ver != 'Unknown' ? 'v$ver' : 'Unknown';

    if (hash.isNotEmpty && branch.isNotEmpty) {
      _cachedDisplayVersion = '$prefix-$hash-$branch';
    } else if (hash.isNotEmpty) {
      _cachedDisplayVersion = '$prefix-$hash';
    } else {
      _cachedDisplayVersion = prefix;
    }

    return _cachedDisplayVersion;
  }
}
