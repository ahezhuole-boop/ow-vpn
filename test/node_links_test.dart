import 'package:flutter_test/flutter_test.dart';
import 'package:own_node_vpn/node_links.dart';

void main() {
  test('VLESS Reality is mapped to TLS Reality', () {
    final o = NodeLinks.parseOutbound(
      'vless://123e4567-e89b-12d3-a456-426614174000@vpn.example.org:443?security=reality&sni=example.org&pbk=TESTPUBKEY&sid=abcd&flow=xtls-rprx-vision',
    );
    expect(o['type'], 'vless');
    expect((o['tls'] as Map)['reality']['enabled'], true);
    expect(o['flow'], 'xtls-rprx-vision');
  });
  test('Trojan disables insecure cert skipping', () {
    final o = NodeLinks.parseOutbound('trojan://password@vpn.example.org:443?sni=vpn.example.org');
    expect((o['tls'] as Map)['insecure'], false);
  });
  test('Shadowsocks parses clear auth format', () {
    final o = NodeLinks.parseOutbound('ss://aes-256-gcm:my-password@vpn.example.org:8388');
    expect(o['type'], 'shadowsocks');
    expect(o['server_port'], 8388);
  });
  test('Unknown schemes are rejected', () {
    expect(() => NodeLinks.parseOutbound('ftp://example.org:80'), throwsFormatException);
  });
}
