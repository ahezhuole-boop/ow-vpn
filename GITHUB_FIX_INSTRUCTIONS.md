# v0.3.1 修复：GitHub Actions libbox 下载失败

## 原因
Gradle 需要 `com.github.singbox-android:libbox:1.14.3`，但默认 Flutter Android 工程没有 JitPack Maven 仓库。

## 你需要在 GitHub 上做的事
1. 仓库根目录一定要有 `lib/main.dart`、`lib/brand.dart`、`lib/node_links.dart`、`lib/privacy_config.dart`。若没有，解压本 ZIP，上传整个 `lib` 目录及其中的四个文件（不要把外层目录作为仓库子文件夹）。
2. 替换 `.github/workflows/android-apk.yml` 为 ZIP 内同名文件。
3. 提交到默认分支，进 Actions → Android APK test build → Run workflow 重新编译。
4. 成功后进入该次运行记录，在 Artifacts 中下载 `ownnode-android-debug-apk`。

## 仍可能遇到的问题
本修复针对缺少 JitPack 仓库，未在 Github Actions 真正运行验证。如果 JitPack 发布、网络、Gradle 插件或其他 Dart/Android 原生配置发生错误，需按新的第一条错误信息进一步处理。不要将任何真实节点密码/订阅令牌直接上传到公开仓库。

## 发布注意
debug APK 仅用于测试。程序的 VPN 功能与零日志运行效果都还没有通过真实设备测试、安全审计。
