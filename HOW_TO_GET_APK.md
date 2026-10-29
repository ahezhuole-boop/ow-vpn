# 获取 Android 安装包 APK（本 ZIP 当前尚不包含 APK）

本项目仍是 Flutter 源码，且没有 `android/` 原生工程文件。不能把源代码改名为 APK。

**方式一：GitHub Actions 自动生成测试 APK**

1. 登录 GitHub，建立一个**私有**仓库（千万不要上传真实节点密码/密钥）。
2. 解压本 ZIP，把内层全部文件**包含隐藏的 `.github/workflows/android-apk.yml`** 上传至仓库根目录。
3. 在 GitHub 仓库页面点 `Actions` → `Android APK test build` → `Run workflow`。
4. 构建成功后，点该次运行，在 `Artifacts` 下载 `ownnode-android-debug-apk`。
5. 解压得到 `app-debug.apk`，这只是供自己测试的调试包，不是正式的签名发布包。

**重要：构建尚未验证！** 当前制作环境没有 Flutter、Android SDK，也不能联网下载相关依赖。因此 Action 可能在 Flutter、Gradle、插件 API、Android Manifest 或原生 VPN 服务集成处失败，届时需根据构建日志修复，不能保证第一次运行就成功。

**方式二：本地 Flutter + Android SDK**

```bash
flutter create --platforms=android --project-name own_node_vpn --org com.example.ownnode .
flutter pub get
# 如果 flutter create 生成了默认 test/widget_test.dart，且其引用不存在的 MyApp，请删除该默认测试。
flutter test
flutter build apk --debug
```

成功后文件位于 `build/app/outputs/flutter-apk/app-debug.apk`。

Windows 使用 `.github/workflows/windows-app.yml` 或安装 Windows Flutter 工具链进行构建；最终必须保留完整 Release 目录。
