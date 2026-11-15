# CI、发布与恢复维护指南

源码基线为 `d0af9d83c4f37199caceb436b3c3ae66cdb36cd6`，Apple 工具基线为 `97f297743718b6d46272d244ad375b5ca903f499`。标准检查复用补充到 `7fd40a7a4777047b554a786ea4085ec1d62a0240`。本章说明工作流、产物校验、发布状态和故障恢复；具体已执行证据见 [验证基线](verification-baseline.md)。GitHub 非秘密控制项最后只读核对于 2026-11-15 16:34（Asia/Singapore）；后续执行前需要重新核对。

主要源码：[正式入口](../../.github/workflows/client-release.yml)、[组装器](../../tool/client_release/assemble_release.py)、[边缘发布器](../../tool/client_release/publish_release.mjs)、[镜像器](../../tool/client_release/github_release.py)、[公证恢复指南](../../tool/client_release/MACOS-DISTRIBUTION.md)。外部消费者位于总项目的 `client-release-edge/src/` 和 `ZolnitSuite/Modules/Client/`；源码合同与线上部署状态分别取证。

## 1. 工作流总览与职责边界

| 文件 | 触发 | 职责 | 外部消费者/副作用 |
|---|---|---|---|
| [build.yaml](../../.github/workflows/build.yaml) | `push`（任意分支/`v*` tag）、`workflow_dispatch`、`workflow_call`（来自 `client-release.yml`） | `dart`/`plugins`/`desktop`/`go`/`android`/`rust`/`windows-helper-test` 检查；正式调用时额外渲染 release notes | `client-release.yml` 的 `ci` job 复用；非正式调用不渲染/上传 release notes |
| [cloud-build.yml](../../.github/workflows/cloud-build.yml) | 指定分支 `push`（忽略 Markdown/docs）、`workflow_dispatch`、`workflow_call`（来自 `client-release.yml`） | `select` 计算平台矩阵和产品开关；平台 jobs 编译、打包并记录来源 | 候选没有正式发行资格；正式调用可签 Android，iOS 输出 unsigned 编译证据；macOS 正式签名在独立后续 job |
| [client-release.yml](../../.github/workflows/client-release.yml) | 正式版本 tag `push`（`v[0-9]+.[0-9]+.[0-9]+`） | `preflight → ci/builds → macos-sign(条件) → publish`，是唯一正式发布入口 | `publish` 写发行边缘（`publish_release.mjs` → Cloudflare Worker `client-release-edge`）与 GitHub Releases（`github_release.py`） |
| [macos-notarization-pipeline.yml](../../.github/workflows/macos-notarization-pipeline.yml) | `workflow_call`（来自 `client-release.yml` 的 `macos-sign`，或 `macos-notarization-verify.yml`） | app 签名公证提交/等待、dmg 提交/等待、finalize | `macos-distribution` environment；checkpoint artifact 传递（`notary-app.zip`、`notary-dmg.dmg`、`pending-receipt.json`），保留 7 天 |
| [macos-notarization-verify.yml](../../.github/workflows/macos-notarization-verify.yml) | 限定 `codex/native-client-shared` 分支的 `workflow_dispatch`，需 `vars.MACOS_NOTARIZATION_VERIFY_ENABLED == 'true'` | 对过去某次正式 run 的产物做独立复核签名，不发布 | `macos-distribution` environment；默认参数 run `42474933687`/tag `v1.1.4`，产物保留 7 天 |
| Apple `apple-device-signer.yml`（pin `97f29774`） | 仅 push 到 `codex/apple-distribution-prep` 且路径为该文件本身时**注册**，真正执行要 `workflow_dispatch` + `vars.APPLE_DEVICE_SIGNING_ENABLED=='true'` + `github.ref=='refs/heads/codex/apple-distribution-prep'` | `operation=archive` 发布一份稳定 unsigned 归档；`operation=sign` 处理**至多一个**排队设备签名任务 | OIDC（`id-token: write`），`apple-distribution` environment；工具 SHA 校验见第 9 节 |
| Apple `apple-distribution.yml`（pin `97f29774`） | 同上注册条件；手动触发需显式输入 `enable` 字面值 `enable`，否则第一步直接报错退出 | 手动 iOS archive/export 通道，可选 TestFlight 上传（`upload_testflight`） | `apple-distribution` environment；默认是禁用状态，防误触发签名 |
| [pages.yaml](../../.github/workflows/pages.yaml) | `main` 路径 push、`build` 完成的 `workflow_run`、手动 | 发布文档/站点到 Pages | 限定上游仓库；监听名为 `build` 的 workflow——改名前必须确认下游，否则会静默失效 |

