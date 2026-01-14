import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

class NTLMFlags {
  static const int negotiateUnicode = 0x00000001;
  static const int negotiateOEM = 0x00000002;
  static const int requestTarget = 0x00000004;
  static const int unknown9 = 0x00000008;
  static const int negotiateSign = 0x00000010;
  static const int negotiateSeal = 0x00000020;
  static const int negotiateDatagram = 0x00000040;
  static const int negotiateLanManagerKey = 0x00000080;
  static const int unknown8 = 0x00000100;
  static const int negotiateNTLM = 0x00000200;
  static const int negotiateNTOnly = 0x00000400;
  static const int anonymous = 0x00000800;
  static const int negotiateOemDomainSupplied = 0x00001000;
  static const int negotiateOemWorkstationSupplied = 0x00002000;
  static const int unknown6 = 0x00004000;
  static const int negotiateAlwaysSign = 0x00008000;
  static const int targetTypeDomain = 0x00010000;
  static const int targetTypeServer = 0x00020000;
  static const int targetTypeShare = 0x00040000;
  static const int negotiateExtendedSecurity = 0x00080000;
  static const int negotiateIdentify = 0x00100000;
  static const int unknown5 = 0x00200000;
  static const int requestNonNTSessionKey = 0x00400000;
  static const int negotiateTargetInfo = 0x00800000;
  static const int unknown4 = 0x01000000;
  static const int negotiateVersion = 0x02000000;
  static const int unknown3 = 0x04000000;
  static const int unknown2 = 0x08000000;
  static const int unknown1 = 0x10000000;
  static const int negotiate128 = 0x20000000;
  static const int negotiateKeyExchange = 0x40000000;
  static const int negotiate56 = 0x80000000;

  static int get type1Flags =>
      negotiateUnicode +
      negotiateOEM +
      requestTarget +
      negotiateNTLM +
      negotiateOemDomainSupplied +
      negotiateOemWorkstationSupplied +
      negotiateAlwaysSign +
      negotiateExtendedSecurity +
      negotiateVersion +
      negotiate128 +
      negotiate56;

  static int get type2Flags =>
      negotiateUnicode +
      requestTarget +
      negotiateNTLM +
      negotiateAlwaysSign +
      negotiateExtendedSecurity +
      negotiateTargetInfo +
      negotiateVersion +
      negotiate128 +
      negotiate56;
}

class Type2Message {
  late Uint8List signature;
  late int type;
  late int targetNameLen;
  late int targetNameMaxLen;
  late int targetNameOffset;
  late Uint8List targetName;
  late int negotiateFlags;
  late Uint8List serverChallenge;
  late Uint8List reserved;
  int? targetInfoLen;
  int? targetInfoMaxLen;
  int? targetInfoOffset;
  Uint8List? targetInfo;
}

