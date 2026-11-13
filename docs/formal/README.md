# Agent 协作状态机与有限状态验证

2026-11-11；对应 [产品设计](../agent-collaboration-design.md)。使用 TLA+ 描述状态和转移，实际运行 TLC 检查有限模型的全部可达状态。不是对尚未实现的应用代码作正确性证明，也不是无限规模的定理证明。

## 完整库存与本次基线范围

2026-11-13 基线实际包含 **7 个 TLA 模块、90 个 cfg 文件、95 个 evidence 文件**，共 195 个 formal 路径（另含本 README、single-writer-notes.md 和 SelectiveUndoSourceCheck.mjs）。模块为 Collaboration、Workflow、SingleWriter、SingleWriterLive、SelectiveUndo、PreviewAccept、LogBackup。后文最初两个模型的 1,088 个状态与 3 个反例只描述原始检查，不概括扩展模型。

在仓库根目录重跑清单和计数（需要 ripgrep）：

```sh
rg --files docs/formal -g '*.tla' | sort
rg --files docs/formal -g '*.tla' | wc -l  # 7
rg --files docs/formal -g '*.cfg' | sort
rg --files docs/formal -g '*.cfg' | wc -l  # 90
rg --files docs/formal/evidence | sort
rg --files docs/formal/evidence | wc -l   # 95
```

本 PR 只记录已接受的设计、形式模型与审计材料，不包含运行时源码、不启用功能。历史 PR 1 包含 advisory 源码和测试，保持 draft 且未合并；源码安排在后续实现 PR。模型、配置、证据和源码检查脚本从 pinned head 原样保留，仅本索引校正范围。下面各节运行数字属于注明日期的历史记录，不是本次打包重新运行的结果。

[2026-11-13 审计索引](../reviews/2026-11-13-pr1-baseline/README.md)记录默认政策及限制：约束检查轮只复验 26 个官方短配置，其余 64 个未复验；有限模型与静态检查不是实现验收或无界证明。

## 流程状态图

下面是最初 Collaboration / Workflow 两个模型的可读投影，完整转移以 `.tla` 文件为准。为便于阅读，未逐一绘出不改变状态的等待及同一阶段中的人工编辑。

```mermaid
stateDiagram-v2
    [*] --> 待评审
    待评审 --> 待评审: 每次取得许可后可外部生图
    待评审 --> 达标: 评审完成且通过
    待评审 --> 未达标: 评审完成但未通过
    未达标 --> 待评审: 少于两轮时细化
    达标 --> 已选择: 用户确认
    未达标 --> 已选择: 用户明确接受不足
    已选择 --> 编辑中: 整体应用
    编辑中 --> 导出中: 固定交付快照
    导出中 --> 导出中: 写入文件或失败等待重试
    导出中 --> 已交付: 三种文件全部写入成功
```

图纸评审将“评分达到 80 且关键特征保留”抽象为通过/未通过。模型不计算审美分数。两轮用尽且未接受时留在未达标状态等待；继续搜索属于新的用户授权批次，未建模。

```mermaid
stateDiagram-v2
    [*] --> 空闲
    空闲 --> 已计划: 记录依赖版本和旧值
    已计划 --> 冲突: 依赖或结构版本已变
    已计划 --> 已准备: 校验通过并保留提交顺序
    已准备 --> 已持久化: 状态与操作记录原子保存
    已持久化 --> 已提交: 发布页面状态并确认
    已准备 --> 已计划: 崩溃恢复且尚未持久化
    已持久化 --> 已提交: 崩溃后从持久记录恢复
    已提交 --> 已提交: 重复请求返回已有结果
    已提交 --> 已撤销: 无后续冲突则追加补偿
    已提交 --> 撤销冲突: 人工修改或结构版本变化
```

“已准备”至提交完成期间，不允许其他提交插入。实际实现可以使用串行队列或等价的事务机制，不要求锁住整个 UI；尚未提交的笔画应明确为临时预览。

## 完整模型动作表

状态图按阶段展示流程，不展开 1,088 个状态节点。下表仅列出原始 Collaboration / Workflow 正常模型和变异模型的全部动作，包括图中省略的自循环。精确变量、守卫和赋值分别见 [Collaboration.tla](Collaboration.tla) 与 [Workflow.tla](Workflow.tla)。

### 协作模型

| 动作 | 起点与条件 | 结果 |
| --- | --- | --- |
| `Plan` | `idle` | `planned`，记录版本、旧值和结构版本 |
| `Human` | `idle/planned/committed`，人工操作少于 2 次 | 当前阶段不变，修改任选豆格并持久化 |
| `StructuralChange` | `planned/committed`，结构尚未变化 | 当前阶段不变，结构版本增加 |
| `Prepare` | `planned`，依赖版本和结构版本一致 | `prepared`，开始保留提交顺序 |
| `Reject` | `planned`，版本不一致 | `conflict` |
| `Persist` | `prepared` | `persisted`，原子保存状态和操作记录 |
| `Publish` | `persisted` | `committed`，发布页面状态并确认 |
| `CrashRecover` | 任意阶段，尚未模拟崩溃 | 页面恢复持久状态；`prepared` 回到 `planned`，`persisted` 进入 `committed`，其余阶段保持 |
| `Retry` | `committed` 且操作已持久化 | 当前阶段不变，返回确认，不重复写入 |
| `Undo` | `committed`，版本和结构未冲突 | `undone`，保存补偿操作 |
| `UndoConflict` | `committed`，撤销前提不成立 | `undoConflict` |
| `EarlyAck` | 仅变异配置，`prepared` | 尚未持久化即确认，触发反例 |

`StaleCommit.cfg` 放宽 `Prepare` 的版本守卫。`ValueUndo.cfg` 将 `Undo` 的版本守卫替换为颜色值比较。两者均预期触发反例。

### 工作流模型

| 动作 | 起点与条件 | 结果 |
| --- | --- | --- |
| `Consent` | 任意阶段，当前无外发许可 | 取得单次许可，阶段不变 |
| `Generate` | `ready`，有许可且生图次数少于 2 次 | 消耗许可并累计调用次数，阶段不变 |
| `Evaluate` | `ready`，评审次数少于 2 次 | 增加次数，进入 `passed` 或 `failed` |
| `Refine` | `failed`，尚未达到 2 次 | 回到 `ready` |
| `Accept` | `passed/failed` | `selected`，记录确认；未达标时记录接受不足 |
| `Apply` | `selected` 且已确认，尚未应用 | `editing`，安装候选 |
| `Export` | `editing` | `exporting`，固定交付快照 |
| `Human` | `editing/exporting`，当前版本小于 2 | 增加当前版本，交付快照不变 |
| `WriteFile` | `exporting`，存在未写文件 | 写入任选文件，阶段不变 |
| `Report` | `exporting`，3 个文件均对应快照 | `delivered`，报告完成 |

