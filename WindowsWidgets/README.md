# Windows 11 小组件面板适配

此项目在 Windows 11 的小组件面板中提供一张显示五小时及一周剩余额度、恢复时间的卡片。它通过本机 Codex `app-server` 查询额度；“刷新额度”由卡片操作触发，已固定的卡片也会定期刷新。刷新时若已有查询正在进行，新的请求会合并为下一次查询，不会静默丢弃。连续读取失败时，自动重试间隔从 2 分钟逐步延长至最多 16 分钟；手动刷新仍可立即请求。读取失败时会显示仍在对应额度窗口内的上次成功值，并标明失败类别和上次更新时间；本地缓存位于当前用户的 `%LOCALAPPDATA%\CodexQuotaWidget\board-quota-cache.json`。任务 Token 详情仍由桌面版显示。安装后从任务栏天气入口打开小组件面板，点“+”选择“Codex 额度”。它是无独立窗口的小组件提供程序，不会出现在开始菜单应用列表中。

项目使用 Windows App SDK 小组件提供程序和 MSIX 打包，适用于 Windows 11 小组件面板。桌面悬浮 `.exe` 保留在仓库根目录，两者可以分别使用。

## 构建

本机开发需要 .NET 8 SDK、Visual Studio 2022 的 Windows 应用开发组件，以及 Windows App SDK。运行 `Generate-Assets.ps1` 可重新生成图标。仓库的 `Build Windows 11 widget` 工作流在 Windows runner 上构建未签名的 MSIX，供检查与测试。MSIX 内含 .NET 运行环境；Windows App Runtime 仍须已安装。

这个 MSIX 是供 Windows 11 本机测试的未签名包，清单含微软要求的未签名标记。测试前需要在“设置 → 系统 → 高级 → 开发人员选项”中启用开发人员模式，再用管理员 PowerShell 运行 `Add-AppxPackage -Path <MSIX 文件> -AllowUnsigned`；含可执行程序的未签名包会面向所有用户安装。正式分发应删除清单中的未签名标记，改用可信证书签名或通过 Microsoft Store 发布。公开发布前还需在真实 Windows 11 小组件面板中验证卡片的显示、固定、刷新和卸载。

## 故障诊断

读取和刷新结果写入当前用户的 `%LOCALAPPDATA%\CodexQuotaWidget\board-diagnostics.jsonl`，达到 128 KiB 后轮换为 `.old`。每行只有 UTC 时间、动作、错误类别和耗时；不记录 Codex 的原始响应、任务标题、会话内容或凭据。卡片上的“未找到 Codex 程序”“读取超时”“额度响应格式异常”等文字可与记录中的 `code` 对照。该文件可删除，下一次刷新时会重新建立。面板版已经在真实 Windows 11 小组件面板中确认选择器可见、额度数据显示和手动刷新成功；其余验收项目仍见下文。

`test/board` 用共用响应样本验证额度解析和过期缓存，并用仅供编译的接口替身检查提供程序源码；Windows CI 还会用真正的 Windows App SDK 构建 MSIX。接口替身测试不能代替面板安装验收。

面板安装验收清单：在小组件选择器中找到“Codex 额度”；显示两档额度；手动刷新能获得新数据；刷新按钮在连续点击和读取进行中仍能得到新数据；退出登录或断网时显示错误类别及旧数据时间；恢复连接后恢复新数据；重启后固定状态仍在；卸载后选择器条目消失。当前源码版本为 0.1.5。前三项已由用户在 Windows 11 上确认；后续项目尚未验收。

## 数据与来源

此提供程序不会上传任务文件或任务标题。额度查询仍可能由 Codex 连接其自身服务。`WidgetHelper` 中的 COM 注册辅助代码取自 [Microsoft Windows App SDK Samples](https://github.com/microsoft/WindowsAppSDK-Samples/tree/main/Samples/Widgets/cs-console-packaged)，保留原文件中的版权声明，并附带 `MICROSOFT-SAMPLE-LICENSE.txt`。
