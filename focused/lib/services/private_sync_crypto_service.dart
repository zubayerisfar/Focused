import 'dart:convert';

import 'package:cryptography/cryptography.dart';

class EncryptedEnvelope {
  const EncryptedEnvelope({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, dynamic> toMap() {
    return {
      'nonce': base64UrlEncode(nonce),
      'cipherText': base64UrlEncode(cipherText),
      'mac': base64UrlEncode(mac),
    };
  }

  factory EncryptedEnvelope.fromMap(
    Map<String, dynamic> map,
  ) {
    final nonce = map['nonce'];
    final cipherText = map['cipherText'];
    final mac = map['mac'];

    if (nonce is! String ||
        cipherText is! String ||
        mac is! String) {
      throw const FormatException(
        'Invalid encrypted envelope.',
      );
    }

    return EncryptedEnvelope(
      nonce: base64Url.decode(nonce),
      cipherText: base64Url.decode(cipherText),
      mac: base64Url.decode(mac),
    );
  }

  SecretBox toSecretBox() {
    return SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(mac),
    );
  }
}

class GeneratedPrivateKey {
  const GeneratedPrivateKey({
    required this.formattedKey,
    required this.masterKeyBytes,
  });

  final String formattedKey;
  final List<int> masterKeyBytes;
}

class PrivateSyncCryptoService {
  static const String keyPrefix = 'FCS1';

  static const String _base32Alphabet =
      '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Hkdf _hkdf = Hkdf(
    hmac: Hmac.sha256(),
    outputLength: 32,
  );
  final Sha256 _sha256 = Sha256();

  Future<GeneratedPrivateKey> generateMasterKey() async {
    final secretKey = await _aesGcm.newSecretKey();
    final bytes = await secretKey.extractBytes();

    return GeneratedPrivateKey(
      formattedKey: await formatMasterKey(bytes),
      masterKeyBytes: List<int>.unmodifiable(bytes),
    );
  }

  Future<List<int>> generateDataKey() async {
    final key = await _aesGcm.newSecretKey();
    return List<int>.unmodifiable(
      await key.extractBytes(),
    );
  }

  Future<String> formatMasterKey(
    List<int> masterKeyBytes,
  ) async {
    _require256BitKey(masterKeyBytes, 'masterKeyBytes');

    final body = _base32Encode(masterKeyBytes);
    final checksum = await _checksum(masterKeyBytes);
    final joined = '$body$checksum';

    final groups = <String>[];
    for (var index = 0;
        index < joined.length;
        index += 4) {
      final end = index + 4 < joined.length
          ? index + 4
          : joined.length;
      groups.add(joined.substring(index, end));
    }

    return '$keyPrefix-${groups.join('-')}';
  }

  Future<List<int>> parseMasterKey(
    String formattedKey,
  ) async {
    var normalized =
        formattedKey.toUpperCase().replaceAll(
              RegExp(r'[\s\-]'),
              '',
            );

    if (!normalized.startsWith(keyPrefix)) {
      throw const FormatException(
        'Focused private key must start with FCS1.',
      );
    }

    normalized = normalized.substring(
      keyPrefix.length,
    );

    // 52 Base32 chars for 256 bits + 4 checksum chars.
    if (normalized.length != 56) {
      throw const FormatException(
        'Focused private key has the wrong length.',
      );
    }

    final body = normalized.substring(0, 52);
    final suppliedChecksum =
        normalized.substring(52);

    final masterKeyBytes = _base32Decode(body);

    _require256BitKey(
      masterKeyBytes,
      'Focused private key',
    );

    final expectedChecksum =
        await _checksum(masterKeyBytes);

    if (suppliedChecksum != expectedChecksum) {
      throw const FormatException(
        'Focused private key checksum is invalid.',
      );
    }

    return List<int>.unmodifiable(masterKeyBytes);
  }

  Future<EncryptedEnvelope> wrapDataKey({
    required List<int> masterKeyBytes,
    required List<int> dataKeyBytes,
  }) async {
    _require256BitKey(masterKeyBytes, 'masterKeyBytes');
    _require256BitKey(dataKeyBytes, 'dataKeyBytes');

    final wrappingKey = await _deriveKey(
      masterKeyBytes,
      purpose: 'focused/private-sync/data-key-wrap/v1',
    );

    return encryptBytes(
      clearText: dataKeyBytes,
      keyBytes: wrappingKey,
    );
  }

  Future<List<int>> unwrapDataKey({
    required List<int> masterKeyBytes,
    required EncryptedEnvelope wrappedDataKey,
  }) async {
    _require256BitKey(masterKeyBytes, 'masterKeyBytes');

    final wrappingKey = await _deriveKey(
      masterKeyBytes,
      purpose: 'focused/private-sync/data-key-wrap/v1',
    );

    final dataKeyBytes = await decryptBytes(
      envelope: wrappedDataKey,
      keyBytes: wrappingKey,
    );

    _require256BitKey(dataKeyBytes, 'unwrapped data key');
    return dataKeyBytes;
  }

  Future<EncryptedEnvelope> createKeyCheck({
    required String uid,
    required List<int> masterKeyBytes,
  }) async {
    final verificationKey = await _deriveKey(
      masterKeyBytes,
      purpose: 'focused/private-sync/key-check/v1',
    );

    return encryptBytes(
      clearText: utf8.encode(_keyCheckMessage(uid)),
      keyBytes: verificationKey,
    );
  }