两个 `Spec` 都允许等待，即状态不变。冲突解决、拒绝候选、主动取消和超预算继续搜索没有细化为模型动作，不能据此声称这些流程已被验证。模型将达标判断作为外部输入。

## 模型边界

| 模型 | 有限范围 | 抽象假设 |
| --- | --- | --- |
| `Collaboration.tla` | 2 个豆格、2 种值、1 次 Agent 操作、最多 2 次人工编辑、1 次结构变化、1 次崩溃恢复、1 次选择性撤销 | 操作读取/修改第 1 格，第 2 格独立；状态、历史和操作身份原子持久化；结构变化以版本失效表示 |
| `Workflow.tla` | 2 轮评审、最多 2 次外部生图、1 次候选应用、3 种文件、导出期间 1 次人工编辑 | 评审结果外部提供；单文件写入原子且成功后有回执；失败可表现为等待，没有文件系统内容损坏模型 |

人工提交和补偿撤销暂抽象成原子持久化动作，只有 Agent 原始提交拆成持久化/发布阶段。模型没有证实真实存储实现满足这些假设。

两个模型独立检查，不构成两者组合或分布式实现的证明。没有覆盖多个 Agent 操作、完整撤销重做栈、任意依赖图、部分冲突合并、身份认证、过期标签页、路径安全或网络协议。颜色与完成状态联动尚未分别建模。

## 已检查的性质

- `NoSilentOverwrite`：通过提交及选择性撤销时，第 1 格和结构版本必须仍符合前提。监测变量 `bad` 记录任何违反。
- `AcknowledgedIsDurable`：操作确认成功蕴含其持久记录存在。
- `ConsistentPublishedState`：除已持久化尚未发布的过渡阶段，页面与持久状态一致。
- `TypeOK`：协作模型的格子、版本和人工操作次数不越界。
- `BoundedSearch`：自动评审不超过两轮。
- `ConfirmedApply`：候选应用之前有用户确认。
- `PreviewIsIsolated`：候选评审和选择阶段不写当前作品。
- `ConsistentDelivery`：各交付文件对应同一个固定快照，即使导出期间人工继续编辑。
- `NoFalseCompletion`：三种文件未全部成功时不能报告完成。

生图许可在 `Generate` 动作中作为前置条件并在使用后消耗；尚未单独通过变异实验检验该规则。

## 实测结果

工具：官方 TLA+ v1.7.4 分发包，TLC 报告版本 2.19；Java 21；单 worker 广度优先搜索。

| 配置 | 不同状态 | 最大搜索深度 | 结果 |
| --- | ---: | ---: | --- |
| Collaboration | 332 | 10 | 全部列出的不变量通过，队列耗尽 |
| Workflow | 756 | 17 | 全部列出的不变量通过，队列耗尽 |
| EarlyAck | 30 | 4 | 如预期违反持久化确认性质 |
| ValueUndo | 228 | 8 | 如预期违反无静默覆盖性质 |
| StaleCommit | 21 | 4 | 如预期违反无静默覆盖性质 |

反例配置在首个错误处停止，状态数不代表其全部可达状态。

3 个反例的最短动作序列：

1. `EarlyAck`：计划 → 准备 → 提前确认。尚未持久化即报告成功。
2. `ValueUndo`：计划 → 准备 → 持久化 → 发布 → 用户改同格 → 用户改回 → 仅按颜色相等撤销。颜色虽然相同，仍覆盖了后续人工意图。
3. `StaleCommit`：计划 → 用户改第 1 格 → 使用过期计划准备提交。

这些反例来自故意削弱保护的模型，不是发现了已实现应用中的三处缺陷。

## 设计需要补充的约束

以下约束是模型通过验证的前提，已纳入设计文档。约束仍需后续代码满足：

1. 页面可以展示临时预览，但成功确认必须晚于状态、历史和操作身份的一致持久化。
2. 版本校验与持久化之间必须保留提交顺序，避免检查之后又被人工修改。
3. 选择性撤销依据变更版本而非仅当前颜色；结构变化无法安全映射时报告冲突。
4. 导出启动时固定快照；报告具体导出版本，不暗示快照包含导出期间发生的后续编辑。

没有设置公平性条件，也关闭了终止状态的死锁检查。因此这里只验证安全性，不保证用户一定确认、存储一定恢复、任务最终完成，或在指定时间内结束。有限实例检查不能推广为任意尺寸/操作数量均正确；实际代码仍需故障注入和端到端验收。

## 复现

官方工具下载：https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar

本次 JAR SHA-256：`936A262061C914694DFD669A543BE24573C45D5AA0FF20A8B96B23D01E050E88`。

工具放在仓库 `.tmp/formal-tools/tla2tools.jar`，在 `docs/formal/` 中执行：

```powershell
java -XX:+UseParallelGC -cp ../../.tmp/formal-tools/tla2tools.jar tlc2.TLC -workers 1 -metadir ../../.tmp/formal-tools/recheck-collaboration -config Collaboration.cfg Collaboration.tla
java -XX:+UseParallelGC -cp ../../.tmp/formal-tools/tla2tools.jar tlc2.TLC -workers 1 -metadir ../../.tmp/formal-tools/recheck-workflow -config Workflow.cfg Workflow.tla
```

将第一条的配置替换为 `EarlyAck.cfg`、`ValueUndo.cfg`、`StaleCommit.cfg` 可重现反例。反例运行应返回不变量违反（退出码 12），正常配置应返回 0。

去除本机路径的日志位于 [`evidence/`](evidence/)。日志保留状态计数、工具版本和反例轨迹。TLC 采用状态指纹，日志包含指纹碰撞的概率估计；不将其表述为数学上的无限状态证明。


## SingleWriter 扩展模型

2026-11-12 补充，状态为 Proposed。协议与三种中断窗口见 [浏览器单写者的持久化与恢复](../single-writer-recovery.md)，完整动作、变量、变异守卫及边界见 [模型索引](single-writer-notes.md)，实现后的验收见 [故障注入与浏览器清单](../single-writer-recovery-tests.md)。本次只修改设计文档和形式模型，不改变工作台行为。

`SingleWriter.tla` 将页面、浏览器本地待发记录、服务易失队列、服务磁盘和消息信道分开。它允许消息丢失、重复与跨重连乱序，两个标签页、旧页面唤醒，以及有限次数的页面和服务崩溃。磁盘仍假设完整记录原子持久化，不能据此声称 Node、IndexedDB 或真实文件系统已通过验收。

安全主配置检查 `AcknowledgedIsDurable`、`NoLostAckedOp`、`NoDuplicateApply`、`SingleActiveWriter`、`NoSilentOverwrite`、`ProjectIdentity`、`ConvergenceAfterRecovery`、`BrowserReplayConsistent` 和 `TypeOK`。其中收敛性质是当前获授写入权且没有待确认操作时的一致性不变量，不是任意故障下必定恢复的保证。

