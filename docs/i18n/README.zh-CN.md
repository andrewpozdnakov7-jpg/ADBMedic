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

确认安装和数据收集。如果尚未安装 ADB，程序会提示下载。请在手机上允许这台计算机进行调试。数据收集完成后，报告会自动在浏览器中打开。

诊断界面目前支持俄语和英语，并根据 Windows 的显示语言自动选择；其他语言的系统使用英语。无需选择模式或添加命令参数。

## 已下载项目？

在项目文件夹中打开 PowerShell，然后运行：

```powershell
.\bootstrap.ps1
```

## 数据与隐私

脚本读取诊断数据，并将其保存在计算机上的 `%LOCALAPPDATA%\ADBMedic` 中。它不会更改手机设置，也不会将诊断数据上传到云端。

目前报告仅汇总收集到的数据，尚不提供自动诊断。向 AI 发送数据和导出诊断 ZIP 的功能均已禁用。本地文件可能包含个人信息，请勿公开发布。

已在 Windows PowerShell 5.1 中测试。完整的真机运行仍有待验证。

[开发指南：测试、Git 保护和高级选项](../DEVELOPMENT.md) · [MIT 许可证](../../LICENSE)
