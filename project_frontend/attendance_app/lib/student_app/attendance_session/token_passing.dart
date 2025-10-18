import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:attendance_app/global_variable/base_url.dart';
import 'package:attendance_app/global_variable/token_handles.dart';
import 'package:attendance_app/global_variable/student_profile.dart';
import 'package:flutter/material.dart';
import 'package:barcode_widget/barcode_widget.dart' as bw;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:attendance_app/permissions.dart';
import 'package:http/http.dart' as http;

class TokenTransferPage extends StatefulWidget {
  final String ownUid;
  final int classroomId;

  const TokenTransferPage({
    super.key,
    required this.ownUid,
    required this.classroomId,
  });

  @override
  State<TokenTransferPage> createState() => _TokenTransferPageState();
}

enum Stage { idle, transmit }

class _TokenTransferPageState extends State<TokenTransferPage> {
  static const int rssiThreshold = -75;
  Stage stage = Stage.idle;

  int scanIndex = 1;
  String? scannedPeerUuid;

  final MobileScannerController cameraController = MobileScannerController();
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  bool _isAdvertising = false;
  bool _isScanning = false;
  bool _foregroundActive = false;

  StreamSubscription? _scanSubscription;
  List<String> _receivedMessages = [];
  String _latestRssi = "N/A";
  String? _latestMatchedMsg;

  // Advertising debug info
  String? _advertisingUuid;
  String? _advertisingPayload;
  String _advertisingStatus = "Stopped";

  // Dynamic target UUID
  String _currentTargetUuid = '';