主配置为两个标签页、两个操作、两个世代、每标签页最多两个请求代次，页面崩溃总数及服务崩溃次数各最多两次，最多两个不同的在途消息。`SingleWriterRestartTwice` 另以一个标签页、一个操作、三个世代和三个请求代次检查两次完整页面重开周期。所有安全配置关闭死锁检查，预算耗尽或冲突阻断不能当作活性通过。

`SingleWriterLive.tla` 在稳定恢复后缀检查 `EventualReconciliation`。它的 8 种初态覆盖页面和服务各自运行或崩溃，以及操作尚未持久化或已经持久化。之后不再有新修改、接管、丢包或崩溃，各发送、接收、重开、重启、写盘及回执动作满足弱公平。它没有证明主模型在无限故障或永久冻结下最终恢复。

### 配置与实测结果

新增配置统一使用 `SingleWriter` 前缀，避免覆盖原来的 `EarlyAck.cfg`。所有配置文件均逐字保留本次研究运行时的内容，仅改文件名。工具为相同 SHA-256 的官方 TLA+ v1.7.4 JAR、TLC 2.19、Java 17.0.13，单 worker 广度优先。日期均为 Asia/Taipei。

下表记录 2026-11-11 的完整研究运行。两个指纹多项式都穷尽同一主状态空间，没有通过设置状态上限或模拟轨迹代替穷尽检查。反例在首个错误处停止，其状态数不是全部可达状态数。裁剪后的摘要与反例投影在 [evidence/](evidence/)，未提交运行缓存或本地路径。

| 配置 | 预期 | 实际 | 生成状态 | 不同状态 | 深度 | 退出码 |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| [SingleWriter](evidence/SingleWriter.txt) | 通过 | 通过 | 47,596,079 | 7,470,612 | 32 | 0 |
| [SingleWriterFP1](evidence/SingleWriterFP1.txt) | 通过 | 通过 | 47,596,079 | 7,470,612 | 32 | 0 |
| [SingleWriterRestartTwice](evidence/SingleWriterRestartTwice.txt) | 通过 | 通过 | 450,001 | 93,443 | 27 | 0 |
| [SingleWriterIdentity](evidence/SingleWriterIdentity.txt) | 通过 | 通过 | 210,673 | 41,355 | 28 | 0 |
| [SingleWriterLive](evidence/SingleWriterLive.txt) | 通过 | 通过 | 194 | 112 | 14 | 0 |
| [SingleWriterEarlyAck](evidence/SingleWriterEarlyAck.txt) | 失败 | AcknowledgedIsDurable | 609 | 227 | 9 | 12 |
| [SingleWriterNoFence](evidence/SingleWriterNoFence.txt) | 失败 | SingleActiveWriter | 10,197 | 3,283 | 9 | 12 |
| [SingleWriterNoDedupe](evidence/SingleWriterNoDedupe.txt) | 失败 | NoDuplicateApply | 1,166 | 360 | 11 | 12 |
| [SingleWriterFilename](evidence/SingleWriterFilename.txt) | 失败 | ProjectIdentity | 24 | 15 | 4 | 12 |
| [SingleWriterGrantRace](evidence/SingleWriterGrantRace.txt) | 失败 | SingleActiveWriter | 22,451 | 6,473 | 10 | 12 |
| [SingleWriterCoverBrowserTwice](evidence/SingleWriterCoverBrowserTwice.txt) | 可达见证 | 可达 | 37,585 | 10,954 | 13 | 12 |
| [SingleWriterCoverServiceTwice](evidence/SingleWriterCoverServiceTwice.txt) | 可达见证 | 可达 | 61,483 | 17,150 | 14 | 12 |
| [SingleWriterCoverBrowserAhead](evidence/SingleWriterCoverBrowserAhead.txt) | 可达见证 | 可达 | 3,471 | 1,255 | 9 | 12 |
| [SingleWriterCoverServiceAhead](evidence/SingleWriterCoverServiceAhead.txt) | 可达见证 | 可达 | 57,430 | 16,097 | 14 | 12 |

`SingleWriterFP1` 使用指纹多项式 1，其余研究配置使用多项式 0，seed 均为 1。状态指纹仍有碰撞风险，重复多项式检查也不是无限状态数学证明。

### 反例对协议的约束

- `SingleWriterEarlyAck` 在服务写盘前让页面显示成功。
- `SingleWriterNoFence` 允许已失去写入权的旧页面提交新操作。
- `SingleWriterNoDedupe` 将已知 ID 再次施加为修改，日志出现重复 ID。此变异还放宽了错误重试分支的基础版本守卫，不能据此声称只删除缓存且保留严格 baseRev 检查也必然双写。正确协议对重复 ID 返回原持久结果。
- `SingleWriterFilename` 把 Q 项目的页面绑定到 P 项目历史。
- `SingleWriterGrantRace` 先接收 A 的 epoch 1 操作，再授予 B epoch 2，最后才把 A 的旧操作写盘。仅在接收时检查 epoch 不够，世代交接与提交持久化必须共用项目队列。此变异同时放宽交接时机和写盘前检查，不是单行守卫变异。

五个负例的完整轨迹分别为 9、9、11、4、10 个状态，证据只保留决定性动作投影。`SingleWriterCover*` 故意断言恢复目标不可达，退出 12 表示找到了见证，不是正向协议失败。正向配置没有发现安全性反例。

### 从仓库布局复现

在仓库根目录准备工具，二进制和运行缓存保存在已有忽略目录 `.wip/`。需要 Java 17 或更高版本、curl，以及 sha256sum。

```sh
mkdir -p .wip/formal-tools
curl -fL https://github.com/tlaplus/tlaplus/releases/download/v1.7.4/tla2tools.jar \
  -o .wip/formal-tools/tla2tools.jar
printf '%s  %s\n' \
  936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88 \
  .wip/formal-tools/tla2tools.jar | sha256sum -c -
cd docs/formal
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 1 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-single-writer \
  -config SingleWriter.cfg SingleWriter.tla
```

较小的安全配置使用 `SingleWriterRestartTwice.cfg`，仍运行 `SingleWriter.tla`。活性配置使用 `SingleWriterLive.cfg SingleWriterLive.tla`。若重跑 `SingleWriterFP1.cfg`，将 `-fp 0` 改为 `-fp 1`。各次运行使用不同的 `-metadir` 目录。

以下命令验证负例与原模型。负例预期退出 12，脚本明确接受该状态，不把任何其他退出码当成通过。

```sh
status=0
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 1 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-single-writer-early-ack \
  -config SingleWriterEarlyAck.cfg SingleWriter.tla || status=$?
test "$status" -eq 12 || exit 1
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 1 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-original-collaboration \
  -config Collaboration.cfg Collaboration.tla
```

