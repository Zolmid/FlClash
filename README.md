# ZolNit 完整迁移包

当前客户端提交：`e5b028510880531cad739e2ac700783eeb75eda8`，开发分支 `codex/zolnit-client`。

这个独立打包分支只用于交付已有开发工作区，不替换 main 或应用开发分支，不触发应用编译和发布。

## 一次下载整个包

在本分支点击 **Code → Download ZIP**，下载并解压完整文件夹。无需分别下载文件。

[下载完整 ZIP](https://github.com/Zolmid/FlClash/archive/refs/heads/codex/migration-package-20261021.zip)

## 恢复到本地

在解压后的文件夹打开终端。安装 Git 与 Python 3.9+ 后运行：

```bash
python3 RESTORE.py --restore
```

Windows 使用 `py -3 RESTORE.py --restore`。默认恢复到用户主目录下 `Developer/ZolNit-Workspace`，拒绝覆盖已有目录。可追加 `--destination "自选的新目录"`。

脚本自动校验并合并内部数据、恢复原始 ZIP、执行已经实测的离线恢复。不联网、不安装工具、不启动 App/VPN，不自动 push 或合 main。

只合并原始 ZIP：`python3 RESTORE.py`。仅验证内部数据：`python3 RESTORE.py --verify-only`。

恢复后在 `ZolNit-Workspace/FlClash` 新建本地 Work，先读上一级的 `CONTINUE-IN-CODEX.md` 和 `MIGRATION.md` 及仓库 `AGENTS.md`，继续原 GitHub 分支开发。

## 包含内容与验证

完整源码和 Git 历史、固定原上游 core、Web 预览及历史、用户品牌包、审计与隔离补丁、云机已有的 Linux 二进制。SDK 和机器缓存不打包，云端凭据、Mac Stripe 私有配置和签名材料不在包内。

原包：351,711,445 bytes；完整包 SHA256：

```text
203216d54f4c5d4d37722cb075709d05a7ce4970593322465ffb0e8940737d3c
```

本地实际合并与离线恢复验证已通过：6 个仓库、745 个 Git 引用、5,650 个文件/链接、工作区状态与固定子模块均匹配。

原 ZIP 超过 GitHub 普通 Git 单文件上限，内部按字节拆分保存；GitHub Download ZIP 将它们作为一个完整下载交付，恢复脚本自动处理，无需手工拼接。

迁移验证不代表支付 SDK、Apple 沙盒或真机 VPN 已验证。正式客户端状态及证据以包内交接文件为准。
