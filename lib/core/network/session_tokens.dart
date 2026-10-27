class SessionTokens {
  const SessionTokens({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;

  factory SessionTokens.fromJson(Map<String, Object?> json) {
    final access = json['accessToken'] as String;
    final refresh = json['refreshToken'] as String;
    if (access.isEmpty || refresh.isEmpty) {
      throw const FormatException('Empty token response');
    }
    return SessionTokens(accessToken: access, refreshToken: refresh);
  }
  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}
