import 'dart:io';

import 'package:path/path.dart' as p;

/// Whether this process can create a symbolic link.
///
/// Flutter wires plugins up with symlinks, so without this
/// `flutter pub get` fails for any project including the `windows` or
/// `linux` platforms — which the default `--platforms` set does. Windows
/// grants the privilege only under Developer Mode or elevation; other
/// platforms effectively always allow it.
bool canCreateSymlink() {
  final Directory probe;
  try {
    probe = Directory.systemTemp.createTempSync('fluframe_symlink_');
  } on FileSystemException {
    return false;
  }
  try {
    Link(p.join(probe.path, 'probe')).createSync(probe.path);
    return true;
  } on FileSystemException {
    return false;
  } finally {
    try {
      probe.deleteSync(recursive: true);
    } on FileSystemException {
      // Best-effort cleanup.
    }
  }
}
