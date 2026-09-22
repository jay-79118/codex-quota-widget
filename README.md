# Codex 额度小组件（Windows）

一个常驻桌面的迷你小组件，显示 Codex 五小时和一周额度的剩余比例及恢复时间，并查看本机任务的 Token 用量。

## 运行条件

- Windows 10/11、Windows PowerShell 5.1。
- 已登录的 Codex 桌面版或可用的 `codex` 命令。
- Node.js 18 或更新版本，且 `node.exe` 位于 `PATH` 或默认安装目录。

## 使用

只需下载 `CodexQuotaWidget.exe` 并双击启动。若要直接运行源码，则把 `CodexQuotaWidget.ps1`、`data.js` 和 `CodexQuotaWidget.ico` 放在同一文件夹，再使用 `启动小组件.vbs` 或 `启动小组件.cmd`。启动器会隐藏 PowerShell 控制台；小组件和通知区域仍可访问。首次读取通常需要数秒，之后每 60 秒刷新。重复启动不会创建第二个小组件。

`.exe` 已内置小组件脚本、数据脚本和图标，可以单独下载。首次运行会将这些文件放在当前用户的 `%LOCALAPPDATA%\CodexQuotaWidget` 文件夹，设置也保存在那里；不会修改系统安装。额度查询仍依赖已安装的 Codex 和 Node.js。可用 Windows PowerShell 5.1 运行 `build-exe.ps1`，从 `WidgetLauncher.cs` 和同目录源码重新编译。

更新 `.exe` 后，先从小组件右键菜单退出旧实例，再运行新版，让新脚本生效。

当前 `.exe` 未使用代码签名证书，Windows 下载后可能显示发布者未知。可用仓库里的源码和构建脚本自行核对并重新编译。

启动器使用 `-ExecutionPolicy Bypass`，仅对这次 PowerShell 进程生效；运行前请确认脚本来自你信任的来源。

- 右键菜单可切换双圆环或跑道皮肤、四种配色、50%～150% 无级大小，也可手动刷新、查看任务 Token 或退出。
- 悬停显示两档额度的剩余比例与恢复时间。按住并移动小组件可拖动位置。
- 跑道中央两行依次显示五小时和一周信息；点击中央切换剩余比例与恢复时间。
- 双圆环中央可点击打开任务 Token 详情。

## 数据与隐私

额度通过本机 Codex `app-server` 接口获取。任务 Token 从当前 Windows 用户的 `~/.codex/sessions` 会话文件读取，仅代表本机记录，其他设备的任务可能缺失。程序不会自行上传任务标题或会话文件，也不需要额外 API 密钥；Codex 获取额度时仍可能访问自己的服务。

任务标题仅对少数明显包含“密码”“密钥”等字样的内容做遮盖，**不能保证所有私人标题都会自动隐藏**。录屏或分享截图前请检查任务详情。`settings.json` 是运行时生成的个人偏好文件，不应提交到公开仓库。

“剩余额度”是时间窗口的剩余百分比，不是剩余 Token 数。任务的缓存输入 Token 已包含在输入 Token 中，不应重复相加。

## 文件

- `CodexQuotaWidget.ps1`：WPF 界面和交互。
- `data.js`：读取额度和本机会话 Token 统计。
- `CodexQuotaWidget.ico`：通知区域图标。
- `CodexQuotaWidget.exe`、`WidgetLauncher.cs`、`build-exe.ps1`：启动程序、源码和构建脚本。
- `启动小组件.vbs`、`启动小组件.cmd`：无控制台启动入口。

## 已知限制

Codex 本地接口和会话文件格式可能变化，更新 Codex 后若额度或任务数据无法读取，请先使用右键菜单“刷新额度”。此工具是独立的社区作品，与 OpenAI 没有官方关联。

## 许可证

公开发布前由项目所有者确定并添加 `LICENSE` 文件。
