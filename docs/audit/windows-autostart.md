# Windows 高优先级自启审计

来源为 Patched `8012efc6fcf06515c11d9da1dc0ddca205fe46be`（`feat(desktop): improve shell integration`），
参考固定至 `7ea4597c9182d40cd57da9fc2f2d5cc0a5f84c2f`，共同基线
`7c61c90ac20493b474d19c75ec96262b478b4b88`。本轮主线保留起点为
`3222b8d609caaf74c28f61712c8d654e4937eed9`。

## 迁入与主线约束

- 迁入 Windows 的零延迟 LogonTrigger 自启：`autoLaunch=true` 且 `highPriorityAutoLaunch=true`
  选择 scheduled task；其他桌面平台继续使用原 `launch_at_startup`。此选项不提高管理员权限。
- `AutoLaunch.updateStatus` 接受两个命名参数，与 bootstrap 和设置同步。窗口监听选择这两个字段的 record，
  保留既有 `FunctionTag.autoLaunch` debouncer、几何/模糊/退出监听与 Helper 所有权。
- 主线 `SAFE_MODE` 下全局 `autoLaunch` 仍为 null；owner 的 safe/debug 门也在任何状态查询和注册前返回。
  不迁入参考中的 `runas` 失败回退，也不调用其 `system.dart` 通用任务 helper。

## 任务归属与权限

`windows_autostart.dart` 独立适配 `whoami.exe` 与 `schtasks.exe`，使用参数列表调用，不经过 shell。
当前用户 SID 由 `whoami /USER /FO CSV /NH` 读取；任务名由固定 FlClash 前缀、该 SID 和
当前可执行路径哈希组成。不会查询、覆盖或删除另一个安装路径/用户的任务，也不会接管历史上仅名为
`FlClash` 的无归属任务。

查询使用 XML 与 HRESULT，仅明确的 file/path-not-found 视为不存在；访问拒绝、账号信息错误或无效 XML
均报告失败。修改或删除之前检查 Source ownership marker、当前 SID、InteractiveToken、LeastPrivilege、
单一 LogonTrigger/Exec、可执行路径和无额外 Arguments。不存在的任务创建时不带 `/F`；
只有归属检查通过的已有任务才允许替换或删除。正常启动的权限和 Helper 授权流程保持不变。

临时 XML 放在每次独立创建的临时目录，字段经过 XML 转义，使用 UTF-16LE BOM 写入；
成功、注册失败或进程异常均清理临时目录。查询同时处理 UTF-16 与 UTF-8 输出，避免中文路径损坏。
任务限定当前用户 InteractiveToken/LeastPrivilege，零延迟、IgnoreNew、禁止强制终止；不会请求 elevation。

## 互斥、失败与并发

正常收敛后 Run entry 和本安装的 scheduled task 互斥。切换先建立新方式，再删除原方式；
新方式建立失败时保留原来成功的方式。旧方式删除失败时先复查旧方式仍存在，再回滚新方式；
如果旧方式实际已删除或状态无法确认，则保留新方式以避免把两个方式一起移除。
失败会写入应用日志并显示错误通知，不把保存的用户选择静默改成另一值。

所有更新经过同一个串行 controller；每次 await 后检查 revision，跳过过时清理并继续处理最新意图。
快速切换/关闭不会让较早完成的任务注册成为最终状态。无效配置或删除失败可留下明确报告的未收敛状态，
不会无期限重试或删除未经验证的注册。

## 验证与平台限制

- 独立纯 Dart 临时包运行同一 `windows_autostart.dart` 与 fake ProcessRunner 测试，19项通过。
  覆盖 XML/Unicode、SID/权限/命令归属、仅操作精确任务名、失败清理临时文件、失败保留、回滚与最新意图。
- `launch.dart`、scheduler adapter、窗口 manager 和两份相关测试的 Dart analyze 无问题，格式检查通过。
- 更新了 `test/common/launch_test.dart` 的命名参数和 safe-mode 验证；根 Flutter/manager 回归由主任务统一运行。
- Linux 未执行真实 `schtasks` 注册/注销或登录自启；仍需 Windows 普通用户验证 Task Scheduler 服务不可用、
  拒绝权限、快速切换、重启登录，以及现有 Run entry 的迁移。测试没有注册宿主任务或更改登录项。

没有修改 `system.dart`、Helper、模型/codegen、根项目依赖、CI或应用身份，也没有提交或推送。
