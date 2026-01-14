import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';

final awsV4Auth = Authenticaion(
  type: 'awsv4',
  label: 'AWS Signature',
  shortLabel: 'AWS v4',
  args: [
    FormInputText(name: 'accessKeyId', label: 'Access Key ID', password: true),
    FormInputText(
      name: 'secretAccessKey',
      label: 'Secret Access Key',
      password: true,
    ),
    FormInputText(
      name: 'service',
      label: 'Service Name',
      defaultValue: 'sts',
      placeholder: 'sts',
      description:
          'The service that is receiving the request (sts, s3, sqs, ...)',
    ),
    FormInputText(
      name: 'region',
      label: 'Region',
      placeholder: 'us-east-1',
      description:
          'The region that is receiving the request (defaults to us-east-1)',
      optional: true,
    ),
    FormInputText(
      name: 'sessionToken',
      label: 'Session Token',
      password: true,
      optional: true,
      description: 'Only required if you are using temporary credentials',
    ),
  ],

  onApply: (ref, args) async {
    final values = args.values;

    final accessKeyId = values['accessKeyId'] ?? '';
    final secretAccessKey = values['secretAccessKey'] ?? '';
    final sessionToken = values['sessionToken'] ?? '';

    final service = (values['service'] ?? 'sts').toString();
    final region = values['region']?.toString() ?? 'us-east-1';

    final uri = Uri.parse(args.url);

    /// Only include headers AWS needs (same as JS)
    final Map<String, String> headers = {};
    for (final h in args.headers) {
      final name = h[0].toLowerCase();
      if (name == 'content-type' ||
          name == 'host' ||
          name == 'x-amz-date' ||
          name == 'x-amz-security-token') {
        headers[name] = h[1];
      }
    }

    final credentials = AWSCredentials(
      accessKeyId,
      secretAccessKey,
      sessionToken,
    );

    final signer = AWSSigV4Signer(
      credentialsProvider: StaticCredentialsProvider(credentials),
    );

    final request = AWSHttpRequest(
      method: AWSHttpMethod.fromString(args.method),
      uri: uri,
      headers: headers,
    );

    final scope = AWSCredentialScope(
      region: region,
      service: AWSService(service),
    );

    final signedRequest = await signer.sign(
      request,
      credentialScope: scope,
      serviceConfiguration: ServiceConfiguration(signBody: false),
    );

    /// Apply signed headers (except content-type)
    return AuthResult(
      headers: signedRequest.headers.entries
          .where((e) => e.key.toLowerCase() != 'content-type')
          .map((e) => [e.key, e.value])
          .toList(),
    );
  },
);
