import Foundation
import FlutterMacOS
import IOBluetooth

final class ClassicBluetoothBridge: NSObject, FlutterStreamHandler, IOBluetoothRFCOMMChannelDelegate {
    private let serviceUuid = IOBluetoothSDPUUID(uuid16: 0x1101)
    private let fluxBluetoothMessage = "flux.bluetooth.message.v1"
    private let fluxBluetoothHello = "flux.bluetooth.hello.v1"
    private let fluxBluetoothHelloAck = "flux.bluetooth.hello.ack.v1"

    // 断开/错误事件的结构化代码：与 Android 端保持一致，Dart 侧按代码分支。
    private let codeDisconnected = "DISCONNECTED"
    private let codeHandshakeSendFailed = "HANDSHAKE_SEND_FAILED"
    private let codeHandshakeAckSendFailed = "HANDSHAKE_ACK_SEND_FAILED"
    private let codeHandshakeIncomplete = "HANDSHAKE_INCOMPLETE"
    private let codePeerNotFlux = "PEER_NOT_FLUX"
    private let protocolVersion = 2
    private let maxWriteChunkSize = 8192
    private var eventSink: FlutterEventSink?
    private var channel: IOBluetoothRFCOMMChannel?
    private var notification: IOBluetoothUserNotification?
    private var serviceRecord: IOBluetoothSDPServiceRecord?
    private var serviceChannelID = BluetoothRFCOMMChannelID(1)
    private var receiveData = Data()
    private var connectionGeneration = 0
    private var handshakeComplete = false
    private var activeRole = ""
    private var activeAddress = ""
    private var activeName = ""
    private var hasBluetoothUsageDescription: Bool {
        guard let description = Bundle.main.object(forInfoDictionaryKey: "NSBluetoothAlwaysUsageDescription") as? String else {
            return false
        }
        return !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) -> Bool {
        switch call.method {
        case "listClassicBluetoothPairedDevices":
            guard hasBluetoothUsageDescription else {
                result(bluetoothUsageDescriptionMissingError())
                return true
            }
            result(listPairedDevices())
            return true
        case "startClassicBluetoothServer":
            guard hasBluetoothUsageDescription else {
                result(bluetoothUsageDescriptionMissingError())
                return true
            }
            result(startServer())
            return true
        case "stopClassicBluetooth":
            stop()
            result(nil)
            return true
        case "connectClassicBluetoothDevice":
            guard let args = call.arguments as? [String: Any],
                  let address = args["address"] as? String,
                  !address.isEmpty else {
                result(FlutterError(code: "INVALID_ADDRESS", message: "Missing Bluetooth address", details: nil))
                return true
            }
            guard hasBluetoothUsageDescription else {
                result(bluetoothUsageDescriptionMissingError())
                return true
            }
            connect(address: address)
            result(nil)
            return true
        case "sendClassicBluetoothClipboard":
            let args = call.arguments as? [String: Any]
            result(sendClipboard(args?["text"] as? String ?? ""))
            return true
        case "sendClassicBluetoothFrame":
            let args = call.arguments as? [String: Any]
            result(sendFrame(args?["payload"] as? String ?? "", sentMessage: nil))
            return true
        default:
            return false
        }
    }

