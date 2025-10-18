package com.example.attendance_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID

class MainActivity : FlutterActivity() {

    private lateinit var bleHelper: NordicBleHelper
    private val CHANNEL = "ble_channel"
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        bleHelper = NordicBleHelper(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    // ---------------- Start Advertising ----------------
                    "startAdvertising" -> {
                        val payloadList = call.argument<List<Int>>("payload")
                        val uuidString = call.argument<String>("uuid")

                        if (payloadList == null || uuidString == null) {
                            result.error("INVALID", "Missing payload or uuid", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val payload = payloadList.map { it.toByte() }.toByteArray()
                            val uuid = UUID.fromString(uuidString)
                            bleHelper.startAdvertising(payload, uuid)
                            result.success("Advertising started")
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to advertise: $e", null)
                        }
                    }

                    // ---------------- Stop Advertising ----------------
                    "stopAdvertising" -> {
                        try {
                            bleHelper.stopAdvertising()
                            result.success("Advertising stopped")
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to stop advertising: $e", null)
                        }
                    }

                    // ---------------- Start Scanning ----------------
                    "startScan" -> {
                        val uuidString = call.argument<String>("uuid")
                        if (uuidString == null) {
                            result.error("INVALID", "UUID not provided", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val uuid = UUID.fromString(uuidString)
                            bleHelper.startScanning(uuid) { payload, rssi ->
                                coroutineScope.launch {
                                    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                        .invokeMethod(
                                            "bleScanResult",
                                            mapOf(
                                                "payload" to payload.toList(),
                                                "rssi" to rssi
                                            )
                                        )
                                }
                            }
                            result.success("Scanning started")
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to start scanning: $e", null)
                        }
                    }

                    // ---------------- Stop Scanning ----------------
                    "stopScan" -> {
                        try {
                            bleHelper.stopScanning()
                            result.success("Scanning stopped")
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to stop scanning: $e", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
