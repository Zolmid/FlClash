# 原生语言资源审计

本批基于已提交的整合版本 `88476f4641da39e1dd24c84f065aa06054ab2200`，
来源为 Patched `323f678d2f4fed3aa08a409cdfbb2e06a32e95b0`
（`feat(l10n): add Traditional Chinese across app and native platforms`）。
该提交修改的 Windows 文件是安装器资源，不包含 `windows/runner/Runner.rc`。

## Flutter 与原生界面的边界

首批整合已接入 Flutter 的 `zh_TW` ARB、生成消息与语言选项，适用于各 Flutter 平台。
本批补齐独立于 Flutter 文案的安装器、Android 通知渠道及 macOS 资源。
安装器按安装时选择的语言显示；Android 和 Apple 原生资源按系统语言选择。
修改应用内 Flutter 语言设置，不代表这些原生界面会立即切换语言。

## 迁入范围

| 平台 | 来源中的真实增量 | 当前适配 |
| --- | --- | --- |
| Windows | 新增 `ChineseTraditional.isl`，安装器启用 `en/ja/ru/zh/zh_TW`，模板支持繁中并为本地 ISL 路径加引号。 | 原样迁入繁中 ISL；日语、俄语使用 Inno 自带文件。本地简中、繁中路径仍相对于生成脚本所在的 `dist/`。保留主线其他语言分支、简中版本和正确的项目根目录图标路径。 |
| Android common | 新增 `values-b+zh+Hant/strings.xml`，包含 `app_name` 和 `service_channel_name`。 | 原样迁入这两个现有键。`Ext.kt` 实际使用通知渠道名称；不添加参考 app/service 中当前没有消费者的键，已有 app/service 繁中保持原样。 |
| macOS | 新增 `InfoPlist.xcstrings` 的五语定位说明；为既有 `MainMenu.xcstrings` 加入18个繁中翻译，并声明 `zh-Hant`。 | 迁入该提交时的两个完整目录及其五种已有语言，补 Xcode 资源引用、MainMenu variant group、knownRegions 和 Info.plist 语言声明。18个菜单键的对象 ID、属性和英文值均匹配当前 Base XIB；不改 XIB、窗口行为或品牌。 |
| iOS | Runner/Widget 字符串目录及工程、plist 增加繁中。 | 首批已经具备三目录中的5、11、3项繁中，以及 `zh-Hant` 声明；本批不重复修改。 |

macOS 菜单目录在更早的 `8012efc6fcf06515c11d9da1dc0ddca205fe46be` 已存在，
本批使用 `323f678d` 的最终目录内容，使现有非繁中翻译也有对应源文件。
范围是来源中的18个菜单键和定位说明，不声称补译了当前 XIB 的所有其他文字。
Windows AppId、发布者、安装权限、版本、独立 nonce ready/ack 握手及上游发布 guard 保持原样。

## 安装器字段的实际 provider 验证

`setup.dart` 固定的 `chen08209/flutter_distributor` 标签 `v0.6.11-flclash.3`
指向提交 `1e640ce6199c02fdf30e5e26ab70a213564db74a`
（annotated tag object 为 `4c48f606cbda7d04aa71ebda5cdea5e13b0c3315`）。
该版本的 [MakeExeConfig.fromJson](https://github.com/chen08209/flutter_distributor/blob/1e640ce6199c02fdf30e5e26ab70a213564db74a/packages/flutter_app_packager/lib/src/makers/exe/make_exe_config.dart)
只识别 `publisher_name` 或旧别名 `appPublisher`，不识别 `publisher`；
[InnoSetupScript.createFile](https://github.com/chen08209/flutter_distributor/blob/1e640ce6199c02fdf30e5e26ab70a213564db74a/packages/flutter_app_packager/lib/src/makers/exe/inno_setup/inno_setup_script.dart)
从 `publisherName` 提供 `PUBLISHER_NAME` 给 Liquid，并删除 null 变量。
使用真实 provider 渲染旧配置，结果是空的 `AppPublisher=`，不是保留一个可见占位符。
因此字段修为 `publisher_name: chen08209`，没有借此替换上游作者。

`AppPublisherURL` 和 `AppSupportURL` 保留 `https://github.com/chen08209/FlClash`。
`AppUpdatesURL` 单独指向 `https://github.com/Zolmid/FlClash/releases/latest`，
与当前 `repository` 和应用更新器一致，避免把此整合版本引导到上游安装包。
这个链接不改变自动更新、签名或正式发布的权限。

`windows/packaging/exe/test/` 是独立的纯 Dart 验证包，固定同一 provider 提交并保存依赖锁，
不改应用或 `setup.dart` 的依赖版本。它直接调用实际 `MakeExeConfig` 和
`InnoSetupScript.createFile()`，检查作者、AppId、品牌、权限、上游/更新来源、
五种语言、占位符替换和原 nonce 握手保留。测试的 Inno 目录只模拟语言文件存在性，
不模拟字段映射或 Liquid 渲染，也不调用 ISCC。修正后两项实际 provider 测试通过，
该独立包的 `dart analyze` 和格式检查也通过。

```bash
cd windows/packaging/exe/test
dart pub get --enforce-lockfile
dart analyze
dart test
```

## 验证

`test/l10n/native_localization_test.dart` 检查安装器配置与模板的五种语言一致、
本地 ISL 引用带引号且从 `dist/` 可解析、语言 ID 与当前用到的自定义消息存在；
检查 Android common 资源键和实际通知渠道调用；检查 macOS 菜单键与当前 XIB 的对应关系、
五语内容、bundle 语言声明和 Xcode 资源引用。
与已有 `test/setup_test.dart` 一起在临时纯 Dart 包中使用现有离线依赖验证，
23项全部通过；定向 `dart analyze`、格式和差异检查通过。
子任务未单独触发根项目 Flutter hooks 或代码生成，也未增加应用依赖；独立验证包的固定 dev 依赖另见上节。根任务统一执行 Flutter 门禁。

本机没有 Inno Setup、Android 设备或 Xcode；静态契约不等于安装器已完成 ISCC 编译，
也不证明系统语言选择、权限弹窗或原生菜单的运行效果。需要对应 Windows/macOS 构建及设备验证。
