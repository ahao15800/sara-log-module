# Sara Log Pusher & AI Diagnostic Module

这是一个面向 Android 16 和 HyperOS 深度调优的 KernelSU / ReSukiSU 模块。它能够自动采集、分析并上传系统底层日志，协助解决系统微掉帧、隔离失效及 TEE 状态异常等问题。

## 主要功能
- **自动化运行**: 每 5 分钟检查一次，若距上次成功上传超过 27 小时，则自动执行备份任务。
- **深度诊断**: 
  - **命名空间审计**: 检测微信等应用的 Mount Namespace 是否被成功隔离。
  - **Binder 事务审计**: 监控系统卡顿（Micro-stutter）的元凶 —— Binder 锁竞争。
  - **TEE 健康度**: 实时检查 Keybox 和 TrickyStore 注入状态。
  - **热管理监控**: 记录 CPU 频率与温度限制。
- **可视化配置**: 内置 Sleek Cyberpunk 风格 WebUI，通过 KernelSU 管理器即可轻松配置 GitHub Token。

## 使用说明
1. 在 GitHub 设置中生成一个具有 `contents:write` 权限的 Personal Access Token。
2. 在 KernelSU 管理器中安装本模块。
3. 打开模块的 WebUI，输入 Token 和你的私有日志仓库名（如 `ahao15800/sara-logs`）。
4. 点击“保存配置”，然后点击“立即体检”测试连接。

## 注意事项
- 本模块需要联网权限（用于 curl 上传）。
- 建议配合私有仓库（Private Repository）使用，以保护系统隐私。
