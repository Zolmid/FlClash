# 原始 YAML 配置创建

来源为 Patched `6af970661d68dc9eed95bf7276fff27f844d49a8`（`feat(profiles): create local profiles in the editor`），固定参考 tip 为 `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`。这是独立应用层净增量：主线 `f2112fc4ad202bbe597e6728acaef7700eeb58a5` 的 `CustomProfileView` 创建结构化配置，不能替代命名后直接编写完整 YAML 的文件配置。

## 当前实现与边界

`lib/views/profiles/add.dart` 在 QR、文件、链接和 typed custom 之外增加“新建”入口，复用已有 `newProfile` / `newProfileDesc` 翻译和 `AppGlyphs`。命名框使用现有 `InputDialog`，打开时聚焦名字，拒绝全空白名字并移除外层空白。取消命名不会分配数据库项或创建配置文件。

草稿以 `Profile.normal(label: ...)` 创建，类型仍是既有 `ProfileType.file`。`EditorPage(content: '')` 保有文档、输入法组合、dirty、撤销和异步保存状态；新流程没有更换 CodeForge、修改 relaxed YAML 或 typed custom 的数据模型。草稿存在于页面回调中，打开编辑器不会调用 `putProfile`。

保存使用 `CoreController.validateConfig(path)` 验证完整配置，再通过既有 `Profile.saveFile` 将临时文件复制到 profile 文件，成功后才调用 `ProfilesAction.putProfile`。这条入口不调用订阅导入的 `validateProfile` / share-link fallback，不会把原始 YAML 转为结构化配置或重新编码；注释和用户输入的文本保持原样。首次成功配置仍由既有 `putProfile` 设置为当前配置。

验证错误和异常经过现有 `safeRun` 提示，编辑器与草稿保留，可修改或重试。`saveFile` 仅增加 `finally` 删除本次临时文件，覆盖拒绝、异常和成功；原有导入验证器可以准备临时文件并保存其内容，行为不变。验证通过前不会创建目标 profile 文件。

空白未改草稿可直接返回；修改后的返回沿用既有未保存确认，确认则保存，明确取消则丢弃；仅关闭确认弹窗会留在编辑器。保存进行中拒绝第二次保存和返回，不会在验证未完成时插入空配置。保存失败后的“保存并退出”同样保留草稿。

导航复用 `_toAddCustom` 的 `origin` 规则，抽取为同文件 `_openEditor`。同一个 navigator 替换添加页；桌面根 sheet 覆盖 profiles navigator 时，先关闭 sheet 并等待过渡，再在 origin 打开编辑器。typed custom 调用相同规则，批量链接、QR 和文件导入流程不变。

## 回归证据与验证状态

- `test/views/add_profile_view_test.dart`：原有四种入口仍在，同时展示新建入口。
- `test/views/create_profile_test.dart`：使用仓库已有原生 Rust 编辑器测试支持，覆盖命名焦点和校验、trim、取消与无空配置、移动端返回、桌面 sheet 的 navigator、完整 YAML 原文保存、无效配置、验证异常和文件写入失败后重试、重复保存与 busy 返回、丢弃、退出保存失败后重试。
- `test/models/profile_file_test.dart`：无效内容保留已有文件，验证异常不创建目标文件，成功准备后的字节仍保存；三条路径均清理临时文件。

上述聚焦 suite 已由 root 执行通过；最终统一格式、分析、全量回归和覆盖率结果见 [验证记录](validation.md)。真实 iOS/Android 输入法、键盘和文件写入行为仍需对应平台验收。