同一模型的其他配置可替换第一条命令的 `-config` 参数。`SingleWriterCover*` 也预期退出 12；正常安全配置及活性配置预期退出 0。原模型没有更改，已有 `EarlyAck`、`StaleCommit` 和 `ValueUndo` 仍应找到各自反例。


### 本次仓库布局复测

2026-11-12（Asia/Taipei）从本分支的 `docs/formal/` 运行上面的相对路径命令，重新检查完整 `SingleWriter.cfg`，没有改用较小配置。工具 JAR 放在忽略目录 `.wip/`，未提交。实际计数如下。

| 配置 | 预期 | 实际 | 生成状态 | 不同状态 | 深度 | 退出码 |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| SingleWriter | 通过 | 通过，队列耗尽 | 47,596,079 | 7,470,612 | 32 | 0 |
| SingleWriterEarlyAck | 失败 | AcknowledgedIsDurable | 609 | 227 | 9 | 12 |
| Collaboration | 通过 | 通过，队列耗尽 | 616 | 332 | 10 | 0 |

同次还复测了单写者的重复恢复、身份、活性、其余负例、全部覆盖见证，以及原有 Workflow、EarlyAck、StaleCommit、ValueUndo，共 18 个配置。全部符合预期，计数与前文研究运行相同。逐配置计数及模型 SHA-256 见 [仓库布局复测摘要](evidence/SingleWriter-layout-recheck.txt)。`SingleWriterFP1` 未在此次整理中重跑，上表明确保留的是 2026-11-11 的第二指纹多项式结果。

以上结果验证本次提交的模型和配置能够从仓库布局复现，不代表应用故障注入或 Playwright 验收通过。


## SelectiveUndo 扩展模型

2026-11-12（Asia/Taipei）补充，状态为 Proposed。恢复范围、操作性质、日志字段与应用验收清单见 [结构变换后的选择性撤销](../selective-undo-after-transform.md)。本次不实现应用功能，也不将不同模型的独立检查视为组合证明。

`SelectiveUndo.tla` 对 3×2 初始网格建模，含空格、两种非空颜色、completed 和逐格版本。局部 Paint、Replace、Done 的逆经过后续 rotate、flipH、flipV 或 crop 的坐标映射。色板映射会合并颜色，首版将色板 epoch 变化作为保守屏障。crop 只模拟删除右侧一列；任意矩形 crop 尚未在应用中实现，现有 resize 缩小会截掉右侧或下方区域。

主探索限最多 4 条历史操作，Paint 选集限当前首尾格及组合，Done 限首尾格，Replace 可修改更广写集。定向组合路径包含 5 条操作。模型检查 TypeOK、NoSilentOverwrite、PreserveLaterEdits、CorrectInverse、ColorDoneConsistency、ConflictReported 与 ABADetected。结构事务自身的选择性撤销、扩尺寸、部分恢复重试及 undo-of-undo 未获证明。

`CorrectInverse` 比较的是省略目标后重放后续**已提交的具体效果**，不是重新执行旧 UI 条件命令。坐标组合路径与稳定格子身份参考路径分开；无冲突时比较整张图的颜色与 completed，有冲突时只比较安全子集并保持其他当前内容不变。`SelectiveUndoWitnessReadDependency` 明确找到了 Replace 在两种重放契约下不同的结果。若产品选择原命令重执行语义，仍须补读集与语义依赖；不能把本节当作该更强契约已通过。

### 配置、预期与仓库布局实测

所有新配置均使用 `SelectiveUndo` 前缀，内容与研究运行逐字一致，仅改文件名。模型也保持字节一致。本次在本分支的 `docs/formal/` 用相对路径重跑全部 32 个新配置及原 `Collaboration.cfg`，共 33 项，均符合预期。工具为相同 SHA-256 的官方 v1.7.4 JAR、TLC 2.19、Java 17.0.13，1 worker、seed 20261112、fp 0。

下表全部为本次仓库布局运行的真实数字。负例与见证在指定不变量首次违反时停止，exit 12 是预期结果，不是正向协议失败。它们的深度不能解释为完整空间的最大深度。各配置摘要与短轨迹只保留决定性投影，不提交完整日志或缓存。

