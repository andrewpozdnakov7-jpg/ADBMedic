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

诊断 ZIP 准备好后，将 **ADBMedic-report.zip** 发给你信任的 AI，并要求遵循内附说明。AI 应调查原因，按真实应用解释耗电，注明数值、事件类型和统计时段，提供操作步骤并验证结果。数据不足时，应给出有针对性的只读 ADB 命令及解释。[完整 AI 职责](../../AI-ANALYST.md)。选项 2 打开文件夹。不支持 ZIP 时，请附加 REPORT.md、facts.json、MANUAL-ANALYSIS-PROMPT.md 及 evidence 中相关文件。

诊断界面目前支持俄语和英语，并根据 Windows 的显示语言自动选择；其他语言的系统使用英语。无需选择模式或添加命令参数。

## 已下载项目？

在项目文件夹中打开 PowerShell，然后运行：

```powershell
.\bootstrap.ps1
```

## 数据与隐私

脚本读取诊断数据，并将其保存在计算机上的 `%LOCALAPPDATA%\ADBMedic` 中。它不会更改手机设置，也不会将诊断数据上传到云端。

ZIP 属于私密诊断资料，保留问题描述、机型/Android、采集时间、真实进程和软件包名称、UID/PID 及详细诊断。请先检查，再决定是否发给所选 AI。不要发布到 GitHub。发现已知凭据或私钥模式时会阻止打包，但不能保证发现所有秘密。程序不会自动上传或执行 AI 建议。[格式与限制](../SAFE-HANDOFF.md)。

已在 Windows PowerShell 5.1 中测试。完整的真机运行仍有待验证。

[开发指南：测试、Git 保护和高级选项](../DEVELOPMENT.md) · [MIT 许可证](../../LICENSE)
