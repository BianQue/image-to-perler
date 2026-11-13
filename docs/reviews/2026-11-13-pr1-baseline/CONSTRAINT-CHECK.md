状态：草稿，待用户审阅

Head：`bdc9c0adc8f0be4b329bf43b7babdae45693cae7`  
Base / Merge base：`ac598aa3102a1a2b54bef680d78cb46baa16ae9b`

**未发现默认政策之间、与所依赖官方不变量或 S1–S5 顺序之间的冲突。** 这是有限模型及静态约束核对结论，不是实现验收或所有模块的组合证明。权威输入为 2026-11-13 16:05 +08:00 接受的 [DEFAULT-DECISIONS.md](../perler-pr1-constraints/DEFAULT-DECISIONS.md)。V3/V4 当前代码仍违反已接受契约，属于已排入 S5-a/S5-b 的实现风险。

| 默认 | 结果 | 范围、映射及理由 |
|---|---|---|
| Q1 | not checked | `LogBackup.projectId`、`SingleWriter.ProjectIdentity`涉及身份；没有真实目录、配额、停止写入及保留期限模型，不能证明目录隔离与磁盘满行为。 |
| Q2 | holds | `LogBackup`检查点独立于 Compact；ProductLog 禁用压缩并保留完整日志，抽象重启后记录仍可读取。未把普通 50 份快照上限套入。 |
| Q3 | holds | `RestoreMatching`或`RejectRestore`；匹配不改现场，较长/分叉/异身份备份拒绝，待发保留；替换及违规恢复开关均 FALSE。 |
| Q4 | holds | `PreviewAccept`允许的行为中选择 RePreview，再由人重新确认；这是收窄。官方路径复验通过；未声称现有模型已经验证独立的 UI 再确认令牌。 |
| Q5 | holds | S2 范围与现有 `resizeProject`一致；`SelectiveUndo`单列 Crop 验证删除区冲突，不是任意矩形 crop 验收，也未证明全部下边缩小情况。 |
| Q6 | not checked | `Workflow.BoundedSearch`覆盖最多两轮；每轮预算、1–3 个复看、获准真实图及独立样本校准无对应模型。80 和研究量化次数不能变为产品资源承诺。 |
| Q7 | not checked | 无量化状态模型；静态确认现有 quantize 的 `maxColors`可变，保持算法与 Q11“24 不是硬上限”不冲突；未做代码等价或图像校准验收。 |
| Q8 | holds | `SelectiveUndo.CorrectInverse`保留已提交具体效果；`Collaboration.Fresh`、`SingleWriter.Fresh`仍检查新提交。没有改成重执行后续条件命令。 |
| Q9 | not checked | `SingleWriter`/`SingleWriterLive`假定原子持久记录；Node.js 24、fsync、排他、真实硬件、浏览器驱逐和平台支持均未验收。 |
| Q10 | holds | PLAN 明确 S2 内存语义、不发持久成功；S3-d/S3-h 承担集成 `AcknowledgedIsDurable`，阶段职责无倒置。 |
| Q11 | not checked | `Workflow`只有确认应用与两轮边界；Agent 评审、最小尺寸、再减色未建模。与 Q7 的 24 色口径无冲突；涉及 Q13 的 screen 子集另验。 |
| Q12 | holds | 静态核对 26 个 PR，依赖均指向表中后继，无倒阶段边、无环；超 M 在同阶段拆分不改变顺序。S/M 工时或行数可达性未证明。 |
| Q13 | holds | intended-policy 小模型中 weak 最佳项 shown、无推荐，note 增删及复算不改变推荐/展示，稳定并列可同时成立。当前代码 V3/V4 仍需修复。 |
| R2 | not checked | 无措辞模型；S5-c 限“256 px”说明，未承诺优化读取。本轮不新增 V5 技术结论。 |
| R3 | not checked | 属核查范围约束，无状态不变量；未扩大到评论、私人实验或旧版 TLC。 |
| P1 | holds | 本轮实际运行 26 个官方配置、2 个小模型及 2 个既有探针；历史 90/90 不计为本轮复验。应用全套测试、构建、浏览器、故障注入仍未在本轮复验。 |