**不能仅凭 skipped 判断 job 无用。** `dart/plugins/go/android/rust/windows-helper-test` 使用手动触发、公开仓库或 `official_release` 条件；`desktop` 的条件单独定义为手动触发或公开仓库，且排除 `push` 的 `v*` tag。正式发行使用自己的 release 构建矩阵。某次 run 的通过范围必须逐 job 核对，不能把条件跳过算成实际执行。

**分支保护观察：**经典 main protection API 返回 `404 Branch not protected`，仓库 rulesets API 另行返回空列表。两条证据共同说明观察时没有这两类保护配置；单个 404 不足以证明 rulesets 为空。本轮没有修改保护规则。

## 2. build.yaml：标准 CI 的测试入口

关键步骤（`dart` job，build.yaml:36-95）：

```sh
# 等价于 CI 实际跑的命令，可在本地复现（风险：低）
python3 -m unittest discover -s tool/client_release/tests -p '*_test.py'
python3 -m unittest discover -s tool/ci/tests -p '*_test.py'
node --test tool/client_release/tests/*_test.mjs
```

这是 `A1-RESULT.md` 所说"候选标准 CI 新增选择器及履历测试在内的 32 项 Node 测试执行、零失败"的真实来源之一——Node 测试来自 `tool/client_release/tests/*_test.mjs`，Python 测试来自 `tool/ci/tests` 和 `tool/client_release/tests`。**诊断失败时先本地跑这三条命令**，不要直接怀疑 runner 环境。

其余关键步骤：

- `dart format --output=none --set-exit-if-changed`、`flutter analyze --no-fatal-infos`：格式/静态检查失败会直接中止 job。
- `Verify changelog`（仅 `main` 或 `refs/tags/*`）：`dart run tool/changelog.dart verify`——这是 `A1-RESULT.md` 里"main 日志确认 changelog 一致"的检查点；分支 push 不触发，看不到不代表坏了。
- `inputs.official_release` 为真时才渲染并上传 `client-release-notes-<run_number>`（保留 14 天），由 `client-release.yml` 消费。
- `Check coverage`：`dart run tool/check_coverage.dart coverage/lcov.info 75`，低于 75% 直接失败。

## 3. 桌面 debug 与 release 构建的重叠

`build.yaml` 自身有 `desktop` 编译 job，不能只把它归类为单元测试。精简前要比较构建配置、平台、触发、附带验收和产物消费者。

### 3.1 三条并行链路的真实对比

| 链路 | 触发（分支 push） | 构建模式 | 产物去向 | 典型耗时来源 |
|---|---|---|---|---|
| `build.yaml` → `desktop`（matrix: linux/windows/macos） | 任意分支 push（非 tag） | `flutter build <platform> --debug`（debug 模式），**构建后直接丢弃 bundle**，不上传 artifact | 无产物；纯粹是"桌面 runner + native 插件代码能否编译通过"的编译健康检查 | Flutter/Go/Rust toolchain 安装 + debug 编译 |
| `cloud-build.yml` → `project`（matrix 含 macos/windows/linux/android/ios，由 `select` 决定） | `main`、`codex/patched-integration`、`codex/ios-support`、`codex/upstream-0.9.1`、`codex/zolnit-client`、`codex/native-client-shared` push | release 模式编译，打包成 artifact（含 `source-provenance.txt`、`SHA256SUMS`），**不签名** | 上传 14 天保留 artifact，供 `client-release.yml`/手动验收消费 | release 编译 + 打包 + provenance 生成 |
| `build.yaml` → `dart`/`plugins`/`go`/`android`/`rust`/`windows-helper-test` | 同 `desktop` 的触发条件 | 测试/静态检查/覆盖率，不编译完整桌面 bundle | 无产物（除 `official_release` 时的 release notes） | 单测/lint/go vet 等 |

### 3.2 真实重复范围：仅限 macOS/Windows/Linux 平台的"是否能编译"

`build.yaml:desktop` 和 `cloud-build.yml:project` 在**同一次 push 到 `main` 等受监控分支时确实会在同三个桌面平台上都触发一次 Flutter 编译**（分别是 debug 和 release 构建配置）。这是 AUDIT-01 样本里 `43606354922`（普通 build）与 `43606354779`（cloud build）并行的真实来源之一。

**不是无意义的重复，原因有三**：

1. **编译配置不同**：debug 与 release 使用不同编译配置。这里只执行编译，不能声称已经运行 debug 断言或验证了 release 运行行为。
2. **产物归宿不同**：`desktop` 不上传 Flutter bundle；`cloud-build.yml` 上传带 provenance 和 SHA256SUMS 的包。`desktop` 的 Windows 特定分支另有 Helper 证据/工具包上传，不能误写成整个 job 无任何 artifact。
3. **触发范围不同**：`desktop` 在**几乎所有分支**的非 tag push 上跑（除 fork 私有副本的普通 push）；`cloud-build.yml` 只在**白名单 6 个分支**上跑。多数开发分支只会触发 `desktop` 的 debug 编译检查，不会触发 `cloud-build.yml`；只有在白名单分支上两者才会同时出现。

