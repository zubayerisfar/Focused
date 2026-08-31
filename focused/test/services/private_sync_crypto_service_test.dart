import 'package:flutter_test/flutter_test.dart';
import 'package:focused/services/private_sync_crypto_service.dart';

void main() {
  group('PrivateSyncCryptoService', () {
    final crypto = PrivateSyncCryptoService();

    test('generated FCS1 key round-trips to the same 256-bit secret',
        () async {
      final generated = await crypto.generateMasterKey();

      expect(
        generated.formattedKey.startsWith('FCS1-'),
        isTrue,
      );

      final decoded = await crypto.parseMasterKey(
        generated.formattedKey,
      );

      expect(decoded, generated.masterKeyBytes);
      expect(decoded.length, 32);
    });

    test('checksum detects a mistyped private key', () async {
      final generated = await crypto.generateMasterKey();
      final original = generated.formattedKey;

      final replacement =
          original.endsWith('0') ? '1' : '0';

      final mistyped =
          '${original.substring(0, original.length - 1)}$replacement';

      await expectLater(
        crypto.parseMasterKey(mistyped),
        throwsA(isA<FormatException>()),
      );
    });

    test('wrapped data key unwraps with the correct master key',
        () async {
      final master = await crypto.generateMasterKey();
      final dataKey = await crypto.generateDataKey();

      final wrapped = await crypto.wrapDataKey(
        masterKeyBytes: master.masterKeyBytes,
        dataKeyBytes: dataKey,
      );

      final unwrapped = await crypto.unwrapDataKey(
        masterKeyBytes: master.masterKeyBytes,
        wrappedDataKey: wrapped,
      );

      expect(unwrapped, dataKey);
    });

    test('wrong master key cannot unwrap the data key', () async {
      final masterA = await crypto.generateMasterKey();
      final masterB = await crypto.generateMasterKey();
      final dataKey = await crypto.generateDataKey();

      final wrapped = await crypto.wrapDataKey(
        masterKeyBytes: masterA.masterKeyBytes,
        dataKeyBytes: dataKey,
      );

      await expectLater(
        crypto.unwrapDataKey(
          masterKeyBytes: masterB.masterKeyBytes,
          wrappedDataKey: wrapped,
        ),
        throwsA(anything),
      );
    });

    test('AES-GCM snapshot encryption round-trips', () async {
      final dataKey = await crypto.generateDataKey();
      final clearText = List<int>.generate(
        2048,
        (index) => index % 251,
      );

      final encrypted = await crypto.encryptBytes(
        clearText: clearText,
        keyBytes: dataKey,
      );

      expect(encrypted.cipherText, isNot(clearText));

      final decrypted = await crypto.decryptBytes(
        envelope: encrypted,
        keyBytes: dataKey,
      );

      expect(decrypted, clearText);
    });

    test('key check binds a key to the Firebase uid', () async {
      final generated = await crypto.generateMasterKey();

      final check = await crypto.createKeyCheck(
        uid: 'user-a',
        masterKeyBytes: generated.masterKeyBytes,
      );

      expect(
        await crypto.verifyKeyCheck(
          uid: 'user-a',
          masterKeyBytes: generated.masterKeyBytes,
          keyCheck: check,
        ),
        isTrue,
      );

      expect(
        await crypto.verifyKeyCheck(
          uid: 'user-b',
          masterKeyBytes: generated.masterKeyBytes,
          keyCheck: check,
        ),
        isFalse,
      );
    });
  });
}
