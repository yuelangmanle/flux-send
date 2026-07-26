class AddressInputTarget {
  final String host;
  final int port;

  const AddressInputTarget({
    required this.host,
    required this.port,
  });
}

AddressInputTarget parseAddressInput(String input, {required int fallbackPort}) {
  final trimmed = normalizeAddressInput(input);
  final uri = Uri.tryParse(trimmed.contains('://') ? trimmed : 'flux://$trimmed');

  if (uri != null && uri.host.isNotEmpty) {
    return AddressInputTarget(
      host: uri.host,
      port: uri.hasPort ? uri.port : fallbackPort,
    );
  }

  return AddressInputTarget(
    host: trimmed,
    port: fallbackPort,
  );
}

bool looksLikeFullAddressInput(String input) {
  final trimmed = normalizeAddressInput(input);
  if (trimmed.contains('://')) {
    final uri = Uri.tryParse(trimmed);
    return uri != null && uri.host.isNotEmpty;
  }

  if (_looksLikeIpv6AddressInput(trimmed)) {
    return true;
  }

  return RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}(?::\d{1,5})?$').hasMatch(trimmed) ||
      RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?::\d{1,5})?$').hasMatch(trimmed);
}

String normalizeAddressInput(String input) {
  return input.trim().replaceAll('：', ':').replaceAll(RegExp(r'\s*:\s*'), ':');
}

bool _looksLikeIpv6AddressInput(String input) {
  final bracketed = RegExp(r'^\[([^\]]+)\](?::\d{1,5})?$').firstMatch(input);
  final host = bracketed?.group(1) ?? input;
  if (host.contains('[') || host.contains(']')) {
    return false;
  }

  final addressPart = host.split('%').first;
  if (addressPart.split(':').length < 3) {
    return false;
  }

  return RegExp(r'^[0-9a-fA-F:.]+$').hasMatch(addressPart);
}