以下路径以 `perler-pr1-constraints/` 为根。完整 [90 个官方配置映射](../perler-pr1-constraints/charts/CONFIG-MAPPING.md)逐项列出模块、政策、开关行号、正向/负向/见证含义和是否本轮复验。7 个 `.tla`及 90 个 `.cfg`与 pinned clone 字节一致，见 [source-identity.txt](../perler-pr1-constraints/charts/official/source-identity.txt)。没有修改任何现存 git clone、计划或远端状态。

| 政策交互 | 官方原文（文件及行） | 判断 |
|---|---|---|
| Q2 + 重启撤旧操作 | `official/LogBackup.tla:122` “Checkpoint ==”；`:128` “UNCHANGED <<projectId, epoch, hist, phys, dropped, pending, unacked,”；`:428` “CheckpointDoesNotDelete ==”；`:459` “RecoverableMatchesHist == RecoverableLog = hist” | 检查点不删除历史，无需 Compact。小模型重启后 `available = hist`表示完整操作记录可供后续撤销判定，不保证每条操作无冲突或可自动撤销。 |
| Q2 与合法压缩 | `official/LogBackup.tla:198` “Compact ==”；`:313` “\/ PersistCheckpoint \/ Checkpoint \/ Compact \/ Backup”；`:496` “This is not a”；`:497` “product default; the choice remains open.”；`:498` “PrefixOpsNotSelectivelyUndoable ==” | Compact 没有 Allow 开关，官方正向/见证确实可达；Q2 明确不提供该动作。小模型完整保留 SafetyOK（含前缀记账不变量），未削弱该规则。 |
| Q3 + 待发 | `official/LogBackup.tla:254` “Conservative: restore is a no-op”；`:256` “A backup with extra ops is not applied,”；`:258` “RestoreMatching ==”；`:271` “RejectRestore ==”；`:464` “RestoreRefusesSafely ==”；`:477` “UnackedPreservedOnReject ==” | 备份比现场长也不快进。ProductLog 补充较长备份拒绝分支，官方小路径覆盖匹配、分叉、异身份和待发保留。 |
| Q3 与替换见证 | `official/LogBackup.tla:298` “ExplicitReplace ==”；`:299` “/\ AllowExplicitReplace”；`:282` “RestoreStaleOrDivergent ==”；`:283` “/\ AllowRestoreStaleOrDivergent” | WitnessExplicitReplace 的 TRUE 仅展示开放选项；负向恢复故意打开违规行为。产品通过运行中两者都 FALSE，不把见证 exit 12 当产品失败。 |
| Q4 + 过期预览 | `official/PreviewAccept.tla:180` “IsStale == proposal.active /\ proposal.prefixLen # Len(history)”；`:200` “act == IF proposal.active THEN "repreview" ELSE "preview"”；`:211` “Reclassify ==”；`:222` “AcceptRebased ==”；`:247` “/\ AllowStaleAccept” | `AllowStaleAccept=FALSE`禁的是 AcceptStale；AcceptRebased 可在旧 proposal 上重新推导，Reclassify 也合法。Q4 不提供 Reclassify，并要求过期时 RePreview/再确认，是比官方更窄的策略。 |
| Q4 保持安全 | `official/PreviewAccept.tla:452` “CorrectAccept ==”；`:481` “NoSilentOverwrite ==”；`:482` “last.action # "acceptRebased" \/ last.accepted \subseteq last.safe”；`:430` “MetaDoesNotWrite ==”；`:490` “ConflictIsTyped ==” | 缩减动作不会使这些状态安全不变量失效。RePreview 是不写作品/历史的元操作；计划没有依赖免 RePreview 的旧方案成功接受。 |
| Q5 + Q8 | `official/SelectiveUndo.tla:52` “Crop ==”；`:53` “LET nw == w-1”；`:98` “ELSE IF RefPosition(k,p)=0 THEN "cropped"”；`:101` “Independent replay oracle: replay committed effects, NOT UI commands.”；`:246` “CorrectInverse ==”；`:260` “ConflictReported ==”；`official/README.md:267`“不是重新执行旧 UI 条件命令” | 原模型只删除右列。映射、稳定格身份、版本和删除区冲突可与具体效果逆运算并存；不推论任意 crop 已验收。 |
| Q8 新并发提交 | `official/Collaboration.tla:45` “This operation reads and writes cell 1; cell 2 is independent.”；`:46` “Fresh == versions[1] = base[1] /\ structure = baseStructure”；`official/SingleWriter.tla:18` “Fresh(m) == ops[m.id].base = disk.log /\ ops[m.id].before = Replay(disk.log)” | 不重执行旧条件命令不等于取消新提交读依赖检查。复杂填充连通性/读集不由这两个有限抽象证明。 |
| Q9 + Q10 | `official/SingleWriter.tla:126` “Flush ==”；`:135` “ReplyWork ==”；`:136` “/\ serviceUp /\ work # None /\ Known(work)”；`:226` “AcknowledgedIsDurable == \A t \in Tabs: b[t].saved \subseteq Ids(disk.log)”；`official/README.md:163`“磁盘仍假设完整记录原子持久化” | 这些是不改变的集成服务承诺；PLAN.md:178 明言“S2 只显示本地语义结果，持久成功交 S3-d/S3-h”。不能把 S2 的本地成功等同持久 ack。 |
| Q9 恢复前提 | `official/SingleWriterLive.tla:3` “Recovery-only suffix”；`:5` “freezes, losses or subsequent crashes after this stabilization point.”；`:28`起弱公平性；`:36` “EventualReconciliation == <> Reconciled” | 112 distinct states 通过，限稳定后的恢复后缀；不保证持续故障下必定恢复，更不覆盖 IndexedDB 被清理。 |
| Q6 + Q11 | `official/Workflow.tla:22` “/\ phase = "ready" /\ round < 2”；`:65` “BoundedSearch == round <= 2”；`:66` “ConfirmedApply == writes > 0 => approved”；`official/README.md:81`“模型将达标判断作为外部输入。” | 两轮、确认应用可复验；预算与最终人工判断仍外置。 |
| Q7 + Q11 的 24 色 | pinned `src/core.ts:132`参数 `maxColors`；`:135` “maxColors < 1 || maxColors > 4096”；`docs/agent-collaboration-design.md:79`“默认自动选择颜色数量，不固定为 24 色。” | 保持现有 quantize 并不固定 24 色；独立研究中的固定预算与产品上限无冲突。 |
| Q12 + Q10 | `PLAN.md:11–36`的 PR 总表、`:81`阶段规则；pinned `docs/agent-collaboration-design.md:164–168`顺序为会话记录→选择性撤销→服务持久化→候选导出→说明/校准/搜索验收 | [stage-order.txt](../perler-pr1-constraints/charts/stage-order.txt)：26 个节点无环。S3-f/g 汇合 S3-h，S5-a/b/c 汇合 S5-d，校准 S5-e 在接入 S5-f 之前。 |

