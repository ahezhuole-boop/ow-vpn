import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sing_box/flutter_sing_box.dart';
import 'package:mmkv/mmkv.dart';
import 'package:path_provider/path_provider.dart';

import 'node_links.dart';
import 'privacy_config.dart';
import 'brand.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MMKV.initialize();
  await FlutterSingBox().init();
  runApp(const OwnNodeApp());
}

class OwnNodeApp extends StatelessWidget {
  const OwnNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Brand.primary;
    return MaterialApp(
      title: Brand.productName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Brand.background,
        colorScheme: ColorScheme.fromSeed(seedColor: accent),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      home: const Dashboard(),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final _vpn = FlutterSingBox();
  final _storage = ProfileStorage.instance;
  StreamSubscription<ProxyState>? _stateSubscription;
  StreamSubscription<ClientStatus>? _trafficSubscription;
  List<Profile> _profiles = [];
  Profile? _selected;
  bool _busy = false;
  ProxyState _state = const ProxyStopped();
  String? _error;
  int _up = 0, _down = 0;
  String _coreVersion = '—';

  @override
  void initState() {
    super.initState();
    _refreshProfiles();
    _vpn.getSingBoxVersion().then((v) {
      if (mounted) setState(() => _coreVersion = v);
    }).catchError((Object _) {});
    _stateSubscription = _vpn.proxyStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _state = s;
        if (s case ProxyStopped(:final errMessage)) {
          _error = errMessage;
          _up = 0;
          _down = 0;
        } else if (s is ProxyStarted) {
          _error = null;
        }
      });
    });
    _trafficSubscription = _vpn.connectedStatusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _up = status.uplink;
        _down = status.downlink;
      });
    });
  }

  void _refreshProfiles() {
    setState(() {
      _profiles = _storage.getProfiles();
      _selected = _storage.getSelectedProfile();
    });
  }

  Future<void> _select(Profile profile) async {
    if (_state is! ProxyStopped) {
      _show('请先断开 VPN，再切换节点配置');
      return;
    }
    try {
      final valid = _storage.setSelectedProfile(profile.id);
      if (!valid) throw StateError('配置选择失败');
      // The plugin uses the active profile file to start its native service.
      final path = await _storage.getProfilePath(profile.id);
      await PrivacyConfig.enforceNoCoreLogsInFile(path);
      _storage.setUsingConfig(path);
      _refreshProfiles();
      _show('已选择：${profile.name}');
    } catch (e) {
      _show('选择配置失败：无法确认节点的隐私日志设置');
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      if (_state is ProxyStarted || _state is ProxyStarting) {
        await _vpn.stopVpn();
      } else {
        if (_selected == null) {
          _show('请先导入节点或订阅配置');
          return;
        }
        final agreed = await _confirmVpnUse();
        if (!agreed || !mounted) return;
        await _select(_selected!);
        if (Platform.isWindows) {
          final status = await _vpn.queryServiceStatus();
          if (status == WindowsServiceStatus.notInstalled) {
            final ok = await _vpn.installService(
              serviceName: windowsServiceName,
              displayName: windowsServiceDisplayName,
              description: windowsServiceDescription,
            );
            if (!ok) throw StateError('Windows 服务安装失败，请同意管理员权限弹窗');
          } else if (status == WindowsServiceStatus.error) {
            throw StateError('无法读取 Windows 服务状态');
          }
        }
        await _vpn.startVpn();
        // Windows reports startup failures asynchronously via proxyStateStream.
      }
    } catch (e) {
      if (mounted) setState(() => _error = '操作失败：请检查节点、网络和 VPN 权限');
      _show('操作失败：请检查节点、网络和 VPN 权限');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clearly visible, separate notice before requesting VPN capabilities.
  /// It is intentionally displayed for each connection in this preview build,
  /// and must be reviewed against real data practices before any public release.
  Future<bool> _confirmVpnUse() async {
    if (!mounted) return false;
    final consent = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('VPN 权限与网络流量说明'),
        content: const SizedBox(
          width: 460,
          child: Text(
            '连接后，本应用会通过系统 VPN/网络代理接口，将符合配置规则的网络流量发送至你选择的节点服务器。'
            '服务器运营者可能看到部分连接元数据。请仅使用你信任的节点。\n\n'
            '本客户端尝试禁用 sing-box 内核日志；不代表 VPN 运营节点、操作系统、云服务商均无日志。'
            '项目未经完整安全审计，不保证匿名、断线保护或 DNS/IPv6 无泄漏。'
            '继续即表示你理解上述用途，并允许下一步请求系统 VPN 权限。',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('理解并继续')),
        ],
      ),
    );
    return consent == true;
  }

  Future<void> _import() async {
    if (_state is! ProxyStopped) {
      _show('请先断开 VPN 再导入配置');
      return;
    }
    final result = await showDialog<({String name, String data, int mode})>(
      context: context,
      builder: (_) => const ImportDialog(),
    );
    if (result == null || !mounted) return;
    setState(() { _busy = true; _error = null; });
    File? temp;
    String? persistedPath;
    try {
      final name = result.name.trim().isEmpty ? '我的节点' : result.name.trim();
      Uri source;
      if (result.mode == 0) { // Direct link
        final config = NodeLinks.parseToConfig(result.data);
        final dir = await getApplicationDocumentsDirectory();
        temp = File('${dir.path}${Platform.pathSeparator}ownnode_import_${DateTime.now().microsecondsSinceEpoch}.json');
        await temp.writeAsString(config, flush: true);
        source = temp.uri;
      } else if (result.mode == 1) { // Subscription URL
        final link = Uri.tryParse(result.data.trim());
        if (link == null || link.scheme != 'https' || link.host.isEmpty) {
          throw const FormatException('订阅仅接受有效 HTTPS 地址');
        }
        source = link;
      } else { // Complete JSON
        final parsed = jsonDecode(result.data);
        if (parsed is! Map<String, dynamic> ||
            parsed['inbounds'] is! List ||
            parsed['route'] is! Map ||
            (parsed['outbounds'] is! List && parsed['endpoints'] is! List)) {
          throw const FormatException('请输入完整 sing-box JSON（需要 inbounds、outbounds/endpoints 和 route）');
        }
        final dir = await getApplicationDocumentsDirectory();
        temp = File('${dir.path}${Platform.pathSeparator}ownnode_import_${DateTime.now().microsecondsSinceEpoch}.json');
        await temp.writeAsString(PrivacyConfig.disableCoreLogs(jsonEncode(parsed)), flush: true);
        source = temp.uri;
      }
      final profile = await ProfileService().importProfile(
        subscribeLink: source,
        name: name,
      );
      if (!_storage.setSelectedProfile(profile.id)) {
        throw StateError('导入成功，但无法设置为当前配置');
      }
      final path = await _storage.getProfilePath(profile.id);
      persistedPath = path;
      await PrivacyConfig.enforceNoCoreLogsInFile(path);
      _storage.setUsingConfig(path);
      _refreshProfiles();
      _show('已导入并选中：$name');
    } catch (e) {
      // Never print raw subscription text or passwords in error logs.
      if (mounted) setState(() => _error = '导入失败，请检查协议与配置格式');
      _show('导入失败：请检查配置格式、订阅地址及网络连接');
    } finally {
      // The parsed profile should be managed by ProfileService after import.
      try {
        if (temp != null && temp.path != persistedPath && await temp.exists()) {
          await temp.delete();
        }
      } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _stateName => switch (_state) {
    ProxyStarted() => '已连接',
    ProxyStarting() => '连接中…',
    ProxyStopping() => '断开中…',
    ProxyStopped() => '未连接',
  };

  bool get _active => _state is ProxyStarted;

  String _fmt(int bytes) {
    final b = bytes.toDouble();
    if (b > 1048576) return '${(b / 1048576).toStringAsFixed(1)} MB/s';
    if (b > 1024) return '${(b / 1024).toStringAsFixed(1)} KB/s';
    return '$bytes B/s';
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
        padding: padding ?? const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffe9edf4)),
          boxShadow: const [BoxShadow(color: Color(0x0c0e2148), blurRadius: 24, offset: Offset(0, 9))],
        ), child: child,
      );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 750;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _card(child: Column(children: [
          Text('连接状态', style: TextStyle(color: Colors.blueGrey.shade500)),
          const SizedBox(height: 8),
          Text(_stateName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 28),
          InkWell(
            borderRadius: BorderRadius.circular(100),
            onTap: _busy ? null : _toggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 154, height: 154,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: _active ? const Color(0xff0eac79) : Brand.primary,
                  boxShadow: [BoxShadow(color: (_active ? Colors.green : Colors.blue).withValues(alpha: .20), blurRadius: 35, spreadRadius: 8)]),
              child: Center(child: _busy
                ? const CircularProgressIndicator(color: Colors.white)
                : Icon(_active ? Icons.power_settings_new : Icons.power_settings_new,
                    color: Colors.white, size: 72)),
            ),
          ),
          const SizedBox(height: 28),
          Text(_active ? '点击断开连接' : '点击连接 VPN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_selected == null ? '尚未选择节点' : '当前配置：${_selected!.name}',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.blueGrey.shade500)),
        ])),
        const SizedBox(height: 18),
        _card(child: Row(children: [
          Expanded(child: _rate(Icons.arrow_upward_rounded, '上传', _fmt(_up))),
          Container(height: 50, width: 1, color: Colors.grey.shade200),
          Expanded(child: _rate(Icons.arrow_downward_rounded, '下载', _fmt(_down))),
        ])),
        if (_error != null && _error!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _card(child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ],
      ],
    );
    final right = _card(child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: Text('我的节点', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          FilledButton.icon(onPressed: _busy ? null : _import,
            icon: const Icon(Icons.add_rounded), label: const Text('导入节点')),
        ]),
        const SizedBox(height: 6),
        Text('单节点链接、HTTPS 订阅、完整 sing-box JSON',
          style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 12)),
        const SizedBox(height: 18),
        if (_profiles.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 36),
            child: Center(child: Column(children: [
              Icon(Icons.dns_outlined, color: Colors.blueGrey.shade300, size: 58),
              const SizedBox(height: 12),
              const Text('还没有配置'),
              const SizedBox(height: 4),
              const Text('点击右上角导入自己的服务器节点', style: TextStyle(fontSize: 12)),
            ])))
        else
          ..._profiles.map((profile) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              tileColor: _selected?.id == profile.id ? const Color(0xffeef5ff) : const Color(0xfff8fafc),
              leading: Icon(Icons.dns_rounded, color: _selected?.id == profile.id ? Brand.primary : Colors.blueGrey),
              title: Text(profile.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(profile.typed.type == ProfileType.remote ? '远程订阅' : '本地配置'),
              trailing: _selected?.id == profile.id ? const Icon(Icons.check_circle, color: Color(0xff1769e0)) : const Icon(Icons.chevron_right),
              onTap: () => _select(profile),
            ),
          )),
        const Divider(height: 34),
        Row(children: [
          const Icon(Icons.shield_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('内核 sing-box $_coreVersion · Android / Windows',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
        ]),
        const SizedBox(height: 10),
        const Text('仅在信任的设备上导入私人节点。首次 Android 连接会请求系统 VPN 权限；Windows 会请求安装系统服务。',
          style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ],
    ));
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Brand.background,
        surfaceTintColor: Colors.transparent,
        title: const Row(children: [
          Icon(Icons.language_rounded, color: Color(0xff1769e0)),
          SizedBox(width: 10),
          Text('OwnNode VPN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ]),
      ),
      body: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          child: isWide
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: left), const SizedBox(width: 22),
                Expanded(flex: 6, child: right),
              ])
            : Column(children: [left, const SizedBox(height: 18), right]),
        ),
      )),
    );
  }

  Widget _rate(IconData icon, String title, String value) => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: Brand.primary, size: 16),
      const SizedBox(width: 5), Text(title, style: const TextStyle(color: Colors.blueGrey)),
    ]),
    const SizedBox(height: 7),
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
  ]);

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _trafficSubscription?.cancel();
    super.dispose();
  }
}

