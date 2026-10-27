# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · [Português](README.pt.md) · [Français](README.fr.md) · **简体中文**

收集 Android 诊断数据并打开本地报告。适用于 Windows，无需管理员权限。

## 开始使用

1. 通过 USB 连接手机，并在手机上开启 USB 调试。
2. 打开普通的 **Windows PowerShell** 窗口。
3. 粘贴以下命令：

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

确认安装和数据收集。如果尚未安装 ADB，程序会提示下载。请在手机上允许这台计算机进行调试。收集完成后，选择 **1 — 打开报告** 或 **2 — 打开报告文件夹**。程序不会自动打开窗口；按 Enter 结束。

当程序确认安全 ZIP 已准备好后，将 **ADBMedic-report.zip** 附加到你使用的 AI 聊天中（如 ChatGPT、Claude 等），并让它遵循压缩包内的说明。压缩包包含测量数据，以及要求 AI 给出清晰结论、详细操作步骤和后续反馈指引的说明。选项 2 可打开 ZIP 所在文件夹。如果聊天服务无法读取 ZIP，请解压并附加 REPORT.md、facts.json 和 MANUAL-ANALYSIS-PROMPT.md。

诊断界面目前支持俄语和英语，并根据 Windows 的显示语言自动选择；其他语言的系统使用英语。无需选择模式或添加命令参数。

## 已下载项目？

在项目文件夹中打开 PowerShell，然后运行：

```powershell
.\bootstrap.ps1
```

## 数据与隐私

脚本读取诊断数据，并将其保存在计算机上的 `%LOCALAPPDATA%\ADBMedic` 中。它不会更改手机设置，也不会将诊断数据上传到云端。

本地报告属于私密文件。只分享程序准备的 ZIP：其中包含经过验证的数值测量和仅适用于本次会话的进程标签，不包含身份标识或原始日志。验证失败时不会创建可分享的 ZIP。程序不会自动诊断或向 AI 上传数据；分析由你选择的聊天服务完成。[导出格式与限制](../SAFE-HANDOFF.md)。

已在 Windows PowerShell 5.1 中测试。完整的真机运行仍有待验证。

[开发指南：测试、Git 保护和高级选项](../DEVELOPMENT.md) · [MIT 许可证](../../LICENSE)
