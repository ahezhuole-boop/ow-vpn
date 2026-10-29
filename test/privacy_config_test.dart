import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_node_vpn/privacy_config.dart';
import 'package:own_node_vpn/node_links.dart';

void main() {
  test('generated node has sing-box core logging disabled', () {
    final result = jsonDecode(NodeLinks.parseToConfig(
      'trojan://test-password@vpn.example.org:443',
    )) as Map<String, dynamic>;
    expect((result['log'] as Map)['disabled'], true);
  });

  test('complete imported JSON overrides previous log level and file', () {
    final input = jsonEncode({
      'log': {'level': 'debug', 'output': 'access.log'},
      'outbounds': [{'type': 'direct', 'tag': 'direct'}],
    });
    final output = jsonDecode(PrivacyConfig.disableCoreLogs(input)) as Map<String, dynamic>;
    expect(output['log'], {'disabled': true});
    expect((output['outbounds'] as List).length, 1);
  });

  test('invalid input cannot be used', () {
    expect(() => PrivacyConfig.disableCoreLogs('not json'), throwsFormatException);
  });
}
