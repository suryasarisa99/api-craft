import 'package:api_craft/core/providers/ref_provider.dart';
import 'package:api_craft/features/auth/auths/oauth2/store.dart';
import 'package:api_craft/features/auth/models/auth_model.dart';
import 'package:api_craft/features/dynamic-form/form_input.dart';

import 'grants/authorization_code.dart';
import 'grants/client_credentials.dart';
import 'grants/implicit.dart';
import 'grants/password.dart';

typedef GrantType = String;

const List<Map<String, String>> grantTypes = [
  {'label': 'Authorization Code', 'value': 'authorization_code'},
  {'label': 'Implicit', 'value': 'implicit'},
  {'label': 'Resource Owner Password Credential', 'value': 'password'},
  {'label': 'Client Credentials', 'value': 'client_credentials'},
];

final String defaultGrantType = grantTypes[0]['value']!;

Future<Map<String, dynamic>> hiddenIfNot(
  List<GrantType> allowedGrantTypes,
  Map<String, dynamic> values, [
  bool Function(Map<String, dynamic>)? otherCondition,
]) async {
  final currentGrantType = values['grantType']?.toString() ?? defaultGrantType;
  final hasGrantType = allowedGrantTypes.contains(currentGrantType);
  final hasOtherBools = otherCondition?.call(values) ?? true;

  final show = hasGrantType && hasOtherBools;
  return {'hidden': !show};
}

const List<String> authorizationUrls = [
  'https://github.com/login/oauth/authorize',
  'https://account.box.com/api/oauth2/authorize',
  'https://accounts.google.com/o/oauth2/v2/auth',
  'https://api.imgur.com/oauth2/authorize',
  'https://bitly.com/oauth/authorize',
  'https://gitlab.example.com/oauth/authorize',
  'https://medium.com/m/oauth/authorize',
  'https://public-api.wordpress.com/oauth2/authorize',
  'https://slack.com/oauth/authorize',
  'https://todoist.com/oauth/authorize',
  'https://www.dropbox.com/oauth2/authorize',
  'https://www.linkedin.com/oauth/v2/authorization',
  'https://MY_SHOP.myshopify.com/admin/oauth/access_token',
  'https://appcenter.intuit.com/app/connect/oauth2/authorize',
];

const List<String> accessTokenUrls = [
  'https://github.com/login/oauth/access_token',
  'https://api-ssl.bitly.com/oauth/access_token',
  'https://api.box.com/oauth2/token',
  'https://api.dropboxapi.com/oauth2/token',
  'https://api.imgur.com/oauth2/token',
  'https://api.medium.com/v1/tokens',
  'https://gitlab.example.com/oauth/token',
  'https://public-api.wordpress.com/oauth2/token',
  'https://slack.com/api/oauth.access',
  'https://todoist.com/oauth/access_token',
  'https://www.googleapis.com/oauth2/v4/token',
  'https://www.linkedin.com/oauth/v2/accessToken',
  'https://MY_SHOP.myshopify.com/admin/oauth/authorize',
  'https://oauth.platform.intuit.com/oauth2/v1/tokens/bearer',
];

