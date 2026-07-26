import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'nearby_devices_state.mapper.dart';

@MappableClass()
class NearbyDevicesState with NearbyDevicesStateMappable {
  final bool runningFavoriteScan;
  final Set<String> runningIps; // list of local ips
  final Map<String, Device> devices; // ip -> device

  /// Devices that are discovered via signaling server.
  /// The key is the fingerprint of the device.
  /// We do not trust the fingerprint, so we allow multiple devices with the same fingerprint.
  final Map<String, Set<Device>> signalingDevices;

  const NearbyDevicesState({
    required this.runningFavoriteScan,
    required this.runningIps,
    required this.devices,
    required this.signalingDevices,
  });

  Map<String, Device> get allDevices {
    final byFingerprint = <String, Device>{};
    final withoutFingerprint = <String, Device>{};

    for (final device in devices.values) {
      if (device.fingerprint.isEmpty) {
        withoutFingerprint[device.ip ?? device.signalingId ?? device.alias] = device;
        continue;
      }

      byFingerprint.update(
        device.fingerprint,
        (current) => current.merge(device),
        ifAbsent: () => device,
      );
    }

    for (final devices in signalingDevices.values) {
      for (final device in devices) {
        if (device.fingerprint.isEmpty) {
          withoutFingerprint[device.ip ?? device.signalingId ?? device.alias] = device;
          continue;
        }

        byFingerprint.update(
          device.fingerprint,
          (current) => current.merge(device),
          ifAbsent: () => device,
        );
      }
    }

    return {
      ...withoutFingerprint,
      for (final device in byFingerprint.values) device.ip ?? device.signalingId ?? device.fingerprint: device,
    };
  }
}

extension on Device {
  Device merge(Device other) {
    final primary = other.ip != null ? other : (ip != null ? this : other);
    final secondary = primary == this ? other : this;

    return Device(
      signalingId: primary.signalingId ?? secondary.signalingId,
      ip: primary.ip ?? secondary.ip,
      version: primary.version.isNotEmpty ? primary.version : secondary.version,
      port: primary.port >= 0 ? primary.port : secondary.port,
      https: primary.https,
      fingerprint: primary.fingerprint.isNotEmpty ? primary.fingerprint : secondary.fingerprint,
      alias: primary.alias.isNotEmpty ? primary.alias : secondary.alias,
      deviceModel: primary.deviceModel ?? secondary.deviceModel,
      deviceType: primary.deviceType,
      download: primary.download || secondary.download,
      discoveryMethods: {
        ...discoveryMethods,
        ...other.discoveryMethods,
      },
    );
  }
}