    private func bluetoothUsageDescriptionMissingError() -> FlutterError {
        let message = "Flux 缺少 macOS 蓝牙隐私说明，系统会阻止经典蓝牙访问；请安装最新版本后再使用蓝牙模式。"
        emit(type: "error", message: message)
        return FlutterError(code: "BLUETOOTH_USAGE_DESCRIPTION_MISSING", message: message, details: nil)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        emit(type: "status", message: "经典蓝牙事件通道已连接")
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    private func listPairedDevices() -> [[String: String]] {
        let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        return devices.map { device in
            [
                "address": device.addressString ?? "",
                "name": device.nameOrAddress ?? device.addressString ?? ""
            ]
        }
    }

    private func startServer() -> Bool {
        notification?.unregister()
        serviceRecord?.remove()
        serviceRecord = publishSerialPortService()

        guard let serviceRecord else {
            return false
        }

        var channelID = BluetoothRFCOMMChannelID(0)
        if serviceRecord.getRFCOMMChannelID(&channelID) == kIOReturnSuccess, channelID > 0 {
            serviceChannelID = channelID
        }

        notification = IOBluetoothRFCOMMChannel.register(
            forChannelOpenNotifications: self,
            selector: #selector(rfcommChannelOpened(_:channel:)),
            withChannelID: serviceChannelID,
            direction: kIOBluetoothUserNotificationChannelDirectionIncoming
        )
        guard notification != nil else {
            serviceRecord.remove()
            self.serviceRecord = nil
            emit(type: "error", message: "经典蓝牙 RFCOMM 监听注册失败")
            return false
        }
        emit(type: "listening", message: "经典蓝牙 RFCOMM 常驻通道 \(serviceChannelID) 正在等待配对设备连接")
        return true
    }

    @objc private func rfcommChannelOpened(_ notification: IOBluetoothUserNotification, channel newChannel: IOBluetoothRFCOMMChannel) {
        attachOnMain(channel: newChannel, role: "server", generation: connectionGeneration)
    }

    private func connect(address: String) {
        guard let device = IOBluetoothDevice(addressString: address) else {
            emit(type: "error", message: "找不到蓝牙设备：\(address)")
            return
        }

        connectionGeneration += 1
        let generation = connectionGeneration
        DispatchQueue.global(qos: .userInitiated).async {
            var rfcommChannel: IOBluetoothRFCOMMChannel?
            let channelID = self.resolveRFCOMMChannelID(device: device)
            let result = device.openRFCOMMChannelSync(&rfcommChannel, withChannelID: channelID, delegate: self)
            if result == kIOReturnSuccess, let rfcommChannel {
                self.attachOnMain(channel: rfcommChannel, role: "client", generation: generation)
            } else {
                self.emit(type: "error", message: "经典蓝牙连接失败：\(result)，通道 \(channelID)")
            }
        }
    }

    private func attachOnMain(channel newChannel: IOBluetoothRFCOMMChannel, role: String, generation: Int) {
        DispatchQueue.main.async {
            guard self.connectionGeneration == generation else {
                newChannel.close()
                return
            }
            self.attach(channel: newChannel, role: role)
        }
    }

    private func attach(channel newChannel: IOBluetoothRFCOMMChannel, role: String) {
        let previousChannel = channel
        channel = newChannel
        previousChannel?.close()
        receiveData = Data()
        handshakeComplete = false
        activeRole = role
        newChannel.setDelegate(self)
        let device = newChannel.getDevice()
        activeAddress = device?.addressString ?? ""
        activeName = device?.nameOrAddress ?? activeAddress
        emit(type: "status", message: "经典蓝牙通道已打开，正在验证 Flux 对端")
        guard sendHandshake(newChannel, type: fluxBluetoothHello) else {
            newChannel.close()
            handleChannelClosed(newChannel, code: codeHandshakeSendFailed)
            emit(type: "error", message: "经典蓝牙握手发送失败")
            return
        }
    }

    private func sendClipboard(_ text: String) -> Bool {
        let payload = "{\"type\":\"\(fluxBluetoothMessage)\",\"text\":\(jsonString(text))}"
        return sendFrame(payload, sentMessage: "经典蓝牙剪切板已发送")
    }

    private func sendFrame(_ payload: String, sentMessage: String?) -> Bool {
        guard let channel else {
            emit(type: "error", message: "经典蓝牙未连接，无法发送剪切板或文件")
            return false
        }
        guard handshakeComplete else {
            emit(type: "error", message: "经典蓝牙尚未完成 Flux 协议握手，无法发送剪切板或文件")
            return false
        }
        return writeFrame(channel, payload: payload, sentMessage: sentMessage)
    }

    private func sendHandshake(_ channel: IOBluetoothRFCOMMChannel, type: String) -> Bool {
        return writeFrame(channel, payload: "{\"type\":\(jsonString(type)),\"v\":\(protocolVersion)}", sentMessage: nil)
    }

    private func writeFrame(_ channel: IOBluetoothRFCOMMChannel, payload: String, sentMessage: String?) -> Bool {
        guard self.channel == channel else {
            return false
        }
        let frame = payload.hasSuffix("\n") ? payload : "\(payload)\n"
        var bytes = Array(frame.utf8)
        let totalBytes = bytes.count
        let result = bytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return kIOReturnError
            }

            var offset = 0
            while offset < totalBytes {
                let chunkLength = min(maxWriteChunkSize, totalBytes - offset)
                let writeResult = channel.writeSync(baseAddress.advanced(by: offset), length: UInt16(chunkLength))
                if writeResult != kIOReturnSuccess {
                    return writeResult
                }
                offset += chunkLength
            }
            return kIOReturnSuccess
        }