本轮复验结果如下。正向 exit 0；负向和可达性见证 exit 12 含义不同，均按配置意图解释。每个官方配置的精确命令、退出码和原始日志在 `charts/official/<配置名>/{command.txt,exit-code.txt,tlc.out}`。未相加重叠状态空间。

| 配置 | exit | distinct states | 结果/违反项 |
|---|---:|---:|---|
| Collaboration | 0 | 332 | 通过 |
| Workflow | 0 | 756 | 通过 |
| StaleCommit | 12 | 21 | 负向：NoSilentOverwrite |
| EarlyAck | 12 | 30 | 负向：AcknowledgedIsDurable |
| ValueUndo | 12 | 228 | 负向：NoSilentOverwrite |
| SingleWriterLive | 0 | 112 | 通过 |
| SingleWriterEarlyAck | 12 | 227 | 负向：AcknowledgedIsDurable |
| SingleWriterCoverServiceAhead | 12 | 16097 | 见证：NotServiceAheadReplayed |
| LogBackupPositiveRestore | 0 | 6 | 通过 |
| LogBackupPositiveRejectKeepsJournal | 0 | 5 | 通过 |
| LogBackupPositiveRejectFork | 0 | 5 | 通过 |
| LogBackupPositiveRejectIdentity | 0 | 4 | 通过 |
| LogBackupPositiveCompact | 0 | 6 | 通过 |
| LogBackupWitnessCompact | 12 | 6 | 见证：NotLegalCompact |
| LogBackupWitnessExplicitReplace | 12 | 7 | 见证：NotExplicitReplace |
| LogBackupNegativeRestoreStale | 12 | 6 | 负向：RecoverableMatchesHist |
| LogBackupNegativeRestoreDivergent | 12 | 5 | 负向：NoFork |
| PreviewAcceptRebaseHumanRePreview | 0 | 7 | 通过 |
| PreviewAcceptWitnessRePreview | 12 | 6 | 见证：NotRePreview |
| PreviewAcceptWitnessStaleHuman | 12 | 5 | 负向：StaleAcceptHarmless |
| PreviewAcceptRebaseRotate | 0 | 5 | 通过 |
| SelectiveUndoPositiveCrop | 0 | 4 | 通过 |
| SelectiveUndoWitnessCrop | 12 | 4 | 见证：NotPartial |
| SelectiveUndoPositiveReadDependency | 0 | 4 | 通过 |
| SelectiveUndoWitnessReadDependency | 12 | 4 | 见证：NotRawReplayGap |
| SelectiveUndoPositiveChain | 0 | 6 | 通过 |
| ProductLog（scratch） | 0 | 17 | 全部不变量通过，死锁检查开启 |
| AdvisoryScreen（scratch） | 0 | 46 | 全部不变量通过，死锁检查开启 |

