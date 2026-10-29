# OwnNode VPN 隐私设置开发版 v0.3 — Android + Windows + 官网页面

> **此项目为品牌化开发起步包，不是可直接安装的 APK/EXE，也不是已经上线的 VPN 服务。**
> `OwnNode VPN` 是临时品牌名；只有您确认并审核品牌、商标及域名后才能当作正式品牌发布。

## v0.3 新增（在 v0.2 基础上）

- 新增 `lib/privacy_config.dart`：导入/选择 sing-box JSON 配置时强制设置 `log.disabled=true`，如无法识别配置则拒绝连接。**这只能控制内核日志，不能代表整个 VPN 服务已经实现零日志。**
- 新增 `server/`：服务端关闭 sing-box 日志的示例片段与“只记录用量”隐私设计说明；未包含真实 VPS 服务端或流量统计后台。
- 新增 `.github/workflows/`：Android 与 Windows 云端编译工作流**草案**，让你可以自行触发构建；目前尚未在实际 CI 执行，不能保证一次通过。
- 新增 `HOW_TO_GET_APK.md`：清晰说明如何得到测试 APK、项目仍缺少原生工程且不存在现成 APK。

## 本版未实现

- 不含可直接安装的 APK/EXE；本环境无 Flutter SDK/Android SDK 且无法下载依赖，也没法真实构建。
- 没有服务端各用户流量用量采集、数据库、管理后台、用户注册/付费。
- 不能对应用 SDK/订阅服务器、系统、VPS 机房及其他第三方的数据处理做“0 日志”保证。
- 未做安全审计、实际 VPN 连接测试和上架前审核。

## 原 v0.2 版功能

1. Flutter 客户端统一品牌文字、颜色和导航标志：`lib/brand.dart`。
2. 响应式中文官网设计：`website/index.html`、`website/styles.css`，含真实「开发中」说明。
3. 网站 SVG + PNG logo：`website/assets/logo.svg` 与 `logo-192.png`、`logo-512.png`。
4. 隐私说明草案（不是正式政策）：`website/privacy.html`。
5. 品牌运营系统架构与发布检查：`docs/ARCHITECTURE.md`、`docs/RELEASE_CHECKLIST.md`。

## 开网站预览（不用配置服务器）

在 `website` 文件夹直接用浏览器打开 `index.html` 即可预览。也可以运行：

```bash
cd website
python -m http.server 8000
```

随后使用浏览器访问 `http://localhost:8000`。**这是官网设计预览，不是 VPN 服务。**

## 修改品牌

- **软件名称/宣传语/配色**：修改 `lib/brand.dart`。
- **网页名称和文案**：修改 `website/index.html`、`website/privacy.html`。
- **官网配色**：修改 `website/styles.css` 顶部的 `:root` 变量。
- **Logo**：修改 `website/assets/logo.svg` 并重新导出 PNG；Flutter 的内置图标位于 `lib/brand.dart`。
- **正式系统应用图标**：在创建项目原生 Android/Windows 文件后，还需要配置 Android launcher icon 和 Windows `.ico`，当前尚未包含原生资源集成。
- **包名和发行标识**：在 `flutter create` 时替换 `com.example.ownnode`，并在真实项目中正确配置 applicationId、Windows 标识及签名。

## Android / Windows Flutter 客户端源码

依赖：Flutter >=3.44、Dart >=3.12（请以实际使用的插件版本要求为准）。本包保留 v0.1 版的连接与节点导入起步代码，**目前没有在 Android/Windows 上编译和测试**。

```bash
# 在本项目根目录，先生成原生项目工程文件
flutter create --project-name own_node_vpn --org com.example.ownnode --platforms=android,windows .
flutter pub get
flutter analyze
flutter test

# Android 需 Android SDK
flutter build apk --release

# Windows 需在 Windows 上安装 Visual Studio C++ 桌面开发工具
flutter build windows --release
```

Flutter 客户端使用 `flutter_sing_box` + `sing-box` 底层；起步版提供普通 VLESS、Trojan、Shadowsocks、Hysteria2、TUIC 单节点链接、HTTPS 订阅、完整 sing-box JSON。WireGuard 当前通过 endpoint 类型的完整 JSON 导入，**没有** WireGuard `.conf` 文件转换器。实际是否连接成功需以终端与服务端测试为准。

### 重要限制

- 所有 VPS、域名、证书和节点都由你自行提供；示例包中没有真实可用的节点。
- 没有账号注册、付费订阅、管理后台、服务端 API；未来系统规划在 `docs/ARCHITECTURE.md`。
- 官网中的「下载」仅跳到开发状态提示，不会提供尚未验证的安装包。
- 本地节点配置可能包含密码，当前**没有保证安全加密存储**。
- 生成的默认 DNS/TUN 模板没有完成实测，不能保证断线保护、DNS/IPv6/WebRTC 无泄漏。
- Windows 的插件服务名称可能与其他软件冲突，正式发布前需要评估隔离和改名方案。
- `flutter_sing_box` / `sing-box` 采用 GPL-3.0 授权，必须审查并履行相关开源分发义务；不能随意宣称闭源自研。
- Android 上架需符合 Google Play VpnService 相关规则，网站隐私说明只是草案，不可作为正式隐私合规文件。

## 参考资料
- Flutter 文档: https://docs.flutter.dev/
- Flutter sing-box 插件: https://pub.dev/packages/flutter_sing_box
- sing-box 配置文档: https://sing-box.sagernet.org/
- Google Play VpnService 政策: https://support.google.com/googleplay/android-developer/answer/12564964
