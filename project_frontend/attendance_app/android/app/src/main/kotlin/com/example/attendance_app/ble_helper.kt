package com.example.attendance_app

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.*
import android.content.Context
import android.os.ParcelUuid
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID

class NordicBleHelper(context: Context) {

    private val bluetoothManager =
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    private val bluetoothAdapter = bluetoothManager.adapter
    private val advertiser: BluetoothLeAdvertiser? = bluetoothAdapter.bluetoothLeAdvertiser
    private val scanner = bluetoothAdapter.bluetoothLeScanner
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    private var scanCallback: ScanCallback? = null
    private var advertiseCallback: AdvertiseCallback? = null

    /**
     * Start advertising BLE payload with a given UUID.
     */
    fun startAdvertising(payload: ByteArray, serviceUuid: UUID) {
        stopAdvertising() // ✅ ensure no duplicate advertiser is running

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(false)
            .build()

        val data = AdvertiseData.Builder()
            .addServiceUuid(ParcelUuid(serviceUuid))
            .addServiceData(ParcelUuid(serviceUuid), payload)
            .build()

        advertiseCallback = object : AdvertiseCallback() {
            override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
                super.onStartSuccess(settingsInEffect)
                // Optional: log success
            }

            override fun onStartFailure(errorCode: Int) {
                super.onStartFailure(errorCode)
                // Optional: log error
            }
        }

        advertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    fun stopAdvertising() {
        advertiseCallback?.let {
            advertiser?.stopAdvertising(it)
        }
        advertiseCallback = null
    }

    /**
     * Scan for a BLE device broadcasting the given service UUID.
     */
    fun startScanning(
        targetUuid: UUID,
        onResult: (payload: ByteArray, rssi: Int) -> Unit
    ) {
        stopScanning() // ✅ clear old scans first

        val filters = listOf(
            ScanFilter.Builder()
                .setServiceUuid(ParcelUuid(targetUuid))
                .build()
        )

        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()

        scanCallback = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val serviceData = result.scanRecord?.getServiceData(ParcelUuid(targetUuid))
                if (serviceData != null) {
                    coroutineScope.launch {
                        onResult(serviceData, result.rssi)
                    }
                    stopScanning() // ✅ stop after first successful match
                }
            }

            override fun onBatchScanResults(results: MutableList<ScanResult>) {
                // Optional: handle multiple results
            }

            override fun onScanFailed(errorCode: Int) {
                // Optional: log scan error
            }
        }

        scanner.startScan(filters, settings, scanCallback)
    }

    fun stopScanning() {
        scanCallback?.let {
            scanner.stopScan(it)
        }
        scanCallback = null
    }
}
