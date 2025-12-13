enum AuthType {
  apiKey("API Key"),
  awsSignature("AWS Signature"),
  basic("Basic Auth"),
  bearer("Bearer Token"),
  jwtBearer("JWT Bearer"),
  oAuth1("OAuth 1.0"),
  oAuth2("OAuth 2.0"),
  ntlm("NTLM Auth"),
  inherit("Inherit from Parent"),
  noAuth("No Auth");

  final String title;
  const AuthType(this.title);
}

class AuthData {
  final AuthType type;
  final String token;
  final String username;
  final String password;

  const AuthData({
    this.type = AuthType.inherit,
    this.token = '',
    this.username = '',
    this.password = '',
  });

  factory AuthData.fromMap(Map<String, dynamic> map) => AuthData(
    type: AuthType.values[map['type'] ?? 0],
    token: map['token'] ?? '',
    username: map['username'] ?? '',
    password: map['password'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'type': type.index,
    'token': token,
    'username': username,
    'password': password,
  };

  AuthData copyWith({
    AuthType? type,
    String? token,
    String? username,
    String? password,
  }) {
    return AuthData(
      type: type ?? this.type,
      token: token ?? this.token,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  AuthData clone() {
    return AuthData(
      type: type,
      token: token,
      username: username,
      password: password,
    );
  }
}