  Future<bool> verifyKeyCheck({
    required String uid,
    required List<int> masterKeyBytes,
    required EncryptedEnvelope keyCheck,
  }) async {
    try {
      final verificationKey = await _deriveKey(
        masterKeyBytes,
        purpose: 'focused/private-sync/key-check/v1',
      );

      final clearText = await decryptBytes(
        envelope: keyCheck,
        keyBytes: verificationKey,
      );

      return utf8.decode(clearText) ==
          _keyCheckMessage(uid);
    } catch (_) {
      return false;
    }
  }

  Future<EncryptedEnvelope> encryptBytes({
    required List<int> clearText,
    required List<int> keyBytes,
  }) async {
    _require256BitKey(keyBytes, 'keyBytes');

    final secretBox = await _aesGcm.encrypt(
      clearText,
      secretKey: SecretKey(keyBytes),
    );

    return EncryptedEnvelope(
      nonce: List<int>.unmodifiable(secretBox.nonce),
      cipherText:
          List<int>.unmodifiable(secretBox.cipherText),
      mac: List<int>.unmodifiable(
        secretBox.mac.bytes,
      ),
    );
  }

  Future<List<int>> decryptBytes({
    required EncryptedEnvelope envelope,
    required List<int> keyBytes,
  }) {
    _require256BitKey(keyBytes, 'keyBytes');

    return _aesGcm.decrypt(
      envelope.toSecretBox(),
      secretKey: SecretKey(keyBytes),
    );
  }

  Future<String> sha256Hex(List<int> bytes) async {
    final hash = await _sha256.hash(bytes);

    return hash.bytes
        .map(
          (value) =>
              value.toRadixString(16).padLeft(2, '0'),
        )
        .join();
  }

  Future<String> snapshotTag({
    required String clearTextHash,
    required List<int> dataKeyBytes,
  }) async {
    _require256BitKey(dataKeyBytes, 'dataKeyBytes');

    final mac = await Hmac.sha256().calculateMac(
      utf8.encode(
        'focused/private-sync/snapshot-tag/v1:$clearTextHash',
      ),
      secretKey: SecretKey(dataKeyBytes),
    );

    return base64UrlEncode(mac.bytes);
  }

  Future<List<int>> _deriveKey(
    List<int> masterKeyBytes, {
    required String purpose,
  }) async {
    _require256BitKey(masterKeyBytes, 'masterKeyBytes');

    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(masterKeyBytes),
      nonce: utf8.encode(
        'focused-private-sync-hkdf-salt-v1',
      ),
      info: utf8.encode(purpose),
    );

    return derived.extractBytes();
  }

  Future<String> _checksum(
    List<int> masterKeyBytes,
  ) async {
    final digest = await _sha256.hash(masterKeyBytes);

    // Four Crockford Base32 characters = 20 check bits.
    return _base32Encode(
      digest.bytes.sublist(0, 3),
    ).substring(0, 4);
  }

  String _keyCheckMessage(String uid) {
    return 'focused-private-sync-key-check-v1:$uid';
  }

  static void _require256BitKey(
    List<int> bytes,
    String name,
  ) {
    if (bytes.length != 32) {
      throw ArgumentError(
        '$name must contain exactly 32 bytes.',
      );
    }
  }

  static String _base32Encode(List<int> bytes) {
    var buffer = 0;
    var bitsInBuffer = 0;
    final output = StringBuffer();

    for (final byte in bytes) {
      buffer = (buffer << 8) | (byte & 0xff);
      bitsInBuffer += 8;

      while (bitsInBuffer >= 5) {
        bitsInBuffer -= 5;
        final index =
            (buffer >> bitsInBuffer) & 0x1f;
        output.write(_base32Alphabet[index]);

        if (bitsInBuffer == 0) {
          buffer = 0;
        } else {
          buffer &= (1 << bitsInBuffer) - 1;
        }
      }
    }

    if (bitsInBuffer > 0) {
      final index =
          (buffer << (5 - bitsInBuffer)) & 0x1f;
      output.write(_base32Alphabet[index]);
    }

    return output.toString();
  }

  static List<int> _base32Decode(String value) {
    var buffer = 0;
    var bitsInBuffer = 0;
    final output = <int>[];

    for (final rawCharacter in value.codeUnits) {
      var character =
          String.fromCharCode(rawCharacter)
              .toUpperCase();

      // Friendly Crockford aliases for common typing mistakes.
      if (character == 'O') character = '0';
      if (character == 'I' || character == 'L') {
        character = '1';
      }

      final index =
          _base32Alphabet.indexOf(character);

      if (index < 0) {
        throw FormatException(
          'Invalid character "$character" in Focused private key.',
        );
      }

      buffer = (buffer << 5) | index;
      bitsInBuffer += 5;

      while (bitsInBuffer >= 8) {
        bitsInBuffer -= 8;
        output.add(
          (buffer >> bitsInBuffer) & 0xff,
        );

        if (bitsInBuffer == 0) {
          buffer = 0;
        } else {
          buffer &= (1 << bitsInBuffer) - 1;
        }
      }
    }

    if (bitsInBuffer > 0 && buffer != 0) {
      throw const FormatException(
        'Focused private key has invalid padding.',
      );
    }

    return output;
  }
}