        if result == kIOReturnSuccess {
            if let sentMessage {
                emit(type: "sent", message: sentMessage)
            }
            return true
        } else {
            emit(type: "error", message: "经典蓝牙发送失败：\(result)")
            return false
        }
    }

    private func stop() {
        connectionGeneration += 1
        notification?.unregister()
        notification = nil
        serviceRecord?.remove()
        serviceRecord = nil
        channel?.close()
        channel = nil
        receiveData = Data()
        handshakeComplete = false
        activeRole = ""
        activeAddress = ""
        activeName = ""
        emit(type: "stopped", message: "经典蓝牙已停止")
    }

    func rfcommChannelData(_ rfcommChannel: IOBluetoothRFCOMMChannel!, data dataPointer: UnsafeMutableRawPointer!, length dataLength: Int) {
        let data = Data(bytes: dataPointer, count: dataLength)
        DispatchQueue.main.async {
            self.handleData(data, from: rfcommChannel)
        }
    }

    private func handleData(_ data: Data, from rfcommChannel: IOBluetoothRFCOMMChannel) {
        guard channel == rfcommChannel else {
            return
        }
        // 以原始字节缓冲，避免多字节 UTF-8 被分块切断后整块丢弃。
        receiveData.append(data)
        while let newlineIndex = receiveData.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = receiveData[receiveData.startIndex..<newlineIndex]
            receiveData.removeSubrange(receiveData.startIndex...newlineIndex)
            guard let line = String(data: Data(lineData), encoding: .utf8) else {
                continue
            }
            handleLine(line, from: rfcommChannel)
        }
    }

    func rfcommChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel!) {
        DispatchQueue.main.async {
            self.handleChannelClosed(rfcommChannel)
        }
    }

    private func handleChannelClosed(_ rfcommChannel: IOBluetoothRFCOMMChannel, code: String = "DISCONNECTED") {
        guard channel == rfcommChannel else {
            return
        }
        channel = nil
        receiveData = Data()
        handshakeComplete = false
        activeRole = ""
        activeAddress = ""
        activeName = ""
        emit(type: "disconnected", message: "经典蓝牙连接已断开", extras: ["code": code])
    }

    private func handleLine(_ line: String, from rfcommChannel: IOBluetoothRFCOMMChannel) {
        if line.isEmpty {
            return
        }
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            rejectUnverifiedMessage(line, code: codePeerNotFlux, on: rfcommChannel)
            return
        }
        switch type {
        case fluxBluetoothHello:
            guard sendHandshake(rfcommChannel, type: fluxBluetoothHelloAck) else {
                rejectUnverifiedMessage("经典蓝牙握手确认发送失败", code: codeHandshakeAckSendFailed, on: rfcommChannel)
                return
            }
            confirmHandshake(rfcommChannel)
        case fluxBluetoothHelloAck:
            confirmHandshake(rfcommChannel)
        case fluxBluetoothMessage:
            guard handshakeComplete else {
                rejectUnverifiedMessage("经典蓝牙握手未完成，已拒绝未验证数据", code: codeHandshakeIncomplete, on: rfcommChannel)
                return
            }
            emit(type: "clipboard", message: json["text"] as? String ?? "")
        default:
            guard handshakeComplete else {
                rejectUnverifiedMessage("经典蓝牙连接的对端不是 Flux，已断开", code: codePeerNotFlux, on: rfcommChannel)
                return
            }
            emit(type: "message", message: line)
        }
    }

    private func confirmHandshake(_ activeChannel: IOBluetoothRFCOMMChannel) {
        guard channel == activeChannel, !handshakeComplete else {
            return
        }
        handshakeComplete = true
        let address = activeAddress
        let name = activeName
        let role = activeRole
        emit(
            type: "connected",
            message: name.isEmpty ? "经典蓝牙 Flux 握手完成（\(role)）" : "经典蓝牙 Flux 已连接：\(name)（\(role)）",
            extras: [
                "address": address,
                "name": name,
                "role": role
            ]
        )
    }

    private func rejectUnverifiedMessage(_ message: String, code: String, on rejectedChannel: IOBluetoothRFCOMMChannel?) {
        emit(type: "error", message: message)
        rejectedChannel?.close()
        emit(type: "disconnected", message: message, extras: ["code": code])
    }

    private func emit(type: String, message: String, extras: [String: String] = [:]) {
        DispatchQueue.main.async {
            self.eventSink?(["type": type, "message": message].merging(extras) { current, _ in current })
        }
    }

    private func publishSerialPortService() -> IOBluetoothSDPServiceRecord? {
        let serviceDict: [String: Any] = [
            "0001 - ServiceClassIDList": [
                IOBluetoothSDPUUID(uuid16: BluetoothSDPUUID16(kBluetoothSDPUUID16ServiceClassSerialPort.rawValue))
            ],
            "0004 - ProtocolDescriptorList": [
                [
                    IOBluetoothSDPUUID(uuid16: BluetoothSDPUUID16(kBluetoothSDPUUID16L2CAP))
                ],
                [
                    IOBluetoothSDPUUID(uuid16: BluetoothSDPUUID16(kBluetoothSDPUUID16RFCOMM)),
                    NSNumber(value: serviceChannelID)
                ]
            ],
            "0100 - ServiceName": "Flux Classic Bluetooth"
        ]

        guard let record = IOBluetoothSDPServiceRecord.publishedServiceRecord(with: serviceDict) else {
            emit(type: "error", message: "经典蓝牙 SPP 服务发布失败")
            return nil
        }
        return record
    }

    private func resolveRFCOMMChannelID(device: IOBluetoothDevice) -> BluetoothRFCOMMChannelID {
        device.performSDPQuery(nil, uuids: [serviceUuid as Any])
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let record = device.getServiceRecord(for: serviceUuid) {
                var channelID = BluetoothRFCOMMChannelID(0)
                if record.getRFCOMMChannelID(&channelID) == kIOReturnSuccess, channelID > 0 {
                    return channelID
                }
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        return BluetoothRFCOMMChannelID(1)
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return encoded
    }
}
