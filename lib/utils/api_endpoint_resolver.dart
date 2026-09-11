class ApiEndpointResolver {
  const ApiEndpointResolver._();

  static Uri chatCompletions(
    String rawInput, {
    bool allowInsecureHttp = false,
  }) {
    final uri = Uri.parse(rawInput.trim());
    _validateEndpoint(uri, allowInsecureHttp: allowInsecureHttp);
    final normalizedPath = _normalizeChatPath(uri.path);

    return uri.replace(
      path: normalizedPath,
      query: uri.query.isEmpty ? null : uri.query,
    );
  }

  static Uri models(
    String rawInput, {
    bool allowInsecureHttp = false,
  }) {
    final chatUri = chatCompletions(
      rawInput,
      allowInsecureHttp: allowInsecureHttp,
    );
    final chatPath = chatUri.path;
    final suffix = '/chat/completions';
    final basePath = chatPath.endsWith(suffix)
        ? chatPath.substring(0, chatPath.length - suffix.length)
        : chatPath;
    final modelsPath = _joinPath(basePath, 'models');

    return chatUri.replace(path: modelsPath, query: null);
  }

  static String previewChatCompletions(
    String rawInput, {
    bool allowInsecureHttp = false,
  }) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    return chatCompletions(
      trimmed,
      allowInsecureHttp: allowInsecureHttp,
    ).toString();
  }

  static void _validateEndpoint(
    Uri uri, {
    required bool allowInsecureHttp,
  }) {
    final scheme = uri.scheme.toLowerCase();
    if ((scheme != 'https' && scheme != 'http') || uri.host.trim().isEmpty) {
      throw const FormatException('API 地址必须是完整的 HTTP 或 HTTPS 地址。');
    }
    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('API 地址不能在 URL 中包含用户名或密码。');
    }
    if (scheme == 'http' && !_isLoopbackHost(uri.host) && !allowInsecureHttp) {
      throw const FormatException(
        '该地址会用明文 HTTP 发送 API Key；请改用 HTTPS，或显式开启当前 API 的明文连接。',
      );
    }
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized == 'localhost' || normalized == '::1') {
      return true;
    }
    final address = Uri.tryParse('http://$normalized')?.host ?? normalized;
    return address == '127.0.0.1' || address.startsWith('127.');
  }

  static String _normalizeChatPath(String rawPath) {
    final path = _trimTrailingSlash(rawPath);

    if (path.isEmpty) {
      return '/v1/chat/completions';
    }

    if (path.endsWith('/chat/completions')) {
      return path;
    }

    if (path.endsWith('/chat')) {
      return '$path/completions';
    }

    if (path.endsWith('/models')) {
      return '${path.substring(0, path.length - '/models'.length)}/chat/completions';
    }

    if (path.endsWith('/v1')) {
      return '$path/chat/completions';
    }

    return _joinPath(path, 'v1/chat/completions');
  }

  static String _joinPath(String left, String right) {
    final normalizedLeft = _trimTrailingSlash(left);
    final normalizedRight = right.startsWith('/') ? right.substring(1) : right;

    if (normalizedLeft.isEmpty) {
      return '/$normalizedRight';
    }

    return '$normalizedLeft/$normalizedRight';
  }

  static String _trimTrailingSlash(String value) {
    if (value.isEmpty || value == '/') {
      return '';
    }

    return value.replaceFirst(RegExp(r'/+$'), '');
  }
}