| 配置 | 预期 | 实际 | 生成状态 | 不同状态 | 深度 | exit |
|---|---|---|---:|---:|---:|---:|
| [SelectiveUndoPositive](evidence/SelectiveUndoPositive.txt) | 通过 | 通过，队列耗尽 | 266625 | 134295 | 5 | 0 |
| [SelectiveUndoPositiveABA](evidence/SelectiveUndoPositiveABA.txt) | 通过 | 通过，队列耗尽 | 6 | 5 | 5 | 0 |
| [SelectiveUndoWitnessABA](evidence/SelectiveUndoWitnessABA.txt) | 见证 NotABA | NotABA | 5 | 5 | 5 | 12 |
| [SelectiveUndoPositiveRotate](evidence/SelectiveUndoPositiveRotate.txt) | 通过 | 通过，队列耗尽 | 6 | 5 | 5 | 0 |
| [SelectiveUndoWitnessRotate](evidence/SelectiveUndoWitnessRotate.txt) | 见证 NotRotate | NotRotate | 5 | 5 | 5 | 12 |
| [SelectiveUndoPositiveFlipH](evidence/SelectiveUndoPositiveFlipH.txt) | 通过 | 通过，队列耗尽 | 6 | 5 | 5 | 0 |
| [SelectiveUndoWitnessFlipH](evidence/SelectiveUndoWitnessFlipH.txt) | 见证 NotFlip | NotFlip | 5 | 5 | 5 | 12 |
| [SelectiveUndoPositiveFlipV](evidence/SelectiveUndoPositiveFlipV.txt) | 通过 | 通过，队列耗尽 | 6 | 5 | 5 | 0 |
| [SelectiveUndoWitnessFlipV](evidence/SelectiveUndoWitnessFlipV.txt) | 见证 NotFlip | NotFlip | 5 | 5 | 5 | 12 |
| [SelectiveUndoPositiveChain](evidence/SelectiveUndoPositiveChain.txt) | 通过 | 通过，队列耗尽 | 7 | 6 | 6 | 0 |
| [SelectiveUndoWitnessChain](evidence/SelectiveUndoWitnessChain.txt) | 见证 NotPartial | NotPartial | 6 | 6 | 6 | 12 |
| [SelectiveUndoPositiveReadDependency](evidence/SelectiveUndoPositiveReadDependency.txt) | 通过 | 通过，队列耗尽 | 5 | 4 | 4 | 0 |
| [SelectiveUndoWitnessReadDependency](evidence/SelectiveUndoWitnessReadDependency.txt) | 见证 NotRawReplayGap | NotRawReplayGap | 4 | 4 | 4 | 12 |
| [SelectiveUndoPositivePartial](evidence/SelectiveUndoPositivePartial.txt) | 通过 | 通过，队列耗尽 | 5 | 4 | 4 | 0 |
| [SelectiveUndoWitnessPartial](evidence/SelectiveUndoWitnessPartial.txt) | 见证 NotPartial | NotPartial | 4 | 4 | 4 | 12 |
| [SelectiveUndoPositiveCrop](evidence/SelectiveUndoPositiveCrop.txt) | 通过 | 通过，队列耗尽 | 5 | 4 | 4 | 0 |
| [SelectiveUndoWitnessCrop](evidence/SelectiveUndoWitnessCrop.txt) | 见证 NotPartial | NotPartial | 4 | 4 | 4 | 12 |
| [SelectiveUndoPositivePalette](evidence/SelectiveUndoPositivePalette.txt) | 通过 | 通过，队列耗尽 | 5 | 4 | 4 | 0 |
| [SelectiveUndoWitnessPalette](evidence/SelectiveUndoWitnessPalette.txt) | 见证 NotConflict | NotConflict | 4 | 4 | 4 | 12 |
| [SelectiveUndoPositivePaletteInverse](evidence/SelectiveUndoPositivePaletteInverse.txt) | 通过 | 通过，队列耗尽 | 4 | 3 | 3 | 0 |
| [SelectiveUndoWitnessPaletteInverse](evidence/SelectiveUndoWitnessPaletteInverse.txt) | 见证 NotConflict | NotConflict | 3 | 3 | 3 | 12 |
| [SelectiveUndoPositiveDone](evidence/SelectiveUndoPositiveDone.txt) | 通过 | 通过，队列耗尽 | 4 | 3 | 3 | 0 |
| [SelectiveUndoWitnessDone](evidence/SelectiveUndoWitnessDone.txt) | 见证 NotRestore | NotRestore | 3 | 3 | 3 | 12 |
| [SelectiveUndoPositiveProject](evidence/SelectiveUndoPositiveProject.txt) | 通过 | 通过，队列耗尽 | 5 | 4 | 4 | 0 |
| [SelectiveUndoWitnessProject](evidence/SelectiveUndoWitnessProject.txt) | 见证 NotConflict | NotConflict | 4 | 4 | 4 | 12 |
| [SelectiveUndoPositiveRepeat](evidence/SelectiveUndoPositiveRepeat.txt) | 通过 | 通过，队列耗尽 | 6 | 5 | 5 | 0 |
| [SelectiveUndoWitnessRepeat](evidence/SelectiveUndoWitnessRepeat.txt) | 见证 NotRepeat | NotRepeat | 5 | 5 | 5 | 12 |
| [SelectiveUndoNegativeValueABA](evidence/SelectiveUndoNegativeValueABA.txt) | 反例 NoSilentOverwrite | NoSilentOverwrite | 5 | 5 | 5 | 12 |
| [SelectiveUndoNegativeNoCoordinateMap](evidence/SelectiveUndoNegativeNoCoordinateMap.txt) | 反例 CorrectInverse | CorrectInverse | 5 | 5 | 5 | 12 |
| [SelectiveUndoNegativePaletteGuess](evidence/SelectiveUndoNegativePaletteGuess.txt) | 反例 CorrectInverse | CorrectInverse | 3 | 3 | 3 | 12 |
| [SelectiveUndoNegativeColorOnly](evidence/SelectiveUndoNegativeColorOnly.txt) | 反例 CorrectInverse | CorrectInverse | 3 | 3 | 3 | 12 |
| [SelectiveUndoNegativeHiddenConflict](evidence/SelectiveUndoNegativeHiddenConflict.txt) | 反例 ConflictReported | ConflictReported | 4 | 4 | 4 | 12 |
| Collaboration（原配置） | 通过 | 通过，队列耗尽 | 616 | 332 | 10 | 0 |

[布局复测摘要](evidence/SelectiveUndo-layout-recheck.txt)保留全部计数与模型哈希。33 项中的 14 个新正向配置 exit 0，13 个覆盖或诊断见证与 5 个错误变体 exit 12，原 Collaboration exit 0。不同配置状态空间重叠，不求和。这次没有重跑 SingleWriter 的大模型，原有模型、配置与证据也没有修改。

### 反例与覆盖见证

- `SelectiveUndoNegativeValueABA` 用值相等替代版本检查，覆盖后来改回相同值的人工编辑。
- `SelectiveUndoNegativeNoCoordinateMap` 不组合旋转后的坐标，在旧位置检查版本，漏掉本来能恢复的格子。该条轨迹不是错格覆盖。
- `SelectiveUndoNegativeColorOnly` 丢掉 completed 的前像，恢复出格式可能合法但语义错误的状态。
- `SelectiveUndoNegativeHiddenConflict` 恢复裁剪保留区，却隐瞒删除区冲突并称全部成功。
- `SelectiveUndoNegativePaletteGuess` 把合并后的同色猜回一个旧色，错误修改原本属于另一旧色的格子。

`SelectiveUndoWitnessRotate`、两个 `WitnessFlip*`、`WitnessCrop` 与 `WitnessChain` 证明自动恢复与部分恢复确实可达，防止“全部拒绝所以永不出错”的假通过。`WitnessPalette` 证明换板屏障确实报告冲突。其余见证覆盖 ABA、完成标记、跨项目拒绝、处理两个目标以及重放契约差异。配置名称都带完整的 `SelectiveUndo` 前缀。

### 相对路径复现

先按本文件 SingleWriter 节的工具下载及 SHA-256 命令，将官方 JAR 放入仓库忽略目录 `.wip/formal-tools/`。下面从仓库根目录开始，Java 17 或更高版本即可运行。JAR 与输出日志均不纳入版本控制。

```sh
cd docs/formal
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-selective-undo-positive \
  -config SelectiveUndoPositive.cfg SelectiveUndo.tla
```

全量复现时，每个配置使用不同的缓存目录。下面的退出码检查不吞掉运行错误；对 exit 12 的结果，还需按表核对指定的不变量名。

```sh
for cfg in SelectiveUndo*.cfg; do
  case "$cfg" in
    SelectiveUndoNegative*|SelectiveUndoWitness*) expected=12 ;;
    *) expected=0 ;;
  esac
  status=0
  java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
    tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
    -metadir "../../.wip/formal-tools/recheck-${cfg%.cfg}" \
    -config "$cfg" SelectiveUndo.tla \
    > "../../.wip/formal-tools/${cfg%.cfg}.log" 2>&1 || status=$?
  test "$status" -eq "$expected" || exit 1
done
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-selective-original-collaboration \
  -config Collaboration.cfg Collaboration.tla
```

真实源码性质检查用 Node 24 原生剥离 TypeScript 类型，不改变算法。从仓库根目录运行：