### 3.3 精简前仍需证明的事项

即便加入了 `desktop` 的分析，AUDIT-01 的核心结论不变：**没有证据支持可以安全删除任一 job 或 workflow**。要精简，必须先核对：

1. `desktop` job 产物虽然被丢弃，但 **Windows 分支上**仍嵌入了只在 `codex/native-client-shared` 触发的隔离 Helper 验收（`windows_helper_architecture_test.ps1`、`windows_helper.ps1`，build.yaml:216-276），这部分不是纯编译检查，删除 `desktop` job 会连带删除这段验收逻辑，必须先确认它和 `cloud-build.yml` 的 Windows 编译路径没有职责重叠。
2. 两条链路各自的 required-check 消费者（第 1 节已确认当前无分支保护规则，但不排除其他仓库级 CI 状态检查依赖项）。
3. 实际耗时和 Actions 分钟消耗——本次仍未执行计费核算，需要另外的只读 API 调查（`gh api repos/.../actions/runs/<id>/timing`），这是明确的下一步，而不是臆测的结论。
4. `pages.yaml` 对名为 `build` 的 workflow 的 `workflow_run` 监听（见第 1 节）——改名或拆分 `build.yaml` 前必须确认。

### 3.4 后续候选及验收条件（未实施）

可调查在同一次 push 已取得同源 release 编译结果的平台上是否仍需重复 debug 编译。实施前必须证明配置门禁等价，迁移或保留 Windows Helper 验收，并覆盖路径过滤、手动调用和失败矩阵。`codex/ios-support` 的 Cloud push 只选 iOS，Markdown/docs push 也可能不触发 Cloud，因此不能按分支白名单直接关闭 desktop。当前没有足够证据证明安全等价，维持现有检查。

### 3.5 正式 tag 的标准检查复用

已有 v1.1.9 的两个同源运行实际各跑过 Dart、Plugins、Go core、Android unit tests、Rust、Windows helper test：独立 build `43608456797` 与正式 client-release `43608456827`。这是六类相同标准检查的重复，与前述 debug/release 桌面编译差异分开。

[standard_ci_reuse.py](../../tool/ci/standard_ci_reuse.py) 仅在精确 Zolmid 仓库/ID、正式 tag 的独立 push 身份下观察正式运行。它核对 workflow ID/path、repo/head repo、SHA/tag、明确 run/attempt、preflight 与六类 job 的身份/实际完成状态、同 SHA reusable-workflow 引用，再次回读 run 防止重跑期间混用 attempt。只有完整证据才复用：成功维持成功；真实检查失败则观察 job 退出1，不能变绿。

预检失败、正式run被取消/替代、缺job、skip、API不可读、页截断、重复job、身份/attempt漂移或等候超时都恢复原检查。观察上限900秒，每30秒轮询一次，单GET最多10秒，job上限20分钟。整个独立workflow被用户取消时仍停止，不把“回退”写成能突破取消。未知错误不得因缺输出认作已委派。

观察 job只用 `contents: read/actions: read`，正式caller补足 `actions: read`；没有改变正式入口、preflight依赖、publisher、签名、notes、artifact或发布并发。非正式tag/分支/manual/call/fork保持原条件。workflow总体颜色与六类job是否执行分开查看，step summary明确引用复用的run/attempt/job ID，local skipped不算重新执行。

事件及故障测试在 [standard_ci_delegation_test.py](../../tool/ci/tests/standard_ci_delegation_test.py)。同源历史run的实际GET回放通过，但它使用合成caller上下文，不能当成新gate已在正式tag上托管执行，更不能据此报告实际节省的分钟数。workflow被重新创建导致固定ID变化时，应重新核实身份后维护pin；未知ID会安全回退原检查。

## 4. cloud-build.yml：select 矩阵与信任边界

`select` job 用 GitHub 表达式生成下列输入，再由 [selectCloudBuild](../../tool/ci/cloud_build_selector.mjs) 纯函数生成 `matrix/enabled/platform/ios_source/android_release/official/client_branch/native_ui` 输出。CLI 只负责写入 `GITHUB_OUTPUT`，导入模块不会写文件或发网络请求：