未发现政策冲突，因此没有政策违反的编号路径。官方负向/见证轨迹保留在上述日志，不能把它们改名为默认合取反例。其余 64 个官方配置未重跑：使用上述小路径覆盖本次交互；特别是 PreviewAcceptPositive、SelectiveUndoPositive 及 SingleWriter 主探索未用大规模穷举或出图。历史审问的 90/90 只作背景，未替代本轮结果。

ProductLog 的 [图](../perler-pr1-constraints/charts/product-log/chart.mmd)、[后备报告](../perler-pr1-constraints/charts/product-log/report.md)、[TLC](../perler-pr1-constraints/charts/product-log/tlc.out)检验：不删前缀、RecoverableLog = hist、检查点可重建、抽象重启后全日志仍可读，以及保守恢复保留待发。保留官方全部 SafetyOK；非产品 Compact 不在 ProductNext。除继承动作外，Restart 是“丢失未持久检查点、保留完整日志”的抽象假设，OfferLonger 是外部备份输入。因此这不是整个实现的 refinement 证明，也不是 LogBackup 与 SelectiveUndo 的机械组合证明。它证明此有限策略可以同时满足这些约束；完整日志可用与具体撤销安全仍需 S3-h 联合验收。

Q4 本轮不另写预览模型。`PreviewAcceptWitnessRePreview/tlc.out` 的官方编号路径为：1 初始；2 Agent 修改；3 预览；4 人修改同格；5 重新推导报告 conflict；6 RePreview。`PreviewAcceptRebaseHumanRePreview`安全检查通过；其中无可恢复项时不会追加补偿。该路径符合“冲突后重新预览”方向，但没有独立的人类确认变量，也不证明任意 UI 循环都安全。静态收窄论证是：旧 proposal 不得成功接受；重新预览后结果变化需新的明确确认；无进展只说明冲突或结束。重复预览只能执行 MetaDoesNotWrite，接受仍必须是用户动作。PLAN.md:408 接受了这些额外限制；官方 Explore 中允许旧 proposal 的 AcceptRebased、Reclassify 不构成相反要求。这里确认的是政策兼容，实际“无偷偷接受循环”的交互/令牌验收留 S2-c。

