import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/teacher_profile.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:http/http.dart' as http;

class ReceiveTokenPage extends StatefulWidget {
  final int classroomId;
  const ReceiveTokenPage({super.key, required this.classroomId});

  @override
  State<ReceiveTokenPage> createState() => _ReceiveTokenPageState();
}

class _ReceiveTokenPageState extends State<ReceiveTokenPage> {
  static const int rssiThreshold = -75;

  String teacherUid = "";
  bool _isScanning = false;
  bool _foregroundActive = false;
  int scanIndex = 1;

  StreamSubscription? _scanSubscription;
  List<Map<String, dynamic>> allSignals = [];
  List<Map<String, dynamic>> matchedSignals = [];
  Map<String, dynamic>? latestMatchedSignal; // <-- new state variable
  String _latestRssi = "N/A";

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeacherUid();
    });
  }

  // ---------------- Helper Methods ----------------
  void _addLog(String msg) {
    if (!mounted) return;
    setState(() {
      allSignals.insert(0, {"message": msg});
      if (allSignals.length > 50) allSignals = allSignals.sublist(0, 50);
    });
  }

  void _loadTeacherUid() {
    final profile = GlobalStore.teacherProfile;
    if (profile != null && profile.containsKey("uid")) {
      teacherUid = profile["uid"];
      _addLog("✅ Loaded teacher UID from global store: $teacherUid");
    } else {
      _addLog("⚠️ Teacher profile not found in global store.");
    }
  }

  String getCurrentUuid() {
    final raw = "$teacherUid$scanIndex";
    String clean = raw.padRight(32, '0');
    if (clean.length > 32) clean = clean.substring(0, 32);
    return "${clean.substring(0, 8)}-"
        "${clean.substring(8, 12)}-"
        "${clean.substring(12, 16)}-"
        "${clean.substring(16, 20)}-"
        "${clean.substring(20)}";
  }

  // ---------------- BLE Scanning ----------------
  Future<void> _startScanning() async {
    if (_isScanning || teacherUid.isEmpty) return;
    final targetUuid = getCurrentUuid().replaceAll('-', '').toLowerCase();
    if (!_foregroundActive && Platform.isAndroid) {
      await _startForegroundTask();
    }
    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
      if (results.isEmpty) return;
      String latestRssiLocal = _latestRssi;

      for (var result in results) {
        try {
          int rssi = result.rssi;
          String payload = 'N/A';
          if (result.advertisementData.manufacturerData.isNotEmpty) {
            final firstData =
                result.advertisementData.manufacturerData.values.first;
            if (firstData.isNotEmpty) payload = String.fromCharCodes(firstData);
          }

          List<String> scannedUuids = result.advertisementData.serviceUuids
              .map((u) => u.toString().replaceAll('-', '').toLowerCase())
              .toList();

          final signalInfo = {
            "uuidList": scannedUuids,
            "rssi": rssi,
            "payload": payload,
            "device": result.device.name.isNotEmpty
                ? result.device.name
                : result.device.id,
            "matched": false,
            "backendMessage": null,
          };

          // Always add to allSignals
          if (mounted) {
            setState(() {
              allSignals.insert(0, signalInfo);
              if (allSignals.length > 50)
                allSignals = allSignals.sublist(0, 50);
            });
          }

          // Check match
          if (scannedUuids.contains(targetUuid) && rssi >= rssiThreshold) {
            final backendMessage = await _callPassToken(payload, rssi);
            signalInfo["matched"] = true;
            signalInfo["backendMessage"] = backendMessage ?? "Success";

            if (mounted) {
              setState(() {
                matchedSignals.insert(0, signalInfo);
                latestMatchedSignal = signalInfo; // <-- new UI logic
                scanIndex++; // keep existing BLE/QR logic
              });
            }
          }

          latestRssiLocal =
              "$rssi dBm (${result.device.name.isNotEmpty ? result.device.name : result.device.id})";
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _latestRssi = latestRssiLocal;
        });
      }
    });

    try {
      await FlutterBluePlus.startScan(
        withServices: [],
        androidScanMode: AndroidScanMode.lowLatency,
      );
      if (!mounted) return;
      setState(() => _isScanning = true);
      _addLog("🔍 Scanning started (UUID: $targetUuid)");
    } catch (e) {
      _addLog("❌ Scan start error: $e");
    }
  }

  Future<void> _stopScanning() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isScanning = false;
      scanIndex++;
    });
    _addLog("🛑 Scanning stopped (scanIndex incremented → $scanIndex)");
  }

  // ---------------- Backend call ----------------
  Future<String?> _callPassToken(String fromUid, int rssi) async {
    try {
      final headers = await TokenHandles.getAuthHeaders();
      if (headers.isEmpty) {
        _addLog("❌ Auth failed, token missing");
        return null;
      }

      final url = Uri.parse(
        "${BaseUrl.value}/session/student/classroom/${widget.classroomId}/pass-token/",
      );

      final body = {"from_uid": fromUid, "to_uid": teacherUid};
      final response = await http.post(
        url,
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (!mounted) return null;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _addLog(
          "📤 Token passed successfully (RSSI: $rssi dBm) → ${data["message"] ?? "Success"}",
        );
        return data["message"];
      } else if (response.statusCode == 403) {
        final data = jsonDecode(response.body);
        _addLog("❌ Forbidden: ${data["detail"] ?? response.body}");
        return data["detail"] ?? "Forbidden";
      } else {
        final data = jsonDecode(response.body);
        _addLog("⚠️ Failed: ${data["error"] ?? response.body}");
        return data["error"] ?? "Failed";
      }
    } catch (e) {
      _addLog("❌ Exception: $e");
      return e.toString();
    }
  }

  // ---------------- Foreground Task ----------------
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bluetooth_scan_channel',
        channelName: 'BLE Scanning',
        channelDescription: 'Foreground service for continuous BLE scanning',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        buttons: const [NotificationButton(id: 'stop', text: 'STOP')],
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 3000,
        isOnceEvent: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<void> _startForegroundTask() async {
    if (_foregroundActive || !Platform.isAndroid) return;
    FlutterForegroundTask.startService(
      notificationTitle: 'BLE Scanning Active',
      notificationText: 'Bluetooth scanning running in background',
    );
    _foregroundActive = true;
  }

  @override
  void dispose() {
    _stopScanning();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receive Token")),
      body: Column(
        children: [
          const SizedBox(height: 20),
          if (teacherUid.isNotEmpty)
            Column(
              children: [
                const Text(
                  "Teacher UID QR Code:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                bw.BarcodeWidget(
                  barcode: bw.Barcode.qrCode(),
                  data: getCurrentUuid(),
                  width: 180,
                  height: 180,
                ),
              ],
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _isScanning ? _stopScanning : _startScanning,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isScanning ? Colors.red : null,
                ),
                child: Text(_isScanning ? "Stop Scanning" : "Start Scanning"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text("Latest RSSI: $_latestRssi"),
          const Divider(),

          // ---------------- UI Upgrade ----------------
          Expanded(
            child: Column(
              children: [
                // Latest matched signal
                if (latestMatchedSignal != null)
                  Container(
                    width: double.infinity,
                    color: Colors.green[300],
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Text(
                      "✅ Latest Matched!\nDevice: ${latestMatchedSignal!['device']}\nRSSI: ${latestMatchedSignal!['rssi']} dBm\nPayload: ${latestMatchedSignal!['payload']}\nBackend: ${latestMatchedSignal!['backendMessage'] ?? "Success"}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 8),

                // Scrollable list of other signals (max 30)
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    itemCount: allSignals.length > 30 ? 30 : allSignals.length,
                    itemBuilder: (context, index) {
                      final sig = allSignals[index];
                      if (sig.containsKey("matched") &&
                          sig["matched"] == true) {
                        return Container(
                          color: Colors.green[100],
                          padding: const EdgeInsets.all(6),
                          margin: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          child: Text(
                            "Matched\nDevice: ${sig['device']}\nRSSI: ${sig['rssi']} dBm",
                          ),
                        );
                      } else if (sig.containsKey("message")) {
                        return Text(sig["message"]);
                      } else {
                        return ListTile(
                          title: Text(sig['device']),
                          subtitle: Text(
                            "UUIDs: ${sig['uuidList'].join(', ')}\nRSSI: ${sig['rssi']} dBm\nPayload: ${sig['payload']}",
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