- `PLATFORM`：push 到 `codex/ios-support` 强制 `ios`，其余 push 或未显式传入时默认 `all`；手动触发使用 `inputs.platform`。
- `IOS_SOURCE`：push 固定 `project`；手动触发可选 `project`/`patched-reference`。
- `CLIENT_BRANCH`：仅 `codex/zolnit-client` 或 `codex/native-client-shared` 为真；`NATIVE_BRANCH` 仅后者为真。正式调用和 `zolnit` 候选在纯函数中进一步计算产品输出开关。
- `ANDROID_RELEASE`：**三重门槛**——手动触发 `workflow_dispatch`、`inputs.android_release` 为真、分支是 `codex/zolnit-client` 或 `codex/native-client-shared`，缺一不可。
- `OFFICIAL_TRUSTED`：push 事件、仓库 `Zolmid/FlClash`、`repository_id` 精确等于 `1420254999`、`ref_type == 'tag'`、tag 前缀 `v`，且 `github.workflow_ref` 精确等于 `Zolmid/FlClash/.github/workflows/client-release.yml@<当前 ref>`。**候选永远不能成为正式**，因为候选分支不是 tag，`workflow_ref` 也不会指向 `client-release.yml`。
- `BUILD_PROFILE`：仅手动触发读取 `inputs.build_profile`（默认 `auto`，可选 `zolnit`）；push 场景空输入由 selector 解析为 `auto`（`A1-main-specific-observations.json` 证实）。

诊断命令为 `node --test tool/client_release/tests/cloud_build_selector_test.mjs`。该套件已经实施并运行：133 个旧输入差分、192 个 profile 场景（48 接受、88 Android 拒绝、56 profile 拒绝），以及 CLI、导入无副作用、标准 CI 接线和履历字段检查。不要直接运行没有 `GITHUB_OUTPUT` 的 CLI 来判断函数正确性。新增组合先补相应输入和拒绝场景，再核对实际 GitHub 表达式求值。

## 5. client-release.yml → assemble_release.py：正式发布契约的源码级细节

### 5.1 身份锁与版本一致性（Context/read_pubspec）

`assemble_release.py` 的 `Context.__init__`（代码第 78-91 行）在构造时就强制检查：`GITHUB_REPOSITORY=='Zolmid/FlClash'`、`GITHUB_REPOSITORY_ID=='1420254999'`、`GITHUB_EVENT_NAME=='push'`、`GITHUB_REF_TYPE=='tag'` 且 ref 名匹配语义化版本正则、`GITHUB_REF=='refs/tags/<tag>'`、`GITHUB_WORKFLOW_REF=='Zolmid/FlClash/.github/workflows/client-release.yml@refs/tags/<tag>'`——任一条件不满足直接抛 `ReleaseError`，不降级继续。

`read_pubspec`（代码第 94-102 行）要求 `pubspec.yaml` 的 `version:` 恰好一条，格式 `X.Y.Z+BUILD`，且 `v{version} == tag`、`build <= 2147483647`（Android `versionCode` 上限）。版本号不一致时**preflight 阶段就失败**，不会进入构建。

### 5.2 check_record/check_provenance：artifact 身份与构建来源绑定

`check_record`（代码第 253-261 行）核对每个候选 artifact 记录：`expired is False`、`workflow_run.id == context.run_id`、`workflow_run.head_sha == context.sha`、`repository_id`/`head_repository_id` 都等于 `1420254999`（**拒绝 fork 构建的产物**）、`digest` 匹配 `sha256:[0-9a-f]{64}` 格式。

`check_provenance`（代码第 221-234 行）解析每个 artifact 内 `source-provenance.txt`，核对字段：`source_repository`/`source_commit`/`native_ui='true'`/`client_bundle='true'`/`official_release='true'`/`run`；非 iOS 平台额外要求 `target='<platform>-<arch>'`、`client_safe_preview='false'`、`distribution_channel='direct'`、`client_build_env='stable'`、`client_defines='APP_ENV=stable;ZOLNIT_DISTRIBUTION=direct'`；iOS 平台额外要求 `source_kind='project'`，且**显式拒绝**出现 `app_bundle_id`/`observer_bundle_id`/`app_group`/`distribution_channel` 字段（"observer 或 debug 构建不是正式产物"）。所有平台还要求 `core/Clash.Meta` submodule 的记录恰好一条、SHA 等于固定值 `8380d0e7462f061a964323e9bf3129a236fcc5d5`，且没有任何子模块处于修改状态（`item[0] in ' -'`）。

### 5.3 assemble：组装流程与不变量

```
preflight (tag 身份锁 + MACOS_SIGNING_REQUIRED 读取)
  → ci: uses build.yaml with official_release=true
  → builds: uses cloud-build.yml with official_release=true
  → macos-sign (仅 macos_signing_required=='true' 时，matrix: arm64/x64)
  → publish (需要 preflight/ci/builds 全部 success)
```

`assemble()`（代码第 300-395 行）执行顺序：