```sh
node docs/formal/SelectiveUndoSourceCheck.mjs
```

本次实际 13 项通过，见 [源码检查摘要](evidence/SelectiveUndo-source-check.txt)。检查直接导入 `src/core.ts`，换板部分抽取 `src/main.ts` 的原始 handler，在固定本地输入上运行。它确认 paint 改色清 completed、map-palette 保留 completed、非方图几何映射及条件命令重执行的差异，不构成应用选择性撤销或浏览器端到端测试。Node 的类型剥离实验性提示不是测试失败。

## PreviewAccept 扩展模型

2026-11-12（Asia/Taipei）补充，状态为 Proposed。协议说明、冲突分类沿用方式、过期策略与界限见 [预览后由人选择：协议验证](../preview-accept.md)。本次不实现应用功能，也不将不同模型的独立检查视为组合证明。本轮没有重跑 SelectiveUndo 与 SingleWriter。

`PreviewAccept.tla` 在既有选择性撤销的格子、坐标提升、版本守卫和补偿写法上，增加一份方案覆盖层。预览只写覆盖层，不追加持久日志，也不改图纸、色板、完成标记、项目身份或 epoch。拒绝丢掉覆盖层后，持久状态必须与拒绝前一致。接受必须对当前前缀重新推导：有可恢复格子时，把 `Compensate` 作为普通的、之后仍可撤销的写入追加到同一条日志；否则只返回第 2 或第 3 类冲突，不写盘。`AcceptStale` 只在 `AllowStaleAccept = TRUE` 时启用，用来产生反例；好协议禁止把旧前缀上算出的补偿直接应用。第 4 类仍只用于硬停止，预览机制不得制造第 4 类。

主探索限 3×2 格子、颜色 0 到 2、最多 3 条历史操作、最多 2 次预览类动作。定向路径把历史放到最多 4 条、预览类动作最多 4 次。这是有限穷举，不是任意图纸或任意长历史的数学证明。方案过期后的 `RePreview` 与 `Reclassify` 都合法且已单独走到，本轮不挑选产品默认值。

### 配置、预期与仓库布局实测

所有新配置均使用 `PreviewAccept` 前缀。模型与配置放入 `docs/formal/` 后保持字节一致。本次在本分支的 `docs/formal/` 用相对路径重跑全部 21 个新配置，另将原 `Collaboration.cfg` 作为低成本健全性检查重跑一次，共 22 项，均符合预期。工具为与本分支 SingleWriter、SelectiveUndo 相同 SHA-256 的官方 v1.7.4 JAR、TLC 2.19（08 August 2024，rev: 5a47802）、Java 17.0.13，1 worker、seed 20261112、fp 0。仓库布局复测于 2026-11-12 16:07:00 至 16:08:32（Asia/Taipei）完成，主探索 TLC 报告用时 01min 14s。

下表全部为本次仓库布局运行的真实数字。负例与见证在指定不变量首次违反时停止，exit 12 是预期结果，不是正向协议失败或工具崩溃。它们的深度不能解释为完整空间的最大深度。各配置摘要与短轨迹只保留决定性投影，不提交完整日志或缓存。

| 配置 | 预期 | 实际 | 生成状态 | 不同状态 | 深度 | exit |
|---|---|---|---:|---:|---:|---:|
| [PreviewAcceptPositive](evidence/PreviewAcceptPositive.txt) | 通过 | 通过，队列耗尽 | 1872205 | 568443 | 6 | 0 |
| [PreviewAcceptReject](evidence/PreviewAcceptReject.txt) | 通过 | 通过，队列耗尽 | 13 | 6 | 6 | 0 |
| [PreviewAcceptRejectAfterEdit](evidence/PreviewAcceptRejectAfterEdit.txt) | 通过 | 通过，队列耗尽 | 11 | 5 | 5 | 0 |
| [PreviewAcceptRebaseRotate](evidence/PreviewAcceptRebaseRotate.txt) | 通过 | 通过，队列耗尽 | 11 | 5 | 5 | 0 |
| [PreviewAcceptRebaseHuman](evidence/PreviewAcceptRebaseHuman.txt) | 通过 | 通过，队列耗尽 | 17 | 8 | 7 | 0 |
| [PreviewAcceptRebaseHumanRePreview](evidence/PreviewAcceptRebaseHumanRePreview.txt) | 通过 | 通过，队列耗尽 | 14 | 7 | 7 | 0 |
| [PreviewAcceptRebaseHumanReclassify](evidence/PreviewAcceptRebaseHumanReclassify.txt) | 通过 | 通过，队列耗尽 | 13 | 6 | 6 | 0 |
| [PreviewAcceptLaterUndo](evidence/PreviewAcceptLaterUndo.txt) | 通过 | 通过，队列耗尽 | 13 | 6 | 6 | 0 |
| [PreviewAcceptRebaseCrop](evidence/PreviewAcceptRebaseCrop.txt) | 通过 | 通过，队列耗尽 | 11 | 5 | 5 | 0 |
| [PreviewAcceptRebasePalette](evidence/PreviewAcceptRebasePalette.txt) | 通过 | 通过，队列耗尽 | 14 | 7 | 7 | 0 |
| [PreviewAcceptRebaseABA](evidence/PreviewAcceptRebaseABA.txt) | 通过 | 通过，队列耗尽 | 16 | 8 | 8 | 0 |
| [PreviewAcceptRebaseProject](evidence/PreviewAcceptRebaseProject.txt) | 通过 | 通过，队列耗尽 | 14 | 7 | 7 | 0 |
| [PreviewAcceptWitnessRebaseRotate](evidence/PreviewAcceptWitnessRebaseRotate.txt) | 见证 NotRebaseRotate | NotRebaseRotate | 8 | 5 | 5 | 12 |
| [PreviewAcceptWitnessLaterUndo](evidence/PreviewAcceptWitnessLaterUndo.txt) | 见证 NotLaterUndo | NotLaterUndo | 10 | 6 | 6 | 12 |
| [PreviewAcceptWitnessRejectRestored](evidence/PreviewAcceptWitnessRejectRestored.txt) | 见证 NotRejectRestored | NotRejectRestored | 10 | 6 | 6 | 12 |
| [PreviewAcceptWitnessRePreview](evidence/PreviewAcceptWitnessRePreview.txt) | 见证 NotRePreview | NotRePreview | 10 | 6 | 6 | 12 |
| [PreviewAcceptWitnessReclassify](evidence/PreviewAcceptWitnessReclassify.txt) | 见证 NotReclassify | NotReclassify | 10 | 6 | 6 | 12 |
| [PreviewAcceptWitnessConflict](evidence/PreviewAcceptWitnessConflict.txt) | 见证 NotConflict | NotConflict | 8 | 5 | 5 | 12 |
| [PreviewAcceptWitnessPartial](evidence/PreviewAcceptWitnessPartial.txt) | 见证 NotPartial | NotPartial | 8 | 5 | 5 | 12 |
| [PreviewAcceptWitnessStaleRotate](evidence/PreviewAcceptWitnessStaleRotate.txt) | 反例 StaleAcceptHarmless | StaleAcceptHarmless | 10 | 6 | 6 | 12 |
| [PreviewAcceptWitnessStaleHuman](evidence/PreviewAcceptWitnessStaleHuman.txt) | 反例 StaleAcceptHarmless | StaleAcceptHarmless | 8 | 5 | 5 | 12 |
| Collaboration（健全性检查） | 通过 | 通过，队列耗尽 | 616 | 332 | 10 | 0 |

