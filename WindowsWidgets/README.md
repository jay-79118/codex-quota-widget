# Windows 11 小组件面板适配

此项目在 Windows 11 的小组件面板中提供一张显示五小时及一周剩余额度、恢复时间的卡片。它通过本机 Codex `app-server` 查询额度；“刷新额度”由卡片操作触发，已固定的卡片也会定期刷新。任务 Token 详情仍由桌面版显示。

项目使用 Windows App SDK 小组件提供程序和 MSIX 打包，适用于 Windows 11 小组件面板。桌面悬浮 `.exe` 保留在仓库根目录，两者可以分别使用。

## 构建

本机开发需要 .NET 8 SDK、Visual Studio 2022 的 Windows 应用开发组件，以及 Windows App SDK。运行 `Generate-Assets.ps1` 可重新生成图标。仓库的 `Build Windows 11 widget` 工作流在 Windows runner 上构建未签名的 MSIX，供检查与测试。

未签名的 MSIX 不能作为普通安装包直接分发。正式安装需要与清单发布者一致的签名证书，以及适当的安装信任方式。公开发布前还需在真实 Windows 11 小组件面板中验证卡片的显示、固定、刷新和卸载。

## 数据与来源

此提供程序不会上传任务文件或任务标题。额度查询仍可能由 Codex 连接其自身服务。`WidgetHelper` 中的 COM 注册辅助代码取自 [Microsoft Windows App SDK Samples](https://github.com/microsoft/WindowsAppSDK-Samples/tree/main/Samples/Widgets/cs-console-packaged)，保留原文件中的版权声明，并附带 `MICROSOFT-SAMPLE-LICENSE.txt`。