1. 先要求 `ZOLNIT_CI_RESULT=='success'` 且 `ZOLNIT_BUILDS_RESULT=='success'`；`MACOS_SIGNING_REQUIRED` 只能是空/`'false'`/`'true'`。若为 `true`，额外要求 `ZOLNIT_MACOS_SIGNING_RESULT=='success'` 且 `MACOS_TEAM_ID` 匹配 `[A-Z0-9]{10}`。
2. 用 `github.tag_commit(tag)` **重新核对**该 tag 当前仍指向 `context.sha`（防止组装期间 tag 被移动）。
3. 为每个 `TARGETS`（android-arm64、linux-x64、macos-arm64/x64、windows-x64、ios-arm64-unsigned）精确定位同名 artifact，`records` 字典里**不允许同名 artifact 出现两次**（代码第 316 行），然后要求目标并集全部存在，缺一就报"missing release evidence"。
4. 对每个 artifact：下载 → `verify_sums`（校验包内 `SHA256SUMS` 与解压后文件逐一比对 digest，且 `SHA256SUMS` 覆盖的文件集合必须与实际解压文件集合**完全相等**，多一个少一个都报错）→ `check_provenance`。
5. Android 额外跑 `check_android_signing`：要求签名报告第一行是 "Verifies"、恰好一个签名者、证书 SHA-256 等于固定值 `35a6ce68c05fd989aa65367a1cefb2e22fb02797b3c6cb1e67ce3d90a2bb6739`、存在 v2/v3 签名方案验证通过的记录；若提供了 `--apksigner` 路径还会用它二次验证。
6. iOS 额外跑 `check_ios`：包名必须精确等于 `ZolNit-<version>-ios-arm64-unsigned.ipa`，**拒绝**出现 `acceptance-pair.json`（那是 routing observer 验收构建，不是正式产物），IPA 内必须有 `Payload/*.app/Info.plist`，**拒绝**嵌带 `embedded.mobileprovision`。
7. macOS 在需要签名时，改用已签名 artifact（`macos-distribution-<arch>-<run_number>`）替换原始包，校验其成员**精确等于**（dmg文件名、`signing-receipt.json`、`SHA256SUMS`），并核对 `signing-receipt.json` 里的 `schema_version`/`source_commit`/`run_id`/`arch`/`input_archive`/`input_sha256`/`dmg`/`dmg_sha256`/`team_id`/`verification=='developer-id-notarized-stapled'` 全部匹配，`identity_sha1` 匹配 40 位十六进制，且 `app_notary_id`/`dmg_notary_id` 均非空。
8. `release-notes` artifact 用 `public_notes()` 校验：要求渲染器的 begin/end 标记各一次、规定的换行与闭合注释、长度不超过 32 KiB，并且提取出的公开正文非空。具体标记以 `NOTES_BEGIN/NOTES_END` 常量为准；不是任意手写文本。
9. 最终写出 `manifest.json`（schema 1，`app_id='com.zolmid.zolnit'`，`updates_enabled=true`，单个 `releases` 条目含 `tag`/`notes`/`assets`）和 `receipt.json`（含 `checks.all_platform_builds`/`standard_ci`/`package_hashes`/`android_production_certificate`/`ios_unsigned_compile`/`macos_notarized` 布尔门禁）。

### 5.4 失败/恢复语义

- 校验失败和受处理的文件/网络错误使主函数返回 1。组装包和最终写文件的中间状态仍可能残留；退出非零的 stage 不能作为成功回执使用。
- `assemble` 创建全新的 stage（`mkdir` 不带 `exist_ok`）。重跑应使用新的自有目录，重新下载并校验；不要对已有 stage 直接再跑，也不要为此删除未知归属目录。精确签名字节的恢复依赖已存 artifact/checkpoint，组装器不是签名断点续传器。

## 6. publish_release.mjs → contracts.mjs：发行边缘（Cloudflare Worker）的真实握手

### 6.1 checkEvidence：第二道身份锁

`publish_release.mjs` 的 `checkEvidence()` 再次校验正式 tag、事件、仓库 ID、workflow ref 和源码 SHA，核对 receipt 的 schema/Core/build 及三个必需 checks。每项 receipt asset 以名称匹配 manifest 的 size/sha256，并要求 `ci_run_id` 等于当前 run、`artifact_id` 是整数；manifest 本身不含后两个字段。随后 `verifyPackages()` 重新检查实际文件类型、大小和摘要。外部服务也必须独立验证，不能只信任 CI 的布尔值。

### 6.2 edgeClient：OIDC 换取与重试策略

