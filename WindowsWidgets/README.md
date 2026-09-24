# Windows 11 小组件面板适配

此项目在 Windows 11 的小组件面板中提供一张显示五小时及一周剩余额度、恢复时间的卡片。它通过本机 Codex `app-server` 查询额度；“刷新额度”由卡片操作触发，已固定的卡片也会定期刷新。读取失败时会显示仍在对应额度窗口内的上次成功值，并标明上次更新时间；本地缓存位于当前用户的 `%LOCALAPPDATA%\CodexQuotaWidget\board-quota-cache.json`。任务 Token 详情仍由桌面版显示。安装后从任务栏天气入口打开小组件面板，点“+”选择“Codex 额度”。它是无独立窗口的小组件提供程序，不会出现在开始菜单应用列表中。

项目使用 Windows App SDK 小组件提供程序和 MSIX 打包，适用于 Windows 11 小组件面板。桌面悬浮 `.exe` 保留在仓库根目录，两者可以分别使用。

## 构建

本机开发需要 .NET 8 SDK、Visual Studio 2022 的 Windows 应用开发组件，以及 Windows App SDK。运行 `Generate-Assets.ps1` 可重新生成图标。仓库的 `Build Windows 11 widget` 工作流在 Windows runner 上构建未签名的 MSIX，供检查与测试。MSIX 内含 .NET 运行环境；Windows App Runtime 仍须已安装。

这个 MSIX 是供 Windows 11 本机测试的未签名包，清单含微软要求的未签名标记。测试前需要在“设置 → 系统 → 高级 → 开发人员选项”中启用开发人员模式，再用管理员 PowerShell 运行 `Add-AppxPackage -Path <MSIX 文件> -AllowUnsigned`；含可执行程序的未签名包会面向所有用户安装。正式分发应删除清单中的未签名标记，改用可信证书签名或通过 Microsoft Store 发布。公开发布前还需在真实 Windows 11 小组件面板中验证卡片的显示、固定、刷新和卸载。

## 数据与来源

此提供程序不会上传任务文件或任务标题。额度查询仍可能由 Codex 连接其自身服务。`WidgetHelper` 中的 COM 注册辅助代码取自 [Microsoft Windows App SDK Samples](https://github.com/microsoft/WindowsAppSDK-Samples/tree/main/Samples/Widgets/cs-console-packaged)，保留原文件中的版权声明，并附带 `MICROSOFT-SAMPLE-LICENSE.txt`。
