import 'dart:convert';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:common/model/stored_security_context.dart';
import 'package:convert/convert.dart';
import 'package:localsend_app/rust/api/crypto.dart' as rust;

/// Generates a random [SecurityContextResult].
StoredSecurityContext generateSecurityContext([AsymmetricKeyPair? keyPair]) {
  keyPair ??= CryptoUtils.generateRSAKeyPair();
  final privateKey = keyPair.privateKey as RSAPrivateKey;
  final publicKey = keyPair.publicKey as RSAPublicKey;
  final dn = {
    'CN': 'Flux User',
    'O': '',
    'OU': '',
    'L': '',
    'S': '',
    'C': '',
  };
  final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);
  final certificate = X509Utils.generateSelfSignedCertificate(keyPair.privateKey, csr, 365 * 10);

  final hash = calculateHashOfCertificate(certificate);
  final spki = extractPublicKeyFromCertificate(certificate);

  return StoredSecurityContext(
    privateKey: CryptoUtils.encodeRSAPrivateKeyToPemPkcs1(privateKey),
    publicKey: spki,
    certificate: certificate,
    certificateHash: hash,
  );
}

/// Calculates the hash of a certificate.
String calculateHashOfCertificate(String certificate) {
  // Convert PEM to DER
  final pemContent = certificate.replaceAll('\r\n', '\n').split('\n').where((line) => line.isNotEmpty && !line.startsWith('---')).join();
  final der = base64Decode(pemContent);

  // Calculate hash
  return CryptoUtils.getHash(
    Uint8List.fromList(der),
    algorithmName: 'SHA-256',
  );
}

String extractPublicKeyFromCertificate(String certificate) {
  final cert = X509Utils.x509CertificateFromPem(certificate);
  final publicHex = cert.tbsCertificate!.subjectPublicKeyInfo.bytes!;
  return _hexToSpkiPem(publicHex);
}

String _hexToSpkiPem(String hexBytes) {
  final publicBytes = hex.decode(hexBytes);
  final publicBase64 = base64Encode(publicBytes);
  final temp =
      '''-----BEGIN PUBLIC KEY-----
$publicBase64
-----END PUBLIC KEY-----''';
  return X509Utils.fixPem(temp);
}

/// 校验证书 DER 字节的 SHA-256 指纹是否与预期一致（LocalSend 协议中设备指纹即证书哈希）。
/// 预期指纹为空时放行（手动输入且未完成注册的对端）。
bool matchesCertificateBytes({required Uint8List der, required String expectedFingerprint}) {
  if (expectedFingerprint.trim().isEmpty) {
    return true;
  }
  final hash = CryptoUtils.getHash(der, algorithmName: 'SHA-256');
  return hash.toLowerCase() == expectedFingerprint.trim().toLowerCase();
}

/// Verifies a certificate with a public key.
/// Throws an exception if the certificate is invalid.
Future<void> verifyCertificate({
  required String cert,
  required String publicKey,
}) async {
  await rust.verifyCert(cert: cert, publicKey: publicKey);
}