`edgeClient()`（代码第 60-90 行）要求 `ACTIONS_ID_TOKEN_REQUEST_URL`/`ACTIONS_ID_TOKEN_REQUEST_TOKEN` 存在（即 workflow 必须声明 `permissions: id-token: write`，`client-release.yml` 的 `publish` job 确实有这一行）。每次调用都**重新换取一次 OIDC token**（audience 为 `zolnit-client-release-edge`），不复用旧 token。失败重试策略：默认 5 次尝试，指数退避（上限 30 秒）；`4xx`（非 429）**立即**抛错不重试；`429`/`5xx`/网络异常才计入重试；超过次数仍失败则抛 `PendingError`（"仍不可用，重跑会恢复同一 session"——这是 publish 流程"可安全重跑"的关键注释）。

### 6.3 publish()：open session → upload → complete → origin-notified 四段

1. **open session**：`POST /__release/v1/sessions`，body 含 receipt/manifest/notes；只接受 200。响应 `id` 必须匹配 `^[A-Za-z0-9-]{1,128}$`，`state` 必须是 `uploading`/`published`/`notified` 之一。
2. **upload**（仅当 `state=='uploading'`）：按分片大小 8 MiB（`MAX_PART_BYTES`，见 `contracts.mjs`）切片 `PUT` 到每个资产的 parts 端点，每片带内容 SHA-256 头和是否最终分片标记；若文件在上传过程中变小会直接报错（"shrank during upload"）。
3. **complete**：`POST {session}/complete`，只接受 200；若返回的 tag 与当前不符报错；若 `state=='staged'` 直接返回 `{state:'staged', downloads_enabled:false, notice_pending:false}`（这是"下载未启用"的**合法**部分成功状态，不是失败）。
4. **origin-notified**：`POST {session}/origin-notified`，接受 200 或 202。200 且 `state=='notified'` → 完全成功（`downloads_enabled:true, notice_pending:false`）。202 且 `state=='published'` 且 `notice_pending:true` → **部分成功**：边缘已发布、下载已启用，但源站通知仍待处理，脚本把这个状态原样返回而不是报错，这正是"edge 成功但 mirror/通知可能滞后"的真实实现。

### 6.4 已知消费者：client-release-edge（Cloudflare Worker）与 ZolnitSuite/Modules/Client

- `workspaces/xboard-ops/work/client-release-edge/src/worker.mjs` 里的 `ReleaseCoordinator`（Durable Object）实现了上面四段握手的**服务端**；其 `receipt()` 校验函数（worker.mjs 第 9-11 行）与 `assemble_release.py`/`publish_release.mjs` 的字段要求逐字段对应（`schema_version`/`repository_id=='1420254999'`/`source_sha`/`tag`/`build`/`core_sha=='8380d0e7...'`/`checks.all_platform_builds`/`checks.standard_ci`/`checks.package_hashes`），这是读源码交叉确认的真实契约一致性证据，不是推测。
- `ZolnitSuite/Modules/Client/Controllers/ReleasePublicationController.php`、`Services/ReleaseAuthorization.php`、`Services/GithubReleaseIdentity.php` 是源站接收发布通知、校验来源及记录发布的消费端。维护时沿 controller → authorization → identity 核对契约；本章没有提供真实鉴权凭据，也不以本地源码推断线上已部署相同版本。

## 7. github_release.py：GitHub Releases 镜像的真实状态机

`mirror()`（代码第 91-145 行）的关键语义：

- **先决条件**：`publish-result.json` 里的 tag/source_sha 必须与当前 `GITHUB_REF_NAME`/`GITHUB_SHA` 一致；若 `downloads_enabled` 不是真，只允许 `state=='staged'`，此时**直接跳过**镜像并返回 `{github_release:'skipped', reason:'downloads disabled; assets stay private on the edge'}`——这是"edge 成功但未公开，GitHub 侧不动"的合法路径，和 6.3 节的 staged 状态对应。
- **is_live()**（代码第 71-78 行）判定当前发行是否是 R2 实时 serving 的版本：必须 `live.updates_enabled` 为真、`live.releases` 恰好一条，且 tag/assets 字节级相等。只有这样才会把 GitHub Release 标记为 `make_latest`。
- **草稿不可变语义**：若已存在同 tag 的 GitHub Release 且仍是草稿，只更新与期望值不同的字段（name/body）；不存在则创建一个 draft/非预发布/`make_latest='false'` 的新草稿。**已发布（非草稿）的 release 缺资产是硬错误**——已发布版本不允许"补发"缺失资产，只有草稿状态才允许继续上传。
- **matches()**（代码第 85-90 行）：优先用 GitHub 返回的 digest 字段比较，没有 digest 时才下载资产重新计算 SHA-256——避免每次 mirror 都重新下载全部资产。
- **发布收尾**：draft 为真时才允许把 draft 置为假（同时按 is_live() 结果设置 make_latest）；若已经不是草稿但本次判定为 latest，只更新 make_latest，不改其他字段。

### 风险分级：本文档中可执行的诊断命令

