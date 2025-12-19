enum AuthType {
  apiKey("API Key", "API Key"),
  awsSignature("AWS v4", "AWS Signature"),
  basic("Basic", "Basic Auth"),
  bearer("Bearer", "Bearer Token"),
  jwtBearer("JWT", "JWT Bearer"),
  oAuth1("OAuth 1", "OAuth 1.0"),
  oAuth2("OAuth 2", "OAuth 2.0"),
  ntlm("NTLM", "NTLM Auth"),
  inherit("Auth", "Inherit from Parent"),
  noAuth("No Auth", "No Authentication");

  final String title;
  final String label;
  const AuthType(this.label, this.title);
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
