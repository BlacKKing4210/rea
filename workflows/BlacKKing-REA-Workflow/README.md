# BlacKKing REA Workflow

面向已授权本地程序和游戏制品的逆向、重建与验证工作流。底层保持
[BlacKKing4210/rea](https://github.com/BlacKKing4210/rea)，不替换成上游 npm 最新版。
此目录是维护源；发行包名以 `BlacKKing-REA-Workflow` 开头，技能标识为
`blackking-rea-workflow`。不重命名已有的 `rea` MCP 服务或 `rea-agents` 包。

## 另一台 Windows 电脑怎么用

1. 下载 Release 的 `BlacKKing-REA-Workflow-1.0.0-windows-x64.zip`，完整解压到固定目录。
   先核对 Release 附带的压缩包 SHA256。路径可以带空格；安装后保持此目录不变。
2. 先运行 `Verify-BlacKKing-REA.ps1`，检查逐文件 SHA256、包内 Node 和 REA CLI。
   核心运行不需要安装 Python、npm 或游戏引擎，也不需要联网。
3. 运行 `Install-BlacKKing-REA.cmd` 查看安装计划；按输出用
   `Install-BlacKKing-REA.ps1 -Apply` 安装独立技能。
4. 如果需要本地 REA MCP，显式加 `-RegisterMcp`。先显示 REA 的配置计划；已有不同
   `rea` 注册时停止并保留原配置，不自动替换另一套安装。先关闭目标 Codex 中使用该
   配置的工作，再由用户批准明确的迁移方案。
5. 在新 Codex 会话中说：`使用 $blackking-rea-workflow 分析这个已授权程序，先核对输入和范围。`
   重新打开会话后确认技能和 MCP 实际可发现；安装文件成功不等于当前会话已经发现工具。

命令行入口为 `BlacKKing-REA.cmd --help`。包内自带官方 Node 24.22.1 Windows x64、
当前 fork 的生产依赖闭包、Windows 原生组件及其许可证。
`source/rea-source.zip` 是固定核心基线提交的可编辑源码，不包含 Git 历史或开发依赖；
新增的 BlacKKing 工作流和脚本以包顶层可编辑文件提供，对应本发行标签。
修改底层后在该 fork 构建并重新打包，不用其他来源替代当前实现。

安装 CMD 仅给该 PowerShell 子进程指定 `RemoteSigned`，不改系统/用户执行策略，
不使用 `Bypass` 或自动解除下载标记。若下载 ZIP 的标记或组织策略仍阻止脚本，
由用户检查发行来源后处理；安装器不会降低保护或自动绕过。

## 流程与验收

| 阶段 | 实际工作 | 能证明什么 |
| --- | --- | --- |
| 输入确认 | 授权范围、版本、输入 SHA256、工具身份、已有工件去重 | 分析对象和基线明确 |
| 容器与提取 | REA 格式读取、逐成员映射、原件与提取字节独立核对 | 已选成员的来源与完整性 |
| 代码恢复 | 保留反编译警告，关键方法对照字节码和独立后端 | 明确范围内的结构与规则 |
| 原始执行 | 受控执行原始方法或原版程序，隔离测试数据 | 被观察输入下的原始行为 |
| 重建 | 保留可编辑代码、配置、资源引用与变更记录 | 可维护的重建工程 |
| 运行验证 | 实际载荷 SHA256 与构建一致后操作真实 UI | 当前构建的已覆盖行为 |
| 体验包 | 清单闭包、CRC/SHA、带空格移位目录、包内运行时启动 | 当前机器上的独立分发能力 |
| 独立复核 | 审查者亲看关键输出与截图，反证结论并记录限制 | 已复核证据及残余未知 |

静态检查、重编码、原始函数执行、原版场景、重建运行、HTML 运行和分发包运行分别记录。
能编译、能打开网页、退出码为零或同后端往返一致，都不单独证明完整源码或完整内容等价。
具体做法见技能的 [验证规范](skills/blackking-rea-workflow/references/verification.md)
和 [目标分派](skills/blackking-rea-workflow/references/target-routing.md)。

## 引擎、费用与数据

核心包不附带商业后端。Ghidra/JDK、CFR、Godot/GDRE、JADX 等免费工具按目标需要提供；
缺少哪个就明确报告该阶段不可用，不宣称所有目标均已就绪，不自动安装引擎。
在本机配置副本中登记实际工具路径，例见 `config/machine-profile.example.json`。
机器配置、认证、代理、MCP 登录态和原案件资料不随工作流迁移。

只使用已授权环境和免费方案。范围内确需选择非付费方案时，记录推荐与提问时间，
15 分钟未答复可按推荐的免费可逆方案继续；这不替代工具强制确认，也不授权付费、
账号/权限变更、破坏性操作或扩大任务。网络命令每次读取当前系统代理开关与地址，
仅作用于该命令；不恢复旧代理、不切换 VPN。

此发行包不含游戏代码、图片、音频、存档、账号、历史会话或案例截图。
测试只用自制夹具。案例中的版本、数值、端口、角色和测试数量不是通用默认值。

## 维护与再打包

维护者先检查当前 fork 和对应锁文件，再用 `scripts/build-core-runtime.mjs` 复用 REA
生产打包器生成核心闭包。`scripts/build-bundle.py` 只接收显式列出的工作流文件、
已验证 Node 官方发行包、核心闭包和 `git archive` 源码；输出到仓库外。
不提交二进制、`dist/`、开发 `node_modules/` 或机器收据。

本目录遵循 REA 仓库 MIT 许可证。Node 与各依赖保留自己的许可证和声明。
技能结构参考 [OpenAI 官方技能说明](https://developers.openai.com/plugins/concepts/skills)。
