# ADBMedic

[English](../../README.md) · [Русский](README.ru.md) · [Español](README.es.md) · [Português](README.pt.md) · [Français](README.fr.md) · **简体中文**

手机耗电快或发热？ADBMedic 会准备一份报告，供你信任的 AI 分析原因并建议下一步操作。

需要 **Android 手机、Windows 电脑，以及支持数据传输的 USB 线**。无需在手机上安装应用。

## 1. 准备手机

1. 打开 **设置 → 关于手机 → 版本号**。它也可能在 **软件信息** 中。连续点击 **7 次**，如有提示，输入手机解锁 PIN。
2. 在设置中找到 **开发者选项**，开启 **USB 调试**。各品牌菜单名称可能不同，可以使用设置中的搜索。
3. 解锁手机，用 USB 线连接到自己的电脑。

## 2. 在电脑上启动

打开开始菜单，搜索 **Windows PowerShell**，正常打开即可，**不需要管理员权限**。

复制下面的命令，粘贴到 PowerShell，然后按 **Enter**：

```powershell
irm https://raw.githubusercontent.com/andrewpozdnakov7-jpg/ADBMedic/main/run.ps1 | iex
```

- 安装和采集提示出现时，输入 **y** 并按 Enter。如果提示下载所需工具，也请确认。
- 留意手机：如弹出 **允许 USB 调试？**，请为自己的电脑点击 **允许**。
- 描述问题，例如“晚上不用手机，电量也下降很多”，然后等待采集完成。

## 3. 将结果交给 AI

1. 在 PowerShell 中选择 **2**，打开报告文件夹。选择 **1** 可以自己查看报告。
2. 将 **ADBMedic-report.zip** 附加到 ChatGPT、Claude 或其他你信任的 AI 聊天中。
3. 粘贴 PowerShell 显示的启动提示词。相同文字也保存在 ZIP 旁边的 **START-PROMPT.txt** 中。

AI 应解释观察结果、给出操作步骤，或要求有针对性的补充检查。默认使用 Windows 显示语言回答；你也可以要求其他语言。

**找不到手机？** 解锁手机，确认调试授权，并尝试另一根数据线或另一个 USB 接口。如果没有生成 ZIP，请保留错误提示，不要自行压缩整个文件夹。

报告包含手机和应用的私密信息。脚本不会自动发送数据。只将 ZIP 交给你选择的 AI，不要发布到 GitHub。结束后可以关闭 USB 调试。脚本界面目前使用俄语或英语。

<details>
<summary>已经下载了项目？</summary>

在项目文件夹中打开 PowerShell，运行：

```powershell
.\bootstrap.ps1
```

</details>

[技术说明与开发](../DEVELOPMENT.md) · [MIT 许可证](../../LICENSE)