final oauth2Auth = Authenticaion(
  type: 'oauth2',
  label: 'OAuth 2.0',
  shortLabel: 'OAuth 2',
  onApply: (ref, args) async {
    final values = args.values as Map<String, dynamic>;
    final headerPrefix = _stringArg(
      values,
      'headerPrefix',
      defaultValue: 'Bearer',
    );
    final grantType = _stringArg(values, 'grantType');
    final credentialsInBody = values['credentials'] == 'body';
    final tokenName = values['tokenName'] == 'id_token'
        ? 'id_token'
        : 'access_token';

    AccessTokenRawResponse? token;

    if (grantType == 'authorization_code') {
      token = await getAuthorizationCode(ref, {
        'accessTokenUrl': _ensureProtocol(_stringArg(values, 'accessTokenUrl')),
        'authorizationUrl': _ensureProtocol(
          _stringArg(values, 'authorizationUrl'),
        ),
        'clientId': _stringArg(values, 'clientId'),
        'clientSecret': _stringArg(values, 'clientSecret'),
        'redirectUri': _stringArgOrNull(values, 'redirectUri'),
        'usePkce': values['usePkce'] == true,
        'scope': _stringArgOrNull(values, 'scope'),
        'audience': _stringArgOrNull(values, 'audience'),
        'state': _stringArgOrNull(values, 'state'),
        'tokenName': tokenName,
        'credentialsInBody': credentialsInBody,
      });
    } else if (grantType == 'implicit') {
      token = await getImplicit(ref, {
        'authorizationUrl': _ensureProtocol(
          _stringArg(values, 'authorizationUrl'),
        ),
        'clientId': _stringArg(values, 'clientId'),
        'redirectUri': _stringArgOrNull(values, 'redirectUri'),
        'responseType': _stringArg(
          values,
          'responseType',
          defaultValue: 'token',
        ),
        'scope': _stringArgOrNull(values, 'scope'),
        'audience': _stringArgOrNull(values, 'audience'),
        'state': _stringArgOrNull(values, 'state'),
        'tokenName': tokenName,
      });
    } else if (grantType == 'client_credentials') {
      token = await getClientCredentials(ref, {
        'accessTokenUrl': _ensureProtocol(_stringArg(values, 'accessTokenUrl')),
        'clientId': _stringArg(values, 'clientId'),
        'clientSecret': _stringArg(values, 'clientSecret'),
        'credentialsInBody': credentialsInBody,
        'scope': _stringArgOrNull(values, 'scope'),
        'audience': _stringArgOrNull(values, 'audience'),
      });
    } else if (grantType == 'password') {
      token = await getPassword(ref, {
        'accessTokenUrl': _ensureProtocol(_stringArg(values, 'accessTokenUrl')),
        'clientId': _stringArg(values, 'clientId'),
        'clientSecret': _stringArg(values, 'clientSecret'),
        'username': _stringArg(values, 'username'),
        'password': _stringArg(values, 'password'),
        'credentialsInBody': credentialsInBody,
        'scope': _stringArgOrNull(values, 'scope'),
        'audience': _stringArgOrNull(values, 'audience'),
      });
    }

    final headerName = _stringArg(
      values,
      'headerName',
      defaultValue: 'Authorization',
    );

    // Determine the actual token value to use
    final tokenValue = (tokenName == 'id_token')
        ? (token?.idToken ??
              token
                  ?.accessToken) // Fallback or strict? JS uses token.response[tokenName]
        : (token?.accessToken);

    final headerValue = "$headerPrefix $tokenValue".trim();

    return AuthResult(
      headers: [
        [headerName, headerValue],
      ],
    );
  },
  args: [
    FormInputSelect(
      name: 'grantType',
      label: 'Grant Type',
      defaultValue: defaultGrantType,
      options: grantTypes
          .map(
            (e) =>
                FormInputSelectOption(label: e['label']!, value: e['value']!),
          )
          .toList(),
    ),
    FormInputText(name: 'clientId', label: 'Client ID', optional: true),
    FormInputText(
      name: 'clientSecret',
      label: 'Client Secret',
      optional: true,
      // Using the dynamicFn property from your FormInput definition
      dynamicFn: (ref, args) => hiddenIfNot([
        'authorization_code',
        'password',
        'client_credentials',
      ], args.values),
    ),
    FormInputText(
      name: 'authorizationUrl',
      label: 'Authorization URL',
      optional: true,
      placeholder: authorizationUrls[0],
      dynamicFn: (ref, args) =>
          hiddenIfNot(['authorization_code', 'implicit'], args.values),
    ),
    FormInputText(
      name: 'accessTokenUrl',
      label: 'Access Token URL',
      optional: true,
      placeholder: accessTokenUrls[0],
      dynamicFn: (ref, args) => hiddenIfNot([
        'authorization_code',
        'password',
        'client_credentials',
      ], args.values),
    ),
    FormInputText(
      name: 'redirectUri',
      label: 'Redirect URI',
      optional: true,
      dynamicFn: (ref, args) =>
          hiddenIfNot(['authorization_code', 'implicit'], args.values),
    ),
    FormInputText(
      name: 'state',
      label: 'State',
      optional: true,
      dynamicFn: (ref, args) =>
          hiddenIfNot(['authorization_code', 'implicit'], args.values),
    ),
    FormInputText(name: 'audience', label: 'Audience', optional: true),
    FormInputSelect(
      name: 'tokenName',
      label: 'Token for authorization',
      description:
          'Select which token to send in the "Authorization: Bearer" header. Most APIs expect '
          'access_token, but some (like OpenID Connect) require id_token.',
      defaultValue: 'access_token',
      options: [
        FormInputSelectOption(label: 'access_token', value: 'access_token'),
        FormInputSelectOption(label: 'id_token', value: 'id_token'),
      ],
      dynamicFn: (ref, args) =>
          hiddenIfNot(['authorization_code', 'implicit'], args.values),
    ),
    FormInputCheckbox(
      name: 'usePkce',
      label: 'Use PKCE',
      dynamicFn: (ref, args) =>
          hiddenIfNot(['authorization_code'], args.values),
    ),
    FormInputAccordion(
      label: 'Advanced',
      inputs: [
        FormInputText(name: 'scope', label: 'Scope', optional: true),
        FormInputText(
          name: 'headerName',
          label: 'Header Name',
          defaultValue: 'Authorization',
        ),
        FormInputText(
          name: 'headerPrefix',
          label: 'Header Prefix',
          defaultValue: 'Bearer',
          optional: true,
        ),
        FormInputSelect(
          name: 'credentials',
          label: 'Send Credentials',
          defaultValue: 'body',
          options: [
            FormInputSelectOption(label: 'In Request Body', value: 'body'),
            FormInputSelectOption(
              label: 'As Basic Authentication',
              value: 'basic',
            ),
          ],
        ),
      ],
    ),
    FormInputAccordion(
      label: 'Access Token Response',
      dynamicFn: (ref, args) async {
        final token = await OAuth2Store.getToken(
          getRef(ref),
          _tokenStoreArgs(
            args.values,
            args.values['contextId'],
          ), // TODO: Context ID
        );
        if (token == null) return {'hidden': true};

        return {
          'label': 'Access Token Response',
          'inputs': [
            FormInputEditor(
              name: 'response',
              defaultValue: token.response.toMap(),
              readOnly: true,
              language: 'json',
            ),
          ],
        };
      },
    ),
  ],
);

// --- Helper Functions ---

TokenStoreArgs _tokenStoreArgs(Map<String, dynamic> values, String contextId) {
  return TokenStoreArgs(
    contextId: contextId, // TODO: Context ID
    clientId: _stringArg(values, 'clientId'),
    accessTokenUrl: _ensureProtocol(_stringArg(values, 'accessTokenUrl')),
    authorizationUrl: _ensureProtocol(_stringArg(values, 'authorizationUrl')),
  );
}

String? _stringArgOrNull(Map<String, dynamic> values, String name) {
  final arg = values[name];
  if (arg == null || arg.toString().isEmpty) return null;
  return arg.toString();
}

String _stringArg(
  Map<String, dynamic> values,
  String name, {
  String defaultValue = '',
}) {
  return _stringArgOrNull(values, name) ?? defaultValue;
}

String _ensureProtocol(String url) {
  if (url.isEmpty || url.startsWith(RegExp(r'https?://'))) return url;
  return 'https://$url';
}