| 命令 | 风险 | 说明 |
|---|---|---|
| `python3 -m unittest discover -s tool/client_release/tests -p '*_test.py'` | 低，可本地执行 | 纯本地测试 |
| `node --test tool/client_release/tests/*_test.mjs` | 低，可本地执行 | 同上 |
| `dart run tool/changelog.dart verify` | 低，可本地执行 | 只读校验 changelog 格式 |
| `gh api repos/Zolmid/FlClash/actions/runs/<RUN_ID>/artifacts`、`gh run view <RUN_ID> -R Zolmid/FlClash --json jobs,status,conclusion` | 低，只读 GitHub API | 诊断某次正式/候选 run 的 artifact 清单和 job 状态；参数名已核对 gh 实际帮助输出 |
| `gh workflow run cloud-build.yml -R Zolmid/FlClash --ref <BRANCH> -f platform=all -f ios_source=project -f android_release=false -f build_profile=zolnit` | **中，需要显式授权** | 会触发真实 Actions 运行；参数名/取值已对照 `cloud-build.yml` 的 `workflow_dispatch.inputs` 定义核实，不是臆造 |
| `python3 tool/client_release/assemble_release.py preflight` | CI 内预检 | 读取真实 tag/pubspec/changelog；设置 `GITHUB_OUTPUT` 时会追加版本/build 输出。不要伪造正式事件在本地解锁发布；离线反例使用现有测试的模拟环境 |
| 任何 `git push` 到 `main`/tag、`publish_release.mjs`/`github_release.py`/`macos_notarize.py submit` 的真实调用、`gh workflow run apple-device-signer.yml`/`apple-distribution.yml` | **高，禁止在文档维护范围内执行** | 会产生不可逆的正式发布、签名或 TestFlight 上传副作用；必须有独立批准包 |

## 8. macos-notarization-pipeline.yml：签名/公证/dmg 检查点（源码级确认）

### 8.1 两段提交-等待与检查点内容

`MACOS-DISTRIBUTION.md` 描述的流程在源码中对应：`macos_notarize.py:submit()`（代码第 294 行起）负责提交并写检查点，`macos_pending.py:Checkpoint`（代码第 63 行起）负责持久化/序列化检查点，`macos_notary_wait.mjs:submissionFromCheckpoint()`（代码第 8-29 行）负责从检查点恢复等待所需的 submission ID。

- 检查点文件**精确限定**为 `pending-receipt.json` + `notary-app.zip`（app 阶段）或额外加 `notary-dmg.dmg`（dmg 阶段）——`macos_notary_wait.mjs` 第 17-19 行校验目录下文件数量和名称**精确匹配**期望集合，多一个少一个都报"Unexpected checkpoint files"。
- 每个 payload 文件都要重新计算 SHA-256 并与检查点记录的摘要比对（第 20-24 行），防止检查点被替换成不同字节的同名文件。
- `receipt.binding` 必须匹配 `team_id`/`source_repository=='Zolmid/FlClash'`/`stage`（第 14-16 行）——这是"工具与应用来源分离"的检查点级体现：检查点本身绑定了团队和仓库身份，不能跨团队/跨仓库复用。
- 提交 ID 必须匹配 UUID 格式（第 27-28 行）；DMG 阶段在 `stage=='app'` 但检查点已经是 dmg 阶段时，会取 `receipt.app_notary_id` 而不是 `submission_id`——这是"app 和 dmg 是两次独立的 Apple 提交，各有自己的 submission ID"的源码证据。

### 8.2 幂等与恢复边界（macos_pending.py）

- `previous_dmg_stage_ran()`（代码第 184 行起）通过只读检查历史 job 来判断"DMG 签名步骤是否真的跑过"，这是"没有检查点时，必须靠只读 job 历史证明从未执行过，否则停止并要求人工核对"的源码依据（对应 `MACOS-DISTRIBUTION.md` "否则，重试停止以待协调"）。
- `select_checkpoint()`（代码第 222 行起）按显式提供的 `resume_<arch>_artifact_id` 或自动从最新失败 job 的检查点中选择；**不接受任意提交 ID**。

### 8.3 Apple App Store Connect API Token（macos_notary_wait.mjs:token()）

`token()`（代码第 33 行起）要求 `APPLE_ASC_API_KEY_ID` 匹配至少 10 位大写字母数字、`APPLE_ASC_ISSUER_ID` 是 UUID；私钥必须是 EC prime256v1 曲线——不满足直接抛"Invalid API configuration"，不会用错误格式的密钥静默重试。

### 诊断/恢复示例（风险：中——仅读取 GitHub API 和已有 artifact，不提交新签名请求）