[布局复测摘要](evidence/PreviewAccept-layout-recheck.txt)保留全部计数与模型哈希。21 项中的 12 个正向配置 exit 0，7 个覆盖见证与 2 个过期接受反例 exit 12，原 Collaboration 健全性检查 exit 0。不同配置状态空间重叠，不求和。此前一次非正式检查使用了更新的 TLC（2026.11.03.180953）；本次公开发布的数字全部来自上述 2.19 JAR，21 项计数与那次结果一致。

### 反例与覆盖见证

- `PreviewAcceptWitnessStaleRotate` 在旋转后把旧坐标写到错误格子，覆盖人的擦除，并让另一笔本来可撤销的操作变得不可恢复。
- `PreviewAcceptWitnessStaleHuman` 在人改过同一格之后，仍把旧方案写回去，覆盖人的笔迹。
- 两条反例都破坏可逆性，但没有造成日志分叉。损害不是第 4 类硬停止。

`PreviewAcceptWitnessRebaseRotate` 证明同一条先预览再旋转的路径上，按当前前缀重推导会写到正确位置。`WitnessConflict` 证明人改过同一格后只返回第 3 类、不写盘。`WitnessLaterUndo`、`WitnessRejectRestored`、`WitnessPartial` 分别证明补偿可再撤销、拒绝后再恢复，以及裁剪后的部分恢复。`WitnessRePreview` 与 `WitnessReclassify` 证明两种过期后续动作都可以走到，并且不进入第 4 类；二者都合法，本轮不挑选默认值。

### 相对路径复现

先按本文件 SingleWriter 节的工具下载及 SHA-256 命令，将官方 JAR 放入仓库忽略目录 `.wip/formal-tools/`。下面从仓库根目录开始，Java 17 或更高版本即可运行。JAR 与输出日志均不纳入版本控制。每个配置使用不同的缓存目录。

```sh
cd docs/formal
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-preview-accept-positive \
  -config PreviewAcceptPositive.cfg PreviewAccept.tla
```

全量复现时，下面的退出码检查不吞掉运行错误；对 exit 12 的结果，还需按表核对指定的不变量名。

```sh
for cfg in PreviewAccept*.cfg; do
  case "$cfg" in
    PreviewAcceptWitness*) expected=12 ;;
    *) expected=0 ;;
  esac
  status=0
  java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
    tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
    -metadir "../../.wip/formal-tools/recheck-${cfg%.cfg}" \
    -config "$cfg" PreviewAccept.tla \
    > "../../.wip/formal-tools/${cfg%.cfg}.log" 2>&1 || status=$?
  test "$status" -eq "$expected" || exit 1
done
```

本轮如需重复 Collaboration 健全性检查，可另用独立缓存目录运行原配置，不与上表 21 项的状态数相加：

```sh
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-preview-original-collaboration \
  -config Collaboration.cfg Collaboration.tla
```

## LogBackup 扩展模型

2026-11-12（Asia/Taipei）补充，状态为 Proposed。协议说明、两项仍未决定的产品选择与界限见 [检查点之后收旧日志，以及恢复备份时避免分叉：协议验证](../log-backup.md)。本次不实现应用功能，也不将不同模型的独立检查视为组合证明。本轮没有重跑 SingleWriter、SelectiveUndo 与 PreviewAccept。

`LogBackup.tla` 把检查点、压缩、备份和恢复写成动作。日志是恢复真源，检查点只是可重建的加速缓存。压缩只能丢掉严格早于一份已经持久保存的检查点的前缀，并且未确认提交不得再依赖这段前缀。压缩后，用检查点加重放后缀，必须得到与压缩前相同的作品状态。备份复制项目身份和当时可恢复的镜像。`RestoreMatching` 只在身份一致、且备份是现场可恢复日志的前缀时启用，此时是空操作，不得把现场回退。身份不符、分叉，或备份带有无法证明属于同一条日志的额外后缀，进入第 4 类硬停止，不得改写现场日志。压缩被拒绝不是第 4 类。`AllowCompactBeforeDurable`、`AllowCompactWithUnacked` 和 `AllowRestoreStaleOrDivergent` 只为反例打开。`AllowExplicitReplace` 只为开放选项的可达性见证打开，不是产品默认。

主探索最多 3 条操作；定向路径把上限放到 4。这是有限穷举，不是任意长日志或真实磁盘的数学证明。压缩之后，被丢掉前缀里的操作还能不能做选择性撤销，以及人能不能明确用备份整份替换现有项目，本轮都不选定默认策略。保留多久也仍待评审。

### 配置、预期与仓库布局实测

所有新配置均使用 `LogBackup` 前缀。模型与配置放入 `docs/formal/` 后保持字节一致。本次在本分支的 `docs/formal/` 用相对路径重跑全部 18 个新配置，另将原 `Collaboration.cfg` 作为低成本健全性检查重跑一次，共 19 项，均符合预期。工具为与本分支 SingleWriter、SelectiveUndo、PreviewAccept 相同 SHA-256 的官方 v1.7.4 JAR、TLC 2.19（08 August 2024，rev: 5a47802）、Java 17.0.13，1 worker、seed 20261112、fp 0。仓库布局复测于 2026-11-12 16:45:35 至 16:45:51（Asia/Taipei）完成，整组用时 15.66 秒，主探索 TLC 报告用时 01s。

下表全部为本次仓库布局运行的真实数字。负例与见证在指定不变量首次违反时停止，exit 12 是预期结果，不是正向协议失败或工具崩溃。它们的深度不能解释为完整空间的最大深度。各配置摘要与短轨迹只保留决定性投影，不提交完整日志或缓存。