class NTLM {
  static String createType1Message({
    String domain = '',
    String workstation = '',
  }) {
    domain = Uri.encodeComponent(domain.toUpperCase());
    workstation = Uri.encodeComponent(workstation.toUpperCase());
    const protocol = 'NTLMSSP\x00';
    const bodyLength = 40;

    var type1flags = NTLMFlags.type1Flags;
    if (domain.isEmpty) {
      type1flags = type1flags - NTLMFlags.negotiateOemDomainSupplied;
    }

    final domainBytes = ascii.encode(domain);
    final workstationBytes = ascii.encode(workstation);
    final buf = ByteData(
      bodyLength + domainBytes.length + workstationBytes.length,
    );
    var pos = 0;

    // Protocol
    final protocolBytes = ascii.encode(protocol);
    for (var i = 0; i < protocolBytes.length; i++) {
      buf.setUint8(pos++, protocolBytes[i]);
    }

    // Type 1
    buf.setUint32(pos, 1, Endian.little);
    pos += 4;

    // TYPE1 flags
    buf.setUint32(pos, type1flags, Endian.little);
    pos += 4;

    // Domain length
    buf.setUint16(pos, domainBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, domainBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(pos, bodyLength + workstationBytes.length, Endian.little);
    pos += 4;

    // Workstation length
    buf.setUint16(pos, workstationBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, workstationBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(pos, bodyLength, Endian.little);
    pos += 4;

    // Version info
    buf.setUint8(pos++, 5); // ProductMajorVersion
    buf.setUint8(pos++, 1); // ProductMinorVersion
    buf.setUint16(pos, 2600, Endian.little);
    pos += 2;
    buf.setUint8(pos++, 0); // VersionReserved1
    buf.setUint8(pos++, 0); // VersionReserved2
    buf.setUint8(pos++, 0); // VersionReserved3
    buf.setUint8(pos++, 15); // NTLMRevisionCurrent

    // Write workstation and domain
    final bytes = buf.buffer.asUint8List();
    if (workstationBytes.isNotEmpty) {
      bytes.setRange(pos, pos + workstationBytes.length, workstationBytes);
      pos += workstationBytes.length;
    }
    if (domainBytes.isNotEmpty) {
      bytes.setRange(pos, pos + domainBytes.length, domainBytes);
    }

    return 'NTLM ${base64.encode(bytes)}';
  }

  static Type2Message? parseType2Message(String rawMsg) {
    final match = RegExp(r'NTLM (.+)?').firstMatch(rawMsg);
    if (match == null || match.group(1) == null) {
      throw Exception(
        "Couldn't find NTLM in the message type2 coming from the server",
      );
    }

    final buf = base64.decode(match.group(1)!);
    final byteData = ByteData.sublistView(Uint8List.fromList(buf));
    final msg = Type2Message();

    msg.signature = Uint8List.fromList(buf.sublist(0, 8));
    msg.type = byteData.getInt16(8, Endian.little);

    if (msg.type != 2) {
      throw Exception("Server didn't return a type 2 message");
    }

    msg.targetNameLen = byteData.getInt16(12, Endian.little);
    msg.targetNameMaxLen = byteData.getInt16(14, Endian.little);
    msg.targetNameOffset = byteData.getInt32(16, Endian.little);
    msg.targetName = Uint8List.fromList(
      buf.sublist(
        msg.targetNameOffset,
        msg.targetNameOffset + msg.targetNameMaxLen,
      ),
    );

    msg.negotiateFlags = byteData.getInt32(20, Endian.little);
    msg.serverChallenge = Uint8List.fromList(buf.sublist(24, 32));
    msg.reserved = Uint8List.fromList(buf.sublist(32, 40));

    if (msg.negotiateFlags & NTLMFlags.negotiateTargetInfo != 0) {
      msg.targetInfoLen = byteData.getInt16(40, Endian.little);
      msg.targetInfoMaxLen = byteData.getInt16(42, Endian.little);
      msg.targetInfoOffset = byteData.getInt32(44, Endian.little);
      msg.targetInfo = Uint8List.fromList(
        buf.sublist(
          msg.targetInfoOffset!,
          msg.targetInfoOffset! + msg.targetInfoLen!,
        ),
      );
    }

    return msg;
  }

  static String createType3Message(
    Type2Message msg2, {
    String domain = '',
    String workstation = '',
    required String username,
    required String password,
    Uint8List? lmPassword,
    Uint8List? ntPassword,
  }) {
    final nonce = msg2.serverChallenge;
    final negotiateFlags = msg2.negotiateFlags;

    final isUnicode = negotiateFlags & NTLMFlags.negotiateUnicode != 0;
    final isNegotiateExtendedSecurity =
        negotiateFlags & NTLMFlags.negotiateExtendedSecurity != 0;

    const bodyLength = 72;

    final domainName = Uri.encodeComponent(domain.toUpperCase());
    final workstationName = Uri.encodeComponent(workstation.toUpperCase());

    late Uint8List workstationBytes, domainNameBytes, usernameBytes;
    final encryptedRandomSessionKeyBytes = Uint8List(0);

    if (isUnicode) {
      workstationBytes = _encodeUtf16Le(workstationName);
      domainNameBytes = _encodeUtf16Le(domainName);
      usernameBytes = _encodeUtf16Le(username);
    } else {
      workstationBytes = ascii.encode(workstationName);
      domainNameBytes = ascii.encode(domainName);
      usernameBytes = ascii.encode(username);
    }

    var lmChallengeResponse = _calcResp(
      lmPassword ?? _createLMHashedPasswordV1(password),
      nonce,
    );
    var ntChallengeResponse = _calcResp(
      ntPassword ?? _createNTHashedPasswordV1(password),
      nonce,
    );

    if (isNegotiateExtendedSecurity) {
      final pwhash = ntPassword ?? _createNTHashedPasswordV1(password);
      final clientChallenge = _generateClientChallenge();

      if (msg2.targetInfo != null) {
        final responses = _calcNTLMv2Resp(
          pwhash,
          username,
          domainName,
          msg2.targetInfo!,
          nonce,
          clientChallenge,
        );
        lmChallengeResponse = responses['lm']!;
        ntChallengeResponse = responses['nt']!;
      } else {
        final responses = _ntlm2srCalcResp(pwhash, nonce, clientChallenge);
        lmChallengeResponse = responses['lm']!;
        ntChallengeResponse = responses['nt']!;
      }
    }

    const signature = 'NTLMSSP\x00';
    final totalLength =
        bodyLength +
        domainNameBytes.length +
        usernameBytes.length +
        workstationBytes.length +
        lmChallengeResponse.length +
        ntChallengeResponse.length +
        encryptedRandomSessionKeyBytes.length;

    final buf = ByteData(totalLength);
    var pos = 0;

    // Signature
    final signatureBytes = ascii.encode(signature);
    for (var i = 0; i < signatureBytes.length; i++) {
      buf.setUint8(pos++, signatureBytes[i]);
    }

    // Type 3
    buf.setUint32(pos, 3, Endian.little);
    pos += 4;

    // LM Challenge Response
    buf.setUint16(pos, lmChallengeResponse.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, lmChallengeResponse.length, Endian.little);
    pos += 2;
    buf.setUint32(
      pos,
      bodyLength +
          domainNameBytes.length +
          usernameBytes.length +
          workstationBytes.length,
      Endian.little,
    );
    pos += 4;

    // NT Challenge Response
    buf.setUint16(pos, ntChallengeResponse.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, ntChallengeResponse.length, Endian.little);
    pos += 2;
    buf.setUint32(
      pos,
      bodyLength +
          domainNameBytes.length +
          usernameBytes.length +
          workstationBytes.length +
          lmChallengeResponse.length,
      Endian.little,
    );
    pos += 4;

    // Domain Name
    buf.setUint16(pos, domainNameBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, domainNameBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(pos, bodyLength, Endian.little);
    pos += 4;

    // User Name
    buf.setUint16(pos, usernameBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, usernameBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(pos, bodyLength + domainNameBytes.length, Endian.little);
    pos += 4;

    // Workstation
    buf.setUint16(pos, workstationBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, workstationBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(
      pos,
      bodyLength + domainNameBytes.length + usernameBytes.length,
      Endian.little,
    );
    pos += 4;

    // Encrypted Random Session Key
    buf.setUint16(pos, encryptedRandomSessionKeyBytes.length, Endian.little);
    pos += 2;
    buf.setUint16(pos, encryptedRandomSessionKeyBytes.length, Endian.little);
    pos += 2;
    buf.setUint32(
      pos,
      bodyLength +
          domainNameBytes.length +
          usernameBytes.length +
          workstationBytes.length +
          lmChallengeResponse.length +
          ntChallengeResponse.length,
      Endian.little,
    );
    pos += 4;

    // Flags
    final flagsToWrite = isUnicode
        ? NTLMFlags.type2Flags
        : NTLMFlags.type2Flags - NTLMFlags.negotiateUnicode;
    buf.setUint32(pos, flagsToWrite, Endian.little);
    pos += 4;

    // Version
    buf.setUint8(pos++, 5);
    buf.setUint8(pos++, 1);
    buf.setUint16(pos, 2600, Endian.little);
    pos += 2;
    buf.setUint8(pos++, 0);
    buf.setUint8(pos++, 0);
    buf.setUint8(pos++, 0);
    buf.setUint8(pos++, 15);

    // Copy data
    final bytes = buf.buffer.asUint8List();
    bytes.setRange(pos, pos + domainNameBytes.length, domainNameBytes);
    pos += domainNameBytes.length;
    bytes.setRange(pos, pos + usernameBytes.length, usernameBytes);
    pos += usernameBytes.length;
    bytes.setRange(pos, pos + workstationBytes.length, workstationBytes);
    pos += workstationBytes.length;
    bytes.setRange(pos, pos + lmChallengeResponse.length, lmChallengeResponse);
    pos += lmChallengeResponse.length;
    bytes.setRange(pos, pos + ntChallengeResponse.length, ntChallengeResponse);

    return 'NTLM ${base64.encode(bytes)}';
  }

  // Helper methods
  static Uint8List _encodeUtf16Le(String text) {
    final units = text.codeUnits;
    final bytes = Uint8List(units.length * 2);
    for (var i = 0; i < units.length; i++) {
      bytes[i * 2] = units[i] & 0xFF;
      bytes[i * 2 + 1] = (units[i] >> 8) & 0xFF;
    }
    return bytes;
  }

  static Uint8List _generateClientChallenge() {
    final random = SecureRandom('Fortuna');
    final seed = Uint8List(32);
    for (var i = 0; i < 32; i++) {
      seed[i] = DateTime.now().millisecondsSinceEpoch % 256;
    }
    random.seed(KeyParameter(seed));

    final challenge = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      challenge[i] = random.nextUint8();
    }
    return challenge;
  }

  static Uint8List _createLMHashedPasswordV1(String password) {
    password = password.toUpperCase();
    final passwordBytes = ascii.encode(password);

    final passwordBytesPadded = Uint8List(14);
    final sourceEnd = passwordBytes.length < 14 ? passwordBytes.length : 14;
    passwordBytesPadded.setRange(0, sourceEnd, passwordBytes);

    final firstPart = passwordBytesPadded.sublist(0, 7);
    final secondPart = passwordBytesPadded.sublist(7);

    final firstPartEncrypted = _desEncrypt(firstPart);
    final secondPartEncrypted = _desEncrypt(secondPart);

    return Uint8List.fromList([...firstPartEncrypted, ...secondPartEncrypted]);
  }

  static Uint8List _desEncrypt(Uint8List buf) {
    final key = _insertZerosEvery7Bits(buf);

    // Use DES in ECB mode
    final params = KeyParameter(key);
    final cipher = DESedeEngine();
    cipher.init(true, params);

    final magicKey = ascii.encode('KGS!@#\$%');
    final encrypted = Uint8List(8);
    cipher.processBlock(magicKey, 0, encrypted, 0);

    return encrypted;
  }

  static Uint8List _insertZerosEvery7Bits(Uint8List buf) {
    final binaryArray = _bytes2BinaryArray(buf);
    final newBinaryArray = <int>[];

    for (var i = 0; i < binaryArray.length; i++) {
      newBinaryArray.add(binaryArray[i]);
      if ((i + 1) % 7 == 0) {
        newBinaryArray.add(0);
      }
    }

    return _binaryArray2Bytes(newBinaryArray);
  }

  static List<int> _bytes2BinaryArray(Uint8List buf) {
    final array = <int>[];
    for (var byte in buf) {
      for (var i = 7; i >= 0; i--) {
        array.add((byte >> i) & 1);
      }
    }
    return array;
  }

  static Uint8List _binaryArray2Bytes(List<int> array) {
    final bufArray = <int>[];

    for (var i = 0; i < array.length; i += 8) {
      if (i + 7 >= array.length) break;

      var byte = 0;
      for (var j = 0; j < 8; j++) {
        byte = (byte << 1) | array[i + j];
      }
      bufArray.add(byte);
    }

    return Uint8List.fromList(bufArray);
  }

  static Uint8List _createNTHashedPasswordV1(String password) {
    final buf = _encodeUtf16Le(password);

    // Correct way to use MD4 from pointycastle
    final md4digest = MD4Digest();
    md4digest.update(buf, 0, buf.length);
    final hash = Uint8List(md4digest.digestSize);
    md4digest.doFinal(hash, 0);

    return hash;
  }

  static Uint8List _calcResp(
    Uint8List passwordHash,
    Uint8List serverChallenge,
  ) {
    final passHashPadded = Uint8List(21);
    passHashPadded.setRange(0, passwordHash.length, passwordHash);

    final resArray = <Uint8List>[];

    final cipher1 = DESedeEngine();
    cipher1.init(
      true,
      KeyParameter(_insertZerosEvery7Bits(passHashPadded.sublist(0, 7))),
    );
    final res1 = Uint8List(8);
    cipher1.processBlock(serverChallenge.sublist(0, 8), 0, res1, 0);
    resArray.add(res1);

    final cipher2 = DESedeEngine();
    cipher2.init(
      true,
      KeyParameter(_insertZerosEvery7Bits(passHashPadded.sublist(7, 14))),
    );
    final res2 = Uint8List(8);
    cipher2.processBlock(serverChallenge.sublist(0, 8), 0, res2, 0);
    resArray.add(res2);

    final cipher3 = DESedeEngine();
    cipher3.init(
      true,
      KeyParameter(_insertZerosEvery7Bits(passHashPadded.sublist(14, 21))),
    );
    final res3 = Uint8List(8);
    cipher3.processBlock(serverChallenge.sublist(0, 8), 0, res3, 0);
    resArray.add(res3);

    return Uint8List.fromList([...res1, ...res2, ...res3]);
  }

  static Uint8List _hmacMd5(Uint8List key, Uint8List data) {
    final hmac = Hmac(md5, key);
    return Uint8List.fromList(hmac.convert(data).bytes);
  }

  static Map<String, Uint8List> _ntlm2srCalcResp(
    Uint8List responseKeyNT,
    Uint8List serverChallenge,
    Uint8List clientChallenge,
  ) {
    final lmChallengeResponse = Uint8List(clientChallenge.length + 16);
    lmChallengeResponse.setRange(0, clientChallenge.length, clientChallenge);

    final combined = Uint8List.fromList([
      ...serverChallenge,
      ...clientChallenge,
    ]);
    final digest = md5.convert(combined);
    final sess = Uint8List.fromList(digest.bytes);
    final ntChallengeResponse = _calcResp(responseKeyNT, sess.sublist(0, 8));

    return {'lm': lmChallengeResponse, 'nt': ntChallengeResponse};
  }

  static Map<String, Uint8List> _calcNTLMv2Resp(
    Uint8List pwhash,
    String username,
    String domain,
    Uint8List targetInfo,
    Uint8List serverChallenge,
    Uint8List clientChallenge,
  ) {
    final responseKeyNTLM = _ntowfv2(pwhash, username, domain);

    final lmV2ChallengeResponse = Uint8List.fromList([
      ..._hmacMd5(
        responseKeyNTLM,
        Uint8List.fromList([...serverChallenge, ...clientChallenge]),
      ),
      ...clientChallenge,
    ]);

    final now = DateTime.now().millisecondsSinceEpoch;
    final timestamp = (now + 11644473600000) * 10000;
    final timestampBuffer = ByteData(8);
    timestampBuffer.setUint64(0, timestamp, Endian.little);

    final zero32Bit = Uint8List(4);
    final temp = Uint8List.fromList([
      0x01, 0x01, 0x00, 0x00, // Version
      ...zero32Bit,
      ...timestampBuffer.buffer.asUint8List(),
      ...clientChallenge,
      ...zero32Bit,
      ...targetInfo,
      ...zero32Bit,
    ]);

    final proofString = _hmacMd5(
      responseKeyNTLM,
      Uint8List.fromList([...serverChallenge, ...temp]),
    );
    final ntV2ChallengeResponse = Uint8List.fromList([...proofString, ...temp]);

    return {'lm': lmV2ChallengeResponse, 'nt': ntV2ChallengeResponse};
  }

  static Uint8List _ntowfv2(Uint8List pwhash, String user, String domain) {
    return _hmacMd5(pwhash, _encodeUtf16Le(user.toUpperCase() + domain));
  }
}