AdvisoryScreen 的 [图](../perler-pr1-constraints/charts/advisory-screen/chart.mmd)、[后备报告](../perler-pr1-constraints/charts/advisory-screen/report.md)、[TLC](../perler-pr1-constraints/charts/advisory-screen/tlc.out)覆盖单 broken、全 broken/并列、全 warn、正常竞争及正常并列五种输入；note 可反复增删并重新筛选。`WeakBestStaysShown`、`WeakRecommendsNothing`、`NotesDoNotChangeRecommendation`、`NotesDoNotChangeDisplay`、`StableTies`同时通过。候选编号作为固定输入顺序的抽象稳定并列键；不是新增产品 ID 排序要求。未模型化评分算法、所有混合组或真实图片。

已用既有 W2 探针对 pinned 代码的只读副本重放（只改副本探针 import 路径，源码字节哈希见 `charts/probes/source-hashes.json`）：

| 已知问题 | 本轮重放路径 | 观察及后续 |
|---|---|---|
| V3 | 1 生成既有 disc 夹具；2 单个 shuffled broken 候选；3 screen | [输出](../perler-pr1-constraints/charts/probes/advisory-weak.out)：`group="weak"`，`recommendedId=null`，最佳项 `state="folded"`；违背 shown，S5-a 修复。探针 exit 0 是执行成功，不是契约通过。 |
| V4 | 1 同豆数 16384 的两个候选（100/98）；2 原颜色筛选；3 仅高分者改为通道互换的既有 note 对照，再筛选 | [输出](../perler-pr1-constraints/charts/probes/advisory-note.out)：高分者加入 `colour-shift` note 后，推荐从 `higher-score`变为`lower-score`，高分者由 recommended 变 shown；S5-b 修复。探针 exit 0。 |

合同原文：pinned `src/advisory/types.ts:27` “note: shown to the user, no effect on state.”；`:60` “weak: no candidate is clean. Nothing is recommended and the best one is still shown.”。现状原因分别为 `src/advisory/index.ts:86`的 broken 优先折叠，及`:82`的 `a.flags.length - b.flags.length`。这两条是已知代码与契约偏差，不是新政策冲突；本轮未修实现。

statechart 技能实际运行失败，两个 spec 均 exit 2：`Cannot read properties of undefined (reading 'tag')`；不能把它记作 TLC 失败或通过。保留 `charts/product-log-statechart-attempt.out`、`charts/advisory-statechart-attempt.out`及对应 exit 文件。按技能后备路径直接 TLC 检查相同 cfg，读取输出后由 DOT 和同一 view 生成 Mermaid 及后备 report.md；没有伪称它们是脚本成功产物。两张图为 12/8 个合并标签、16/14 条箭头；省略同标签内部跳转，合法 Done 自环明确保留。未发生规则违反，故没有被隐藏的 bug 路径。

模型遗漏和残余风险：Q9 运行时官方语义、真实文件系统追加/同步/进程排他、断电、目录 sync、磁盘满及 IndexedDB 驱逐未验证；平台及独立存储故障环境仍须实现前由维护者确认。Q1 无无限保留保证。全日志保存不能保证冲突操作自动可撤。Q5 下边 resize 与任意尺寸没有由单列模型证明，任意 crop 不在本轮。Q6/Q11 的真实图、预算、人工特征判断及最小尺寸没有证明。Q10 是分阶段职责核对，不是提前放宽集成 ack 契约。R2/R3 未扩展为优化、私人实验或评论验证。应用测试、构建、浏览器、真实故障注入本轮未跑。新模型与官方模型均为有界检查，非无界证明。