| 配置 | 预期 | 实际 | 生成状态 | 不同状态 | 深度 | exit |
|---|---|---|---:|---:|---:|---:|
| [LogBackupPositive](evidence/LogBackupPositive.txt) | 通过 | 通过，队列耗尽 | 65994 | 7653 | 12 | 0 |
| [LogBackupPositiveCompact](evidence/LogBackupPositiveCompact.txt) | 通过 | 通过，队列耗尽 | 12 | 6 | 6 | 0 |
| [LogBackupPositiveRestore](evidence/LogBackupPositiveRestore.txt) | 通过 | 通过，队列耗尽 | 12 | 6 | 6 | 0 |
| [LogBackupPositiveRejectFork](evidence/LogBackupPositiveRejectFork.txt) | 通过 | 通过，队列耗尽 | 10 | 5 | 5 | 0 |
| [LogBackupPositiveRejectIdentity](evidence/LogBackupPositiveRejectIdentity.txt) | 通过 | 通过，队列耗尽 | 8 | 4 | 4 | 0 |
| [LogBackupPositiveRejectKeepsJournal](evidence/LogBackupPositiveRejectKeepsJournal.txt) | 通过 | 通过，队列耗尽 | 10 | 5 | 5 | 0 |
| [LogBackupPositiveCompactThenRestore](evidence/LogBackupPositiveCompactThenRestore.txt) | 通过 | 通过，队列耗尽 | 16 | 8 | 8 | 0 |
| [LogBackupWitnessCompact](evidence/LogBackupWitnessCompact.txt) | 见证 NotLegalCompact | NotLegalCompact | 10 | 6 | 6 | 12 |
| [LogBackupWitnessRestore](evidence/LogBackupWitnessRestore.txt) | 见证 NotLegalRestore | NotLegalRestore | 10 | 6 | 6 | 12 |
| [LogBackupWitnessRejectFork](evidence/LogBackupWitnessRejectFork.txt) | 见证 NotRejectFork | NotRejectFork | 8 | 5 | 5 | 12 |
| [LogBackupWitnessRejectIdentity](evidence/LogBackupWitnessRejectIdentity.txt) | 见证 NotRejectIdentity | NotRejectIdentity | 6 | 4 | 4 | 12 |
| [LogBackupWitnessRejectKeepsJournal](evidence/LogBackupWitnessRejectKeepsJournal.txt) | 见证 NotRejectKeepsJournal | NotRejectKeepsJournal | 8 | 5 | 5 | 12 |
| [LogBackupWitnessCompactThenRestore](evidence/LogBackupWitnessCompactThenRestore.txt) | 见证 NotCompactThenRestore | NotCompactThenRestore | 14 | 8 | 8 | 12 |
| [LogBackupWitnessExplicitReplace](evidence/LogBackupWitnessExplicitReplace.txt) | 见证 NotExplicitReplace | NotExplicitReplace | 12 | 7 | 7 | 12 |
| [LogBackupNegativeCompactBeforeDurable](evidence/LogBackupNegativeCompactBeforeDurable.txt) | 反例 RecoverableMatchesHist | RecoverableMatchesHist | 10 | 6 | 6 | 12 |
| [LogBackupNegativeCompactUnacked](evidence/LogBackupNegativeCompactUnacked.txt) | 反例 UnackedNotStranded | UnackedNotStranded | 10 | 6 | 6 | 12 |
| [LogBackupNegativeRestoreStale](evidence/LogBackupNegativeRestoreStale.txt) | 反例 RecoverableMatchesHist | RecoverableMatchesHist | 10 | 6 | 6 | 12 |
| [LogBackupNegativeRestoreDivergent](evidence/LogBackupNegativeRestoreDivergent.txt) | 反例 NoFork | NoFork | 8 | 5 | 5 | 12 |
| Collaboration（健全性检查） | 通过 | 通过，队列耗尽 | 616 | 332 | 10 | 0 |

[布局复测摘要](evidence/LogBackup-layout-recheck.txt)保留全部计数与模型哈希。18 项中的 7 个正向配置 exit 0，7 个覆盖见证与 4 个错误变体 exit 12，原 Collaboration 健全性检查 exit 0。不同配置状态空间重叠，不求和。此前一次本地检查使用了同一份官方 2.19 JAR；本次公开发布的数字全部来自上述仓库布局复测，18 项计数与那次结果一致。

### 反例与覆盖见证

- `LogBackupNegativeCompactBeforeDurable` 在检查点尚未持久时就丢掉旧前缀，可恢复日志只剩下后缀，与完整历史不一致。
- `LogBackupNegativeCompactUnacked` 在未确认提交的基础前缀仍短于将被丢掉的那段时压缩，这条恢复路径无法再核对基础前缀。
- `LogBackupNegativeRestoreStale` 把较早的前缀备份写回已经继续追加的现场日志，已经追加的后缀从可恢复镜像里消失。
- `LogBackupNegativeRestoreDivergent` 未做前缀核对，就把分叉备份写进现场日志。

`LogBackupWitnessCompact` 证明合法压缩可达：先打好持久检查点，再追加，再收掉旧前缀，用检查点加重放后缀仍得到压缩前的作品状态。`WitnessRestore` 证明备份已是现场前缀时，匹配恢复不改现场。`WitnessRejectFork` 与 `WitnessRejectIdentity` 证明分叉和身份不符会硬停止，且不改现场日志。`WitnessRejectKeepsJournal` 证明拒绝后未确认记录仍在。`WitnessCompactThenRestore` 证明压缩后再备份可恢复镜像，匹配恢复仍不改现场。`WitnessExplicitReplace` 只证明受开关控制的显式替换可以走到，不是产品默认。

### 相对路径复现

先按本文件 SingleWriter 节的工具下载及 SHA-256 命令，将官方 JAR 放入仓库忽略目录 `.wip/formal-tools/`。下面从仓库根目录开始，Java 17 或更高版本即可运行。JAR 与输出日志均不纳入版本控制。每个配置使用不同的缓存目录。

```sh
cd docs/formal
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-log-backup-positive \
  -config LogBackupPositive.cfg LogBackup.tla
```

全量复现时，下面的退出码检查不吞掉运行错误；对 exit 12 的结果，还需按表核对指定的不变量名。

```sh
for cfg in LogBackup*.cfg; do
  case "$cfg" in
    LogBackupNegative*|LogBackupWitness*) expected=12 ;;
    *) expected=0 ;;
  esac
  status=0
  java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
    tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
    -metadir "../../.wip/formal-tools/recheck-${cfg%.cfg}" \
    -config "$cfg" LogBackup.tla \
    > "../../.wip/formal-tools/${cfg%.cfg}.log" 2>&1 || status=$?
  test "$status" -eq "$expected" || exit 1
done
```

本轮如需重复 Collaboration 健全性检查，可另用独立缓存目录运行原配置，不与上表 18 项的状态数相加：

```sh
java -Xmx2g -XX:+UseParallelGC -cp ../../.wip/formal-tools/tla2tools.jar \
  tlc2.TLC -workers 1 -seed 20261112 -fp 0 \
  -metadir ../../.wip/formal-tools/recheck-logbackup-original-collaboration \
  -config Collaboration.cfg Collaboration.tla
```