```sh
gh run view <RUN_ID> -R Zolmid/FlClash --json jobs,status,conclusion
gh run download <RUN_ID> -R Zolmid/FlClash -n <checkpoint-artifact-name> -D /tmp/macos-checkpoint
```

读取后按 8.1/8.2 节的字段核对检查点是 pending 还是 terminal，不贸然重新 dispatch 或替换为不同字节的同名文件。

## 9. Apple 独立工具链与 OIDC 边界（git show 97f29774 确认）

- **apple-device-signer.yml**：注册（register）和真正执行是两个不同事件——push 本文件到 `codex/apple-distribution-prep` 只会"登记"这个 workflow 存在，job 的 if 条件明确要求 `workflow_dispatch`，所以 push 永远不会跑 job。真正执行还需要 `vars.APPLE_DEVICE_SIGNING_ENABLED=='true'` 且 `github.ref=='refs/heads/codex/apple-distribution-prep'`。第一步"Validate operation, inputs, and pinned tools revision"用 shell 严格校验：`operation=archive` 必须带合法 `vX.Y.Z` 的 `source_tag`；`operation=sign` **禁止**带 `source_tag`（签名任务的版本来自队列里已排队的任务，不是手动指定）；并要求 `vars.APPLE_DEVICE_SIGNER_TOOLS_SHA` 精确等于 `GITHUB_SHA`——这是"工具 SHA 必须和被 dispatch 的提交完全一致"的源码级门禁，防止用旧工具代码签名新内容或反之。
- **apple-distribution.yml**：手动触发的第一步是"Refuse disabled lane"，只有当 `inputs.enable` 的**字面值**精确是 `enable` 时才不触发这个拒绝步骤；其余任何值（包括默认值 `disabled`）都会直接报错退出。这是"默认禁用，需要人工在界面上手打 enable 才会继续"的真实防呆设计，而不是一个可以被意外触发的布尔开关。
- 两个工作流绑定 `environment: apple-distribution`。2026-11-15 16:34 的只读 API 观察到仅有 custom branch policy，允许 `codex/apple-distribution-prep`，没有 reviewer 或 wait timer 规则。不能把 YAML 的 environment 名称本身当成存在人工审批。
- `apple-device-signer.yml` 使用 OIDC（`id-token: write`）；具体 OIDC 信任关系（哪个外部身份提供方被允许用这个 token）**UNKNOWN**。
- 观察时仓库变量 `APPLE_DEVICE_SIGNING_ENABLED=true`；environment 变量 `APPLE_DEVICE_SIGNER_TOOLS_SHA=97f297743718b6d46272d244ad375b5ca903f499`。后者是 environment 作用域，仓库同名变量 API 返回 404 不表示 pin 缺失。读取这些非秘密配置不等于批准签名队列操作。
- 工具与 App 源码分别维护，不能通过整分支合并替代队列、dispatcher、OIDC 与 pin 的迁移。历史祖先/独有提交计数参见分支章节，不能把旧基线计数套到新 main。

## 10. 当前仍缺失的验收与已知缺口（不可写成 PASS）

- **R14 的 V3 为用户明确延期、NOT_RUN**：V0/V1、双 profile 托管构建及 iOS 开发包 V2 已完成。真机安装、系统 TUN/VPN、升级和运行行为不能标为 N/A 或 PASS，按 [设备执行单](device-validation.md) 补验。
- **R16/R17 当前结论**：A1 的五个托管流程和 12 份候选 artifact 已通过来源/摘要核验，main 已快进至 `d0af9d83`。这取代早期“远端候选 NOT_RUN”的记录；新正式发行仍 NO-GO。公开客户端仍为 v1.1.9/`bfb49ed8`，其历史 V4 与本次 main 的 V2 分开。
- **CI 精简去重**（第 3.4 节候选）：仍是 UNKNOWN/待证据的后续范围，本次给出了具体候选和不实施的理由，不等于已完成去重决策。
- **分支级 required checks**：已确认当前 main 无保护规则（第 1 节）；但这不等于"可以安全放松其他隐含的消费者期望"，`pages.yaml` 对 build workflow 名称的依赖、`workflow_run` 触发链路仍需在改动前核对。
- **Apple 运行条件**：已确认的非秘密 GitHub 配置见第 9 节；外部 dispatcher 的有效信任配置、当前队列和后续设备/签名资格仍需在实际执行窗口复核。不得用本地源码或过期观察替代实时条件。
- **client-release-edge/ZolnitSuite 的部署状态、密钥配置、实际 D1/R2 绑定**：本次只读取了源码职责和字段契约用于交叉验证，没有读取任何密钥、.env、数据库连接串或部署配置，这些运行时细节保持 UNKNOWN。

本章节是维护者在后续排查或准备发布前**必须先确认**的清单，而不是可以通过补文档直接跳过的步骤。
