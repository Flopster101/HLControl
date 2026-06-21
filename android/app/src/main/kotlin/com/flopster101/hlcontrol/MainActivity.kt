package com.flopster101.hlcontrol

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val PERMISSION_REQUEST_CODE = 444
    private var permissionResultCallback: MethodChannel.Result? = null

    private var scanResultCallback: MethodChannel.Result? = null
    private val discoveredDevices = mutableListOf<Map<String, String>>()
    private val bluetoothReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (BluetoothDevice.ACTION_FOUND == action) {
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                if (device != null) {
                    val name = if (ActivityCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                        device.name
                    } else null
                    val mac = device.address
                    if (mac != null) {
                        val devMap = mapOf("name" to (name ?: "Unknown Device"), "mac" to mac)
                        if (!discoveredDevices.any { it["mac"] == mac }) {
                            discoveredDevices.add(devMap)
                        }
                    }
                }
            } else if (BluetoothAdapter.ACTION_DISCOVERY_FINISHED == action) {
                sendScanResult()
            }
        }
    }

    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var socket: BluetoothSocket? = null
    private var outStream: OutputStream? = null
    private var inStream: InputStream? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isConnected = false

    override fun configureFlutterEngine(@NonNull flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flopster101.hlcontrol/bluetooth").setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    result.success(hasRequiredPermissions())
                }
                "requestPermissions" -> {
                    requestRequiredPermissions(result)
                }
                "getPairedDevices" -> {
                    getPairedDevices(result)
                }
                "startScan" -> {
                    startScan(result)
                }
                "connect" -> {
                    val mac = call.argument<String>("mac") ?: ""
                    connect(mac, result)
                }
                "disconnect" -> {
                    disconnect(result)
                }
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes") ?: byteArrayOf()
                    write(bytes, result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flopster101.hlcontrol/bluetooth_events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun hasRequiredPermissions(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_SCAN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
        } else {
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_ADMIN) == PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestRequiredPermissions(result: MethodChannel.Result) {
        if (hasRequiredPermissions()) {
            result.success(true)
            return
        }
        permissionResultCallback = result
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT),
                PERMISSION_REQUEST_CODE
            )
        } else {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(
                    Manifest.permission.BLUETOOTH,
                    Manifest.permission.BLUETOOTH_ADMIN,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ),
                PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            permissionResultCallback?.success(allGranted)
            permissionResultCallback = null
        }
    }

    private fun getPairedDevices(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not supported on this device", null)
            return
        }
        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        try {
            val bondedDevices = adapter.bondedDevices
            val deviceList = mutableListOf<Map<String, String>>()
            for (device in bondedDevices) {
                val name = if (ActivityCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                    device.name
                } else null
                val mac = device.address
                if (mac != null) {
                    deviceList.add(mapOf("name" to (name ?: "Unknown Device"), "mac" to mac))
                }
            }
            result.success(deviceList)
        } catch (e: Exception) {
            result.error("PAIRED_QUERY_FAILED", e.message, null)
        }
    }

    private fun startScan(result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not supported on this device", null)
            return
        }
        if (!hasRequiredPermissions()) {
            result.error("PERMISSION_DENIED", "Bluetooth permissions not granted", null)
            return
        }

        scanResultCallback = result
        discoveredDevices.clear()

        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }
        registerReceiver(bluetoothReceiver, filter)

        try {
            adapter.startDiscovery()
            // Force stop after 4 seconds if not finished
            Handler(Looper.getMainLooper()).postDelayed({
                if (adapter.isDiscovering) {
                    adapter.cancelDiscovery()
                }
            }, 4000)
        } catch (e: Exception) {
            sendScanResult()
        }
    }

    private fun sendScanResult() {
        try {
            unregisterReceiver(bluetoothReceiver)
        } catch (e: Exception) {}

        scanResultCallback?.success(discoveredDevices)
        scanResultCallback = null
    }

    private fun connect(mac: String, result: MethodChannel.Result) {
        val adapter = BluetoothAdapter.getDefaultAdapter()
        if (adapter == null) {
            result.error("BLUETOOTH_UNAVAILABLE", "Bluetooth is not supported on this device", null)
            return
        }
        val device = adapter.getRemoteDevice(mac)
        if (device == null) {
            result.error("DEVICE_NOT_FOUND", "Device with MAC address $mac not found", null)
            return
        }

        executor.execute {
            try {
                sendEvent("status", "connecting")

                // Try port 10 reflection first
                var connected = false
                try {
                    val m = device.javaClass.getMethod("createInsecureRfcommSocket", Int::class.javaPrimitiveType)
                    val s = m.invoke(device, 10) as BluetoothSocket
                    adapter.cancelDiscovery()
                    s.connect()
                    socket = s
                    connected = true
                } catch (e: Exception) {
                    // Fallback to standard SPP UUID
                    try {
                        val sppUuid = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
                        val s = device.createInsecureRfcommSocketToServiceRecord(sppUuid)
                        adapter.cancelDiscovery()
                        s.connect()
                        socket = s
                        connected = true
                    } catch (e2: Exception) {
                        throw e2
                    }
                }

                if (connected) {
                    outStream = socket!!.outputStream
                    inStream = socket!!.inputStream
                    isConnected = true

                    Handler(Looper.getMainLooper()).post {
                        result.success(true)
                    }

                    sendEvent("status", "connected")
                    Thread { listenForData() }.start()
                } else {
                    throw IOException("Could not connect to device")
                }
            } catch (e: Exception) {
                android.util.Log.e("HLControl-Native", "connect failed with exception: ${e.message}", e)
                disconnectInternal()
                Handler(Looper.getMainLooper()).post {
                    result.error("CONNECTION_FAILED", e.message, null)
                }
                sendEvent("status", "failed")
            }
        }
    }

    private fun listenForData() {
        val buffer = ByteArray(1024)
        while (isConnected) {
            try {
                val bytesRead = inStream?.read(buffer) ?: -1
                if (bytesRead > 0) {
                    val data = buffer.copyOfRange(0, bytesRead)
                    val intList = data.map { it.toInt() and 0xFF }
                    Handler(Looper.getMainLooper()).post {
                        sendEvent("data", intList)
                    }
                } else if (bytesRead == -1) {
                    throw IOException("End of stream reached")
                }
            } catch (e: Exception) {
                android.util.Log.e("HLControl-Native", "listenForData error or socket disconnected: ${e.message}", e)
                if (isConnected) {
                    disconnectInternal()
                    sendEvent("status", "disconnected")
                }
                break
            }
        }
    }

    private fun write(bytes: ByteArray, result: MethodChannel.Result) {
        if (!isConnected || outStream == null) {
            result.error("NOT_CONNECTED", "No device connected", null)
            return
        }
        executor.execute {
            try {
                outStream?.write(bytes)
                outStream?.flush()
                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
            } catch (e: Exception) {
                android.util.Log.e("HLControl-Native", "write failed with exception: ${e.message}", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("WRITE_FAILED", e.message, null)
                }
            }
        }
    }

    private fun disconnect(result: MethodChannel.Result) {
        disconnectInternal()
        result.success(true)
        sendEvent("status", "disconnected")
    }

    private fun disconnectInternal() {
        isConnected = false
        try { inStream?.close() } catch (e: Exception) {}
        inStream = null
        try { outStream?.close() } catch (e: Exception) {}
        outStream = null
        try { socket?.close() } catch (e: Exception) {}
        socket = null
    }

    private fun sendEvent(event: String, value: Any?) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(mapOf("event" to event, "value" to value))
        }
    }
}