  final TextEditingController _rxUuidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      bool granted = await AppPermissions.requestAllPermissions(context);
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Permissions not granted")),
        );
      }
    });
    _initForegroundTask();
  }

  // ---------------- Helper Methods ----------------
  String getCurrentUuid() {
    final raw = "${widget.ownUid}$scanIndex";
    String clean = raw.padRight(32, '0');
    if (clean.length > 32) clean = clean.substring(0, 32);
    return "${clean.substring(0, 8)}-"
        "${clean.substring(8, 12)}-"
        "${clean.substring(12, 16)}-"
        "${clean.substring(16, 20)}-"
        "${clean.substring(20)}";
  }

  Uint8List payloadToBytes(String payload) {
    if (payload.length > 16) {
      payload = payload.substring(0, 16);
    }
    return Uint8List.fromList(payload.codeUnits);
  }

  String formatUuid(String input) {
    input = input.trim().replaceAll(' ', '');
    if (input.isEmpty) throw FormatException('UUID cannot be empty');

    if (RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(input)) {
      return input.toLowerCase();
    }

    if (RegExp(r'^[0-9]+$').hasMatch(input)) {
      String first = input.padLeft(8, '0').substring(0, 8);
      String second = input.length > 8
          ? input.substring(8).padRight(4, '0').substring(0, 4)
          : '0000';
      String third = input.length > 12
          ? input.substring(12).padRight(4, '0').substring(0, 4)
          : '0000';
      String fourth = '0000';
      String fifth = '000000000000';
      return "$first-$second-$third-$fourth-$fifth";
    }

    throw FormatException('Invalid UUID format');
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _callPassToken(String fromUid, String toUid, int rssi) async {
    try {
      final headers = await TokenHandles.getAuthHeaders();
      if (headers.isEmpty) return _showSnack("❌ Authentication failed");

      final url = Uri.parse(
        "${BaseUrl.value}/session/student/classroom/${widget.classroomId}/pass-token/",
      );

      final response = await http.post(
        url,
        headers: {...headers, "Content-Type": "application/json"},
        body: jsonEncode({"from_uid": fromUid, "to_uid": toUid}),
      );

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        _showSnack("✅ ${body["message"] ?? "Token passed!"} (RSSI: $rssi dBm)");
      } else {
        _showSnack("❌ ${body["error"] ?? "Unknown error"}");
      }
    } catch (e) {
      _showSnack("❌ Exception: $e");
    }
  }

  // ---------------- Advertising ----------------
  Future<void> _startAdvertising(String targetUuid) async {
    final payload =
        GlobalStudentProfile.currentStudent?.uid ??
        widget.ownUid; // Use student's UID
    Uint8List payloadBytes = payloadToBytes(payload);
    String uuid = formatUuid(targetUuid);

    final advertiseData = AdvertiseData(
      serviceUuid: uuid,
      manufacturerId: 1234,
      manufacturerData: payloadBytes,
      includeDeviceName: true,
    );

    try {
      await _blePeripheral.start(advertiseData: advertiseData);
      setState(() {
        _isAdvertising = true;
        _advertisingUuid = uuid;
        _advertisingPayload = payload;
        _advertisingStatus = "Active";
      });
      _showSnack("📡 Advertising started (UUID: $uuid, Payload: $payload)");
    } catch (e) {
      setState(() => _advertisingStatus = "Error: $e");
      _showSnack("❌ BLE advertise error: $e");
    }
  }

  Future<void> _stopAdvertising() async {
    await _blePeripheral.stop();
    setState(() {
      _isAdvertising = false;
      _advertisingUuid = null;
      _advertisingPayload = null;
      _advertisingStatus = "Stopped";
    });
    _showSnack("📴 Advertising stopped");
  }

  // ---------------- Scanning ----------------
  Future<void> _startScanning(String rxUuid) async {
    if (_isScanning) return;

    _currentTargetUuid = formatUuid(rxUuid).replaceAll('-', '').toLowerCase();

    if (!_foregroundActive && Platform.isAndroid) {
      Future.microtask(() => _startForegroundTask());
    }

    await _scanSubscription?.cancel();

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (results.isEmpty) return;

      List<String> newMessages = [];
      String latestRssiLocal = _latestRssi;

      for (var result in results) {
        try {
          int rssi = result.rssi;
          String payloadValue = 'N/A';

          if (result.advertisementData.manufacturerData.isNotEmpty) {
            payloadValue = String.fromCharCodes(
              result.advertisementData.manufacturerData.values.first,
            );
          }

          List<String> scannedUuids = result.advertisementData.serviceUuids
              .map((u) => u.toString().replaceAll('-', '').toLowerCase())
              .toList();

          String msg =
              "UUIDs: ${scannedUuids.join(', ')}, RSSI: $rssi, Payload: $payloadValue, Device: ${result.device.name.isNotEmpty ? result.device.name : result.device.id}";
          newMessages.add(msg);

          if (scannedUuids.contains(_currentTargetUuid) &&
              rssi >= rssiThreshold) {
            Future.microtask(
              () => _callPassToken(payloadValue, widget.ownUid, rssi),
            );
            scanIndex++;
            _latestMatchedMsg = msg;
            _currentTargetUuid = getCurrentUuid(); // update next scan
          }

          latestRssiLocal =
              "$rssi dBm (${result.device.name.isNotEmpty ? result.device.name : result.device.id})";
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _receivedMessages.insertAll(0, newMessages);
          if (_receivedMessages.length > 50) {
            _receivedMessages = _receivedMessages.sublist(0, 50);
          }
          _latestRssi = latestRssiLocal;
        });
      }
    });

    FlutterBluePlus.startScan(
      withServices: [],
      androidScanMode: AndroidScanMode.lowLatency,
      continuousUpdates: true,
    );

    setState(() => _isScanning = true);
    _showSnack("🔍 Scanning started (UUID: $rxUuid)");
  }

  Future<void> _stopScanning() async {
    await _stopForegroundTask();
    await _scanSubscription?.cancel();
    _scanSubscription = null;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    scanIndex++;
    _currentTargetUuid = getCurrentUuid(); // Update after manual stop
    setState(() => _isScanning = false);
    _showSnack("🛑 Scanning stopped (scanIndex incremented → $scanIndex)");
  }

  // ---------------- Foreground Task ----------------
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bluetooth_scan_channel',
        channelName: 'Bluetooth Scanning',
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
    bool running = await FlutterForegroundTask.isRunningService;
    if (!running) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'BLE Scanning Active',
        notificationText: 'Bluetooth scanning running in background',
      );
    }
    _foregroundActive = true;
  }

  Future<void> _stopForegroundTask() async {
    if (_foregroundActive) {
      await FlutterForegroundTask.stopService();
      _foregroundActive = false;
    }
  }

  // ---------------- QR ----------------
  void _onQrDetected(String scannedValue) {
    if (stage == Stage.idle && scannedPeerUuid == null) {
      scannedPeerUuid = scannedValue;
      setState(() {
        stage = Stage.transmit;
        _advertisingStatus = "Starting...";
        _advertisingUuid = scannedValue;
        _advertisingPayload =
            GlobalStudentProfile.currentStudent?.uid ?? widget.ownUid;
        _isAdvertising = true;
      });

      // Start BLE advertising async
      _startAdvertising(scannedValue)
          .then((_) => setState(() => _advertisingStatus = "Active"))
          .catchError((e) => setState(() => _advertisingStatus = "Error: $e"));
    }
  }

  Future<void> _onStopTransmit() async {
    await _stopAdvertising();
    scannedPeerUuid = null;
    setState(() => stage = Stage.idle);
  }

  @override
  void dispose() {
    cameraController.dispose();
    _scanSubscription?.cancel();
    _stopForegroundTask();
    _blePeripheral.stop();
    _rxUuidController.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Token Transfer")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: cameraController,
              onDetect: (capture) {
                if (capture.barcodes.isNotEmpty) {
                  final barcode = capture.barcodes.first;
                  if (barcode.rawValue != null)
                    _onQrDetected(barcode.rawValue!);
                }
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_latestMatchedMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.green[200],
                    child: Text(
                      "Matched: $_latestMatchedMsg",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                bw.BarcodeWidget(
                  barcode: bw.Barcode.qrCode(),
                  data: getCurrentUuid(),
                  width: 140,
                  height: 140,
                ),
                const SizedBox(height: 12),
                Text(
                  "Your UID: ${widget.ownUid}",
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (stage == Stage.transmit)
                      ElevatedButton(
                        onPressed: _onStopTransmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text("Stop Transmitting"),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isScanning
                            ? _stopScanning
                            : () => _startScanning(getCurrentUuid()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isScanning ? Colors.red : null,
                        ),
                        child: Text(
                          _isScanning ? "Stop Scanning" : "Start Scanning",
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          // Scrollable debug info
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isAdvertising)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      color: Colors.blue[100],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "📡 Advertising Debug Info",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text("UUID: ${_advertisingUuid ?? 'N/A'}"),
                          Text("Payload: ${_advertisingPayload ?? 'N/A'}"),
                          Text("Status: $_advertisingStatus"),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text("Scanned Messages (scrollable, max 50):"),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _receivedMessages.length,
                    itemBuilder: (context, index) =>
                        ListTile(title: Text(_receivedMessages[index])),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