复现（本轮工具：Node `v24.22.1`，Java `17.0.13`，TLC `2026.11.03.180953`；JAR SHA-256 `e20447644bfabd29d6bd0fc2c0eb1473fb301c1a0e4dfe1961938ce5a191edbf`；无网络）：

```sh
cd /workspace/codex/ws/perler-pr1-constraints
export TLA2TOOLS=/home/box/.local/tla/tla2tools.jar
export JAVA=/home/box/.local/jre17/bin/java
export PATH="/home/box/.local/jre17/bin:/home/box/.local/bin:$PATH"
# 每次使用新目录；命令应先检查该目录不存在。
recheck=$(mktemp -d "$PWD/charts/recheck-XXXXXX")
statechart=/home/box/sand-data/plugins/cache/cursor-public/pstack/6e359ce0aba9e927914d8a940510aa2ef66a8f23/skills/statechart/scripts/statechart
"$statechart" specs/ProductLog.tla --config specs/ProductLog.cfg --view specs/ProductLog.view.mjs --out "$recheck/product-log"
"$statechart" specs/AdvisoryScreen.tla --config specs/AdvisoryScreen.cfg --view specs/AdvisoryScreen.view.mjs --out "$recheck/advisory-screen"
# 若同样脚本错误，使用独立新后备目录；不修改 cfg 或去掉不变量。
mkdir "$recheck/product-log-direct" "$recheck/advisory-screen-direct"
/home/box/.local/bin/tlc -workers 1 -metadir "$recheck/product-log-direct/states" -dump dot,actionlabels "$recheck/product-log-direct/states.dot" -config specs/ProductLog.cfg specs/ProductLog.tla > "$recheck/product-log-direct/tlc.out" 2>&1
printf '%s\n' "$?" > "$recheck/product-log-direct/exit-code.txt"
/home/box/.local/bin/tlc -workers 1 -metadir "$recheck/advisory-screen-direct/states" -dump dot,actionlabels "$recheck/advisory-screen-direct/states.dot" -config specs/AdvisoryScreen.cfg specs/AdvisoryScreen.tla > "$recheck/advisory-screen-direct/tlc.out" 2>&1
printf '%s\n' "$?" > "$recheck/advisory-screen-direct/exit-code.txt"
node specs/fallback-chart.mjs "$recheck/product-log-direct" specs/ProductLog.view.mjs
node specs/fallback-chart.mjs "$recheck/advisory-screen-direct" specs/AdvisoryScreen.view.mjs
# 官方配置实例；每个已运行配置的原始完整命令见对应 command.txt。
timeout 600 /home/box/.local/bin/tlc -workers 1 -noGenerateSpecTE -metadir "$recheck/legal-restore" -config official/LogBackupPositiveRestore.cfg official/LogBackup.tla
node --no-warnings probes/replay/advisory-weak.mjs
node --no-warnings probes/replay/advisory-note.mjs
```

其余 25 个官方配置用 `charts/official/results.json`所列 module/config 配对代入最后一条 TLC 命令，并为每个配置分配新的 metadir；精确原始命令全部留存。`-noGenerateSpecTE`只阻止负向/见证在源旁写派生轨迹模块，不更改检查语义；首次运行自动生成的文件已移入 `charts/official/generated-traces/`。所有源 `.tla/.cfg`未变。

交付说明：Codex 会话的工作区写权限仅限 `perler-pr1-constraints/`，写入 `/workspace/codex/ws/perler-pr1-review/CONSTRAINT-CHECK.md` 时得到 `Errno 30: Read-only file system`。协调者随后把同一份报告复制到该指定路径。完整副本仍保留在 `/workspace/codex/ws/perler-pr1-constraints/CONSTRAINT-CHECK.md`。
