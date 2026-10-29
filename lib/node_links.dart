import 'dart:convert';

/// Converts common single-node share links to a sing-box 1.14-compatible
/// configuration. Advanced transports, subscription formats, and WireGuard
/// endpoints should be imported as complete sing-box JSON instead.
class NodeLinks {
  static const supported = 'vless://, trojan://, ss://, hysteria2://, hy2://, tuic://';

  static String parseToConfig(String raw) {
    final outbound = parseOutbound(raw);
    return const JsonEncoder.withIndent('  ').convert(wrapOutbound(outbound));
  }

  static Map<String, dynamic> parseOutbound(String raw) {
    final link = raw.trim();
    final uri = Uri.tryParse(link);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      if (link.startsWith('ss://')) return _parseShadowsocks(link);
      throw const FormatException('节点链接格式不正确，缺少主机名');
    }
    final port = uri.hasPort ? uri.port : _defaultPort(uri.scheme);
    if (port < 1 || port > 65535) throw const FormatException('无效的服务器端口');
    final query = uri.queryParameters;
    final host = uri.host;
    switch (uri.scheme.toLowerCase()) {
      case 'vless':
        final uuid = Uri.decodeComponent(uri.userInfo);
        if (uuid.isEmpty) throw const FormatException('VLESS UUID 不能为空');
        final outbound = <String, dynamic>{
          'type': 'vless', 'tag': 'node', 'server': host,
          'server_port': port, 'uuid': uuid,
        };
        final flow = query['flow'];
        if (flow != null && flow.isNotEmpty) outbound['flow'] = flow;
        final security = query['security'] ?? 'none';
        if (security == 'tls' || security == 'reality') {
          final tls = <String, dynamic>{
            'enabled': true,
            'server_name': query['sni'] ?? query['serverName'] ?? host,
            'insecure': false,
          };
          if (security == 'reality') {
            final pbk = query['pbk'] ?? '';
            if (pbk.isEmpty) throw const FormatException('REALITY 缺少公钥 pbk');
            tls['reality'] = {
              'enabled': true,
              'public_key': pbk,
              'short_id': query['sid'] ?? '',
            };
          }
          final fp = query['fp'];
          if (fp != null && fp.isNotEmpty) tls['utls'] = {'enabled': true, 'fingerprint': fp};
          outbound['tls'] = tls;
        } else if (security != 'none') {
          throw FormatException('暂不支持的 VLESS security=$security，请导入完整 JSON');
        }
        _appendTransport(outbound, query);
        return outbound;
      case 'trojan':
        final password = Uri.decodeComponent(uri.userInfo);
        if (password.isEmpty) throw const FormatException('Trojan 密码不能为空');
        final outbound = <String, dynamic>{
          'type': 'trojan', 'tag': 'node', 'server': host,
          'server_port': port, 'password': password,
          'tls': {
            'enabled': true,
            'server_name': query['sni'] ?? host,
            'insecure': false,
          },
        };
        _appendTransport(outbound, query);
        return outbound;
      case 'hysteria2':
      case 'hy2':
        final password = Uri.decodeComponent(uri.userInfo.split(':').last);
        if (password.isEmpty) throw const FormatException('Hysteria2 密码不能为空');
        return {
          'type': 'hysteria2', 'tag': 'node', 'server': host,
          'server_port': port, 'password': password,
          'tls': {
            'enabled': true,
            'server_name': query['sni'] ?? host,
            'insecure': false,
          },
        };
      case 'tuic':
        final userParts = uri.userInfo.split(':');
        if (userParts.length < 2) throw const FormatException('TUIC 需要 UUID:password');
        return {
          'type': 'tuic', 'tag': 'node', 'server': host,
          'server_port': port,
          'uuid': Uri.decodeComponent(userParts.first),
          'password': Uri.decodeComponent(userParts.sublist(1).join(':')),
          'congestion_control': query['congestion_control'] ?? 'bbr',
          'tls': {
            'enabled': true,
            'server_name': query['sni'] ?? host,
            'insecure': false,
            'alpn': [query['alpn'] ?? 'h3'],
          },
        };
      case 'ss':
        return _parseShadowsocks(link);
      default:
        throw FormatException('不支持此链接协议：${uri.scheme}；可导入完整 sing-box JSON');
    }
  }

  static int _defaultPort(String scheme) => switch (scheme.toLowerCase()) {
    'ss' => 8388,
    _ => 443,
  };

  static void _appendTransport(Map<String, dynamic> outbound, Map<String, String> q) {
    final type = q['type'];
    if (type == null || type == 'tcp' || type == 'none') return;
    if (type == 'ws') {
      final transport = <String, dynamic>{
        'type': 'ws', 'path': q['path'] ?? '/',
      };
      final hostHeader = q['host'];
      if (hostHeader != null && hostHeader.isNotEmpty) {
        transport['headers'] = {'Host': hostHeader};
      }
      outbound['transport'] = transport;
      return;
    }
    if (type == 'grpc') {
      outbound['transport'] = {
        'type': 'grpc', 'service_name': q['serviceName'] ?? '',
      };
      return;
    }
    throw FormatException('暂不支持 $type 传输，请导入完整 sing-box JSON');
  }

  static Map<String, dynamic> _parseShadowsocks(String link) {
    final without = link.substring(5);
    final noFragment = without.split('#').first;
    final noQuery = noFragment.split('?').first;
    String auth;
    String endpoint;
    if (noQuery.contains('@')) {
      final index = noQuery.lastIndexOf('@');
      auth = noQuery.substring(0, index);
      endpoint = noQuery.substring(index + 1);
      if (!auth.contains(':')) auth = _decodeBase64Url(auth);
    } else {
      final decoded = _decodeBase64Url(noQuery);
      final index = decoded.lastIndexOf('@');
      if (index < 0) throw const FormatException('无效的 Shadowsocks 链接');
      auth = decoded.substring(0, index);
      endpoint = decoded.substring(index + 1);
    }
    final split = auth.indexOf(':');
    if (split <= 0) throw const FormatException('Shadowsocks 加密方式或密码缺失');
    final serverUri = Uri.tryParse('ss://$endpoint');
    if (serverUri == null || serverUri.host.isEmpty || !serverUri.hasPort) {
      throw const FormatException('Shadowsocks 主机或端口无效');
    }
    return {
      'type': 'shadowsocks', 'tag': 'node',
      'server': serverUri.host, 'server_port': serverUri.port,
      'method': Uri.decodeComponent(auth.substring(0, split)),
      'password': Uri.decodeComponent(auth.substring(split + 1)),
    };
  }

  static String _decodeBase64Url(String value) {
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(value)));
    } catch (_) {
      throw const FormatException('Shadowsocks Base64 数据无效');
    }
  }

  static Map<String, dynamic> wrapOutbound(Map<String, dynamic> outbound) {
    return {
      'log': {'disabled': true},
      'dns': {
        'servers': [
          {'type': 'local', 'tag': 'bootstrap'},
          {
            'type': 'https', 'tag': 'remote',
            'server': '1.1.1.1', 'path': '/dns-query',
            'tls': {'enabled': true, 'server_name': 'cloudflare-dns.com'},
            'detour': 'node',
          },
        ],
        'final': 'remote',
      },
      'inbounds': [
        {
          'type': 'tun', 'tag': 'tun-in',
          'address': ['172.19.0.1/30'], 'auto_route': true,
          'dns_mode': 'hijack',
        },
      ],
      'outbounds': [outbound, {'type': 'direct', 'tag': 'direct'}],
      'route': {
        'rules': [
          {'action': 'sniff'},
          {'protocol': 'dns', 'action': 'hijack-dns'},
        ],
        'final': 'node',
        'auto_detect_interface': true,
        'default_domain_resolver': 'bootstrap',
      },
    };
  }
}