class ImportDialog extends StatefulWidget {
  const ImportDialog({super.key});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  final _name = TextEditingController(text: '我的节点');
  final _data = TextEditingController();
  int _mode = 0;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('导入节点配置'),
    content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(controller: _name, decoration: const InputDecoration(labelText: '配置名称')),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          value: _mode,
          decoration: const InputDecoration(labelText: '导入方式'),
          items: const [
            DropdownMenuItem(value: 0, child: Text('单个节点分享链接')),
            DropdownMenuItem(value: 1, child: Text('HTTPS 订阅地址')),
            DropdownMenuItem(value: 2, child: Text('完整 sing-box JSON')),
          ],
          onChanged: (v) { if (v != null) setState(() => _mode = v); },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _data,
          autocorrect: false, enableSuggestions: false,
          maxLines: _mode == 2 ? 12 : 5,
          decoration: InputDecoration(
            labelText: _mode == 0 ? '节点链接' : (_mode == 1 ? '订阅 URL' : '配置 JSON'),
            alignLabelWithHint: true,
            hintText: _mode == 0 ? 'vless://…\ntrojan://…\nss://…\nhysteria2://…\ntuic://…'
              : (_mode == 1 ? 'https://your-domain.example/subscription' : '{"inbounds": [...], "outbounds": [...], "route": {...}}'),
          ),
        ),
        const SizedBox(height: 10),
        Text(_mode == 0
          ? '支持常见链接参数。WireGuard、复杂传输和高级配置请使用完整 JSON。'
          : (_mode == 1
            ? '订阅会通过 HTTPS 获取并按插件解析器转换，建议使用你自己的订阅源。'
            : '此项适合所有 sing-box 支持的协议，包括 WireGuard endpoint。'),
          style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
      ],
    ))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(
        onPressed: () {
          if (_data.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请先填写节点或配置')));
            return;
          }
          Navigator.pop(context, (name: _name.text, data: _data.text, mode: _mode));
        },
        child: const Text('导入'),
      ),
    ],
  );

  @override
  void dispose() { _name.dispose(); _data.dispose(); super.dispose(); }
}
