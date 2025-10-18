import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static final List<Permission> _permissions = [
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.bluetoothAdvertise,
    Permission.location, // covers fine location
    Permission.camera,
  ];

  /// Requests all runtime permissions
  static Future<bool> requestAllPermissions(BuildContext context) async {
    for (Permission perm in _permissions) {
      PermissionStatus status = await perm.status;

      if (status.isGranted) continue;

      status = await perm.request();

      if (status.isPermanentlyDenied) {
        await _showPermanentDeniedDialog(context, perm);
        return false;
      }

      if (!status.isGranted) return false;
    }

    return true;
  }

  static Future<void> _showPermanentDeniedDialog(
    BuildContext context,
    Permission perm,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Permission Required"),
        content: Text(
          "${perm.toString().replaceAll("Permission.", "")} is permanently denied. Please enable it in settings.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text("Open Settings"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }
}
