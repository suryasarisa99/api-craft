import 'dart:convert';

import 'package:api_craft/core/models/models.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';

// enum Signatures {
//   hmacSha1,
//   hmacSha256,
//   hmacSha512,
//   rsaSha1,
//   rsaSha256,
//   rsaSha512,
//   plaintext,
// }

// final defaultSig = Signatures.hmacSha1;
// final pkSigs = Signatures.values
//     .where((s) => s.name.startsWith('rsa'))
//     .toList();
// final nonPkSigs = Signatures.values
//     .where((s) => !s.name.startsWith('rsa'))
//     .toList();
class Signatures {
  static const hmacSha1 = 'HMAC-SHA1';
  static const hmacSha256 = 'HMAC-SHA256';
  static const hmacSha512 = 'HMAC-SHA512';
  static const rsaSha1 = 'RSA-SHA1';
  static const rsaSha256 = 'RSA-SHA256';
  static const rsaSha512 = 'RSA-SHA512';
  static const plaintext = 'PLAINTEXT';
}

const defaultSig = Signatures.hmacSha1;

const allSigns = [
  Signatures.hmacSha1,
  Signatures.hmacSha256,
  Signatures.hmacSha512,
  Signatures.rsaSha1,
  Signatures.rsaSha256,
  Signatures.rsaSha512,
  Signatures.plaintext,
];
final pkSigs = allSigns.where((s) => s.startsWith('RSA-')).toList();
final nonPkSigs = allSigns.where((s) => !s.startsWith('RSA-')).toList();

dynamic hashFunction(String signatureMethod) {
  switch (signatureMethod) {
    case Signatures.hmacSha1:
      return (String base, String key) => base64Encode(
        Hmac(sha1, utf8.encode(key)).convert(utf8.encode(base)).bytes,
      );

    case Signatures.hmacSha256:
      return (String base, String key) => base64Encode(
        Hmac(sha256, utf8.encode(key)).convert(utf8.encode(base)).bytes,
      );

    case Signatures.hmacSha512:
      return (String base, String key) => base64Encode(
        Hmac(sha512, utf8.encode(key)).convert(utf8.encode(base)).bytes,
      );

    case Signatures.rsaSha1:
      return (String base, RSAPrivateKey privateKey) =>
          _rsaSign(base, privateKey, 'SHA-1');

    case Signatures.rsaSha256:
      return (String base, RSAPrivateKey privateKey) =>
          _rsaSign(base, privateKey, 'SHA-256');

    case Signatures.rsaSha512:
      return (String base, RSAPrivateKey privateKey) =>
          _rsaSign(base, privateKey, 'SHA-512');

    case Signatures.plaintext:
      return (String base) => base;
  }
}

String _rsaSign(String base, RSAPrivateKey privateKey, String hash) {
  final signer = Signer('$hash/RSA');
  signer.init(true, PrivateKeyParameter<RSAPrivateKey>(privateKey));

  final sig = signer.generateSignature(utf8.encode(base)) as RSASignature;

  return base64Encode(sig.bytes);
}

DynamicFn hiddenIfNot(
  List<String> sigMethod, [
  List<bool Function(Map<String, dynamic> values)> other = const [],
]) {
  return (ref, args) {
    final hasGrantType = sigMethod.firstWhereOrNull(
      (t) => t == (args.values['signatureMethod'] ?? defaultSig),
    );
    final hasOtherBools = other.every((t) => t(args.values));
    final show = hasGrantType != null && hasOtherBools;
    return {'hidden': !show};
  };
}

final oAuth1 = Authenticaion(
  type: 'oauth1',
  label: 'OAuth 1.0',
  shortLabel: 'OAuth 1',
  args: [
    FormInputBanner(
      // color: 'info',
      inputs: [FormInputMarkdown(content: 'OAuth 1.0 is still in beta')],
    ),
    FormInputSelect(
      name: 'signatureMethod',
      label: 'Signature Method',
      defaultValue: defaultSig,
      options: allSigns
          .map((v) => FormInputSelectOption(label: v, value: v))
          .toList(),
    ),
    FormInputText(
      name: 'consumerKey',
      label: 'Consumer Key',
      password: true,
      optional: true,
    ),
    FormInputText(
      name: 'consumerSecret',
      label: 'Consumer Secret',
      password: true,
      optional: true,
    ),
    FormInputText(
      name: 'tokenKey',
      label: 'Access Token',
      password: true,
      optional: true,
    ),
    FormInputText(
      name: 'tokenSecret',
      label: 'Token Secret',
      password: true,
      optional: true,
      dynamicFn: hiddenIfNot(nonPkSigs),
    ),
    FormInputText(
      name: 'privateKey',
      label: 'Private Key (RSA-SHA1)',
      multiLine: true,
      optional: true,
      password: true,
      placeholder:
          '-----BEGIN RSA PRIVATE KEY-----\nPrivate key in PEM format\n-----END RSA PRIVATE KEY-----',
      dynamicFn: hiddenIfNot(pkSigs),
    ),
    FormInputAccordion(
      label: 'Advanced',
      inputs: [
        FormInputText(name: 'callback', label: 'Callback Url', optional: true),
        FormInputText(
          name: 'verifier',
          label: 'Verifier',
          optional: true,
          password: true,
        ),
        FormInputText(name: 'timestamp', label: 'Timestamp', optional: true),
        FormInputText(name: 'nonce', label: 'Nonce', optional: true),
        FormInputText(
          name: 'version',
          label: 'OAuth Version',
          optional: true,
          defaultValue: '1.0',
        ),
        FormInputText(name: 'realm', label: 'Realm', optional: true),
      ],
    ),
  ],
  onApply: (ref, values) {},
);
// dynamic onApply(Ref ref, CallTemplateFunctionArgs args) {
//   final values = args.values;
//   final consumerKey = values['consumerKey'] ?? '';
//   final consumerSecret = values['consumerSecret'] ?? '';
//   final signatureMethod = values['signatureMethod'] ?? Signatures.hmacSha1;
//   final version = values['version'] ?? '';
//   final realm = values['realm'] ?? '';
//   // final oauth = OAuth({
//   //   consumer: { key: consumerKey, secret: consumerSecret },
//   //   signature_method: signatureMethod,
//   //   version,
//   //   hash_function: hashFunction(signatureMethod),
//   //   realm,
//   // });
//   oauth

// }
