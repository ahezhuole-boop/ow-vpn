import 'dart:convert';
import 'dart:io';

/// Disables the sing-box core log in a JSON profile.
/// This is NOT equivalent to disabling OS, cloud-provider, CDN, crash or other logs.
class PrivacyConfig {
  static String disableCoreLogs(String raw) {
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('配置必须是 JSON 对象');
    }
    final result = Map<String, dynamic>.from(data);
    result['log'] = {'disabled': true};
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  /// Fail closed if a plugin profile is not the expected sing-box JSON.
  /// In production this write needs atomic replacement and external audit.
  static Future<void> enforceNoCoreLogsInFile(String path) async {
    final file = File(path);
    final original = await file.readAsString();
    final modified = disableCoreLogs(original);
    await file.writeAsString(modified, flush: true);
  }
}
