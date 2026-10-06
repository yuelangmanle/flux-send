package org.localsend.localsend_app

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger
import kotlin.concurrent.thread

class ClassicBluetoothBridge(private val context: Context) : EventChannel.StreamHandler {
    private val serviceUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val serviceName = "FluxClassicBluetooth"
    private val fluxBluetoothMessage = "flux.bluetooth.message.v1"
    private val fluxBluetoothHello = "flux.bluetooth.hello.v1"
    private val fluxBluetoothHelloAck = "flux.bluetooth.hello.ack.v1"

    // 断开/错误事件的结构化代码：Dart 侧按代码分支，文案仅作展示（i18n 安全）。
    private val codeDisconnected = "DISCONNECTED"
    private val codeHandshakeSendFailed = "HANDSHAKE_SEND_FAILED"
    private val codeHandshakeAckSendFailed = "HANDSHAKE_ACK_SEND_FAILED"
    private val codeHandshakeIncomplete = "HANDSHAKE_INCOMPLETE"
    private val codePeerNotFlux = "PEER_NOT_FLUX"
    private val maxWriteChunkSize = 8192
    private val mainHandler = Handler(Looper.getMainLooper())
    private val bluetoothAdapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
    private var eventSink: EventChannel.EventSink? = null
    private var serverSocket: BluetoothServerSocket? = null
    private var socket: BluetoothSocket? = null
    private val connectionGeneration = AtomicInteger(0)
    @Volatile private var running = false
    @Volatile private var handshakeComplete = false
    @Volatile private var activeRole = ""

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result): Boolean {
        when (call.method) {
            "listClassicBluetoothPairedDevices" -> {
                result.success(listPairedDevices())
                return true
            }
            "startClassicBluetoothServer" -> {
                result.success(startServer())
                return true
            }
            "stopClassicBluetooth" -> {
                stop()
                result.success(null)
                return true
            }
            "connectClassicBluetoothDevice" -> {
                val address = call.argument<String>("address")
                if (address.isNullOrBlank()) {
                    result.error("INVALID_ADDRESS", "Missing Bluetooth MAC address", null)
                    return true
                }
                connect(address)
                result.success(null)
                return true
            }
            "sendClassicBluetoothClipboard" -> {
                val text = call.argument<String>("text") ?: ""
                result.success(sendClipboard(text))
                return true
            }
            "sendClassicBluetoothFrame" -> {
                val payload = call.argument<String>("payload") ?: ""
                result.success(sendFrame(payload, sentMessage = null))
                return true
            }
        }
        return false
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        emit("status", "经典蓝牙事件通道已连接")
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    @SuppressLint("MissingPermission")
    private fun listPairedDevices(): List<Map<String, String>> {
        if (!hasBluetoothConnectPermission()) {
            emit("error", "缺少 BLUETOOTH_CONNECT 权限")
            return emptyList()
        }

        return try {
            bluetoothAdapter?.bondedDevices?.map { device ->
                mapOf(
                    "address" to device.address.orEmpty(),
                    "name" to (device.name ?: device.address.orEmpty()),
                )
            } ?: emptyList()
        } catch (e: SecurityException) {
            emit("error", "读取已配对蓝牙设备失败：${e.message}")
            emptyList()
        }
    }

    @SuppressLint("MissingPermission")
    private fun startServer(): Boolean {
        if (!hasBluetoothConnectPermission()) {
            emit("error", "缺少 BLUETOOTH_CONNECT 权限")
            return false
        }
        if (!hasBluetoothAdvertisePermission()) {
            emit("error", "缺少 BLUETOOTH_ADVERTISE 权限")
            return false
        }
        if (running) {
            emit("status", "经典蓝牙 RFCOMM 服务已在运行")
            return true
        }

        val adapter = bluetoothAdapter
        if (adapter == null) {
            emit("error", "经典蓝牙不可用：未找到蓝牙适配器")
            return false
        }

        val nextServerSocket = try {
            adapter.listenUsingRfcommWithServiceRecord(serviceName, serviceUuid)
        } catch (e: Exception) {
            emit("error", "经典蓝牙监听启动失败：${e.message}")
            Log.w("FluxBluetooth", "Server socket creation failed", e)
            return false
        }

        val generation = connectionGeneration.incrementAndGet()
        serverSocket = nextServerSocket
        running = true
        thread(name = "FluxBluetoothServer", isDaemon = true) {
            try {
                emit("listening", "经典蓝牙 RFCOMM 正在等待配对设备连接")
                while (running) {
                    val accepted = nextServerSocket.accept() ?: break
                    attachSocket(accepted, "server", generation)
                }
            } catch (e: Exception) {
                if (running) {
                    emit("error", "经典蓝牙服务异常：${e.message}")
                    Log.w("FluxBluetooth", "Server failed", e)
                }
            } finally {
                running = false
                closeServerSocket(nextServerSocket)
            }
        }
        return true
    }

    @SuppressLint("MissingPermission")
    private fun connect(address: String) {
        if (!hasBluetoothConnectPermission()) {
            emit("error", "缺少 BLUETOOTH_CONNECT 权限")
            return
        }

        val generation = connectionGeneration.incrementAndGet()
        closeSocket(emitDisconnected = false)
        thread(name = "FluxBluetoothClient", isDaemon = true) {
            var nextSocket: BluetoothSocket? = null
            try {
                val adapter = bluetoothAdapter ?: throw IllegalStateException("Bluetooth adapter unavailable")
                val device: BluetoothDevice = adapter.getRemoteDevice(address)
                nextSocket = device.createRfcommSocketToServiceRecord(serviceUuid)
                adapter.cancelDiscovery()
                nextSocket.connect()
                attachSocket(nextSocket, "client", generation)
                nextSocket = null
            } catch (e: Exception) {
                closeQuietly(nextSocket)
                if (connectionGeneration.get() == generation) {
                    emit("error", "经典蓝牙连接失败：${e.message}")
                }
                Log.w("FluxBluetooth", "Connect failed", e)
            }
        }
    }

    private fun attachSocket(nextSocket: BluetoothSocket, role: String, generation: Int) {
        if (connectionGeneration.get() != generation) {
            closeQuietly(nextSocket)
            return
        }
        closeSocket(emitDisconnected = false)
        socket = nextSocket
        handshakeComplete = false
        activeRole = role
        emit("status", "经典蓝牙通道已打开，正在验证 Flux 对端")
        thread(name = "FluxBluetoothReadLoop", isDaemon = true) {
            readLoop(nextSocket)
        }
        if (!sendHandshake(nextSocket, fluxBluetoothHello)) {
            closeActiveSocket(nextSocket, "经典蓝牙握手发送失败", codeHandshakeSendFailed)
        }
    }

    private fun readLoop(activeSocket: BluetoothSocket) {
        var disconnectMessage = "经典蓝牙连接已断开"
        var disconnectCode = codeDisconnected
        try {
            val reader = BufferedReader(InputStreamReader(activeSocket.inputStream, Charsets.UTF_8))
            while (socket === activeSocket) {
                val line = reader.readLine() ?: break
                try {
                    val json = JSONObject(line)
                    when (json.optString("type")) {
                        fluxBluetoothHello -> {
                            if (!sendHandshake(activeSocket, fluxBluetoothHelloAck)) {
                                disconnectMessage = "经典蓝牙握手确认发送失败"
                                disconnectCode = codeHandshakeAckSendFailed
                                break
                            }
                            confirmHandshake(activeSocket, activeRole)
                        }
                        fluxBluetoothHelloAck -> confirmHandshake(activeSocket, activeRole)
                        fluxBluetoothMessage -> {
                            if (!handshakeComplete) {
                                disconnectMessage = "经典蓝牙握手未完成，已拒绝未验证数据"
                                disconnectCode = codeHandshakeIncomplete
                                break
                            }
                            if (socket !== activeSocket) {
                                break
                            }
                            emit("clipboard", json.optString("text"))
                        }
                        else -> {
                            if (!handshakeComplete) {
                                disconnectMessage = "经典蓝牙连接的对端不是 Flux，已断开"
                                disconnectCode = codePeerNotFlux
                                break
                            }
                            if (socket !== activeSocket) {
                                break
                            }
                            emit("message", line)
                        }
                    }
                } catch (e: Exception) {
                    if (!handshakeComplete) {
                        disconnectMessage = "经典蓝牙连接的对端不是 Flux，已断开"
                        disconnectCode = codePeerNotFlux
                        break
                    }
                    if (socket !== activeSocket) {
                        break
                    }
                    emit("message", line)
                }
            }
        } catch (e: Exception) {
            disconnectMessage = "经典蓝牙连接已断开：${e.message}"
        } finally {
            if (socket === activeSocket) {
                closeActiveSocket(activeSocket, disconnectMessage)
            }
        }
    }

    private fun closeActiveSocket(activeSocket: BluetoothSocket, message: String, code: String = codeDisconnected) {
        closeSocket(emitDisconnected = false)
        emitDisconnected(message, code)
    }

    private fun sendClipboard(text: String): Boolean {
        val payload = JSONObject()
            .put("type", fluxBluetoothMessage)
            .put("text", text)
            .toString()
        return sendFrame(payload, sentMessage = "经典蓝牙剪切板已发送")
    }

    private fun sendFrame(payload: String, sentMessage: String?): Boolean {
        val activeSocket = socket
        if (activeSocket == null || !activeSocket.isConnected || !handshakeComplete) {
            val reason = if (activeSocket == null || !activeSocket.isConnected) {
                "经典蓝牙未连接，无法发送剪切板或文件"
            } else {
                "经典蓝牙尚未完成 Flux 协议握手，无法发送剪切板或文件"
            }
            emit("error", reason)
            return false
        }

        return writeFrame(activeSocket, payload, sentMessage)
    }

    private fun sendHandshake(activeSocket: BluetoothSocket, type: String): Boolean {
        return writeFrame(activeSocket, JSONObject().put("type", type).toString(), sentMessage = null)
    }

    @Synchronized
    private fun writeFrame(activeSocket: BluetoothSocket, payload: String, sentMessage: String?): Boolean {
        if (socket !== activeSocket || !activeSocket.isConnected) {
            return false
        }
        val frame = if (payload.endsWith("\n")) payload else "$payload\n"
        try {
            val bytes = frame.toByteArray(Charsets.UTF_8)
            var offset = 0
            while (offset < bytes.size) {
                val chunkSize = minOf(maxWriteChunkSize, bytes.size - offset)
                activeSocket.outputStream.write(bytes, offset, chunkSize)
                offset += chunkSize
            }
            activeSocket.outputStream.flush()
            if (sentMessage != null) {
                emit("sent", sentMessage)
            }
            return true
        } catch (e: Exception) {
            emit("error", "经典蓝牙发送失败：${e.message}")
            return false
        }
    }

    private fun confirmHandshake(nextSocket: BluetoothSocket, role: String) {
        if (socket !== nextSocket || handshakeComplete) {
            return
        }
        handshakeComplete = true
        val deviceName = remoteDeviceName(nextSocket)
        emit(
            "connected",
            if (deviceName.isBlank()) "经典蓝牙 Flux 握手完成（$role）" else "经典蓝牙 Flux 已连接：$deviceName（$role）",
            mapOf(
                "address" to nextSocket.remoteDevice?.address.orEmpty(),
                "name" to deviceName,
                "role" to role,
            ),
        )
    }

    fun stop() {
        connectionGeneration.incrementAndGet()
        running = false
        closeSocket(emitDisconnected = false)
        closeServerSocket()
        emit("stopped", "经典蓝牙已停止")
    }

    private fun closeSocket(emitDisconnected: Boolean = false) {
        val hadSocket = socket != null
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
        handshakeComplete = false
        activeRole = ""
        if (emitDisconnected && hadSocket) {
            emit("disconnected", "经典蓝牙连接已断开")
        }
    }

    private fun closeServerSocket(activeServerSocket: BluetoothServerSocket? = serverSocket) {
        try {
            activeServerSocket?.close()
        } catch (_: Exception) {
        }
        if (serverSocket === activeServerSocket) {
            serverSocket = null
        }
    }

    private fun closeQuietly(socket: BluetoothSocket?) {
        try {
            socket?.close()
        } catch (_: Exception) {
        }
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    private fun hasBluetoothAdvertisePermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            ContextCompat.checkSelfPermission(context, Manifest.permission.BLUETOOTH_ADVERTISE) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission")
    private fun remoteDeviceName(activeSocket: BluetoothSocket): String {
        return try {
            activeSocket.remoteDevice?.name ?: activeSocket.remoteDevice?.address.orEmpty()
        } catch (_: SecurityException) {
            activeSocket.remoteDevice?.address.orEmpty()
        }
    }

    private fun emit(type: String, message: String, extras: Map<String, String> = emptyMap()) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "message" to message) + extras)
        }
    }

    private fun emitDisconnected(message: String, code: String) {
        emit("disconnected", message, mapOf("code" to code))
    }
}
