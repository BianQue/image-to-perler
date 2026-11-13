# PR #1 审问报告（草稿，待用户审阅）

状态：草稿，待用户审阅

只读审问，未改目标仓库，未改远端状态。

## 0. 钉定信息

| 项 | 值 |
|---|---|
| 仓库 / PR | BianQue/image-to-perler · PR #1 · `Design: Agent-assisted collaboration for Image to Perler` |
| Head（codex/agent-collaboration-design） | `bdc9c0adc8f0be4b329bf43b7babdae45693cae7` |
| Base（main） | `ac598aa3102a1a2b54bef680d78cb46baa16ae9b` |
| Merge base | `ac598aa3102a1a2b54bef680d78cb46baa16ae9b`（main 未前进） |
| 范围 | merge base → head 全部 diff：211 个文件，+6852 行；11 个提交；加所提供 PR 描述快照（`pinned/pr-body.md`，与 `pinned/pr.json` 的 body 一致） |
| 远端复核（协调者，2026-11-13 约 00:10 +08:00） | `git ls-remote`：head、main 的 SHA 与上表一致；原始输出见 `evidence/COORDINATOR-EVIDENCE.md` §A |
| PR 状态 | 快照 `pinned/pr.json`（2026-11-12 23:58 +08:00）`isDraft=false`；协调者 00:10 +08:00 只读复查为 **`isDraft=true`**，见 §4 |

## 1. 已核实发现（5 条，合并同根因后）

严重度按"信任该说法的读者会被误导的程度"。V1–V5 的命令均由协调者亲自重跑，输出与 worker 一致（`evidence/COORDINATOR-EVIDENCE.md` §B）；探针脚本位于各 worker 目录。

| id | 标题 | 严重度 | 发现者 | 
|---|---|---|---|
| V1 | PR 描述称"仅文档/无运行时源码"，分支实际新增 `src/advisory/*` 与测试 | 中 | W1-F1、W2-F1、W3-F1 |
| V2 | PR 描述（及设计文档 :178）只讲"两个模型、3 个变异配置"，分支实际是 7 个 `.tla`、90 个 `.cfg`、95 个证据文件 | 中 | W1-F2、W2-F2 |
| V3 | `weak` 组承诺"最佳项仍展示"，实际 `broken` 项被折叠 | 低 | W2-F4、W3-F2 |
| V4 | `note` 标志声称"不影响状态"，实际改变推荐结果 | 中 | W2-F5、W3-F3 |
| V5 | 注释称"评估器读取不超过 256 px 画布"，实际每个候选读取整张原图 | 低（措辞有歧义） | W3-F4 |

### V1　范围说明与代码不符
- 引文：`pr-body.md:3` "This is a **documentation-only design proposal**"；`pr-body.md:33` "No runtime source or existing sample outputs are included."；`pr-body.md:41` "**Blast Radius:** documentation"。
- 命令：
  ```
  git -C repo diff --name-status ac598aa3102a1a2b54bef680d78cb46baa16ae9b bdc9c0adc8f0be4b329bf43b7babdae45693cae7 -- src tests
  ```
- 输出（节选，共 8 行，全为 `A`）：`src/advisory/{index,measure,types}.ts`、`tests/advisory-fixtures.ts`、`tests/advisory-parity-cases.ts`、`tests/advisory-parity.test.ts`、`tests/advisory-reference.json`、`tests/advisory.test.ts`。对应提交 `910aad5`（"Add advisory candidate screen with procedural tests"）。
- 冲突：描述写"没有运行时源码"，分支加了可调用的 `screen`。该模块未被工作台引用，所以不是"协作功能已实现"，但"只含文档"不成立，审阅者可能跳过源码与测试。

### V2　模型清单低报
- 引文：`pr-body.md:11` "Two finite models and three negative configurations"；`pr-body.md:32` "two independent bounded safety checks"；`docs/agent-collaboration-design.md:178` "TLC 在两个独立有限模型中检查了 1,088 个不同状态 … 3 个变异配置均找到预期反例"。
- 命令与输出：
  ```
  git -C repo ls-tree -r --name-only bdc9c0adc8f0be4b329bf43b7babdae45693cae7 docs/formal
  ```
  清单统计结果：`.tla` 7、`.cfg` 90、`docs/formal/evidence/` 文件 95；文件名含 `Negative` 的 `.cfg` 恰为 9 个（另有 EarlyAck/ValueUndo/StaleCommit 等）。
  Worker 1 的分类为 19 个故意出错配置（含 Witness 型 stale 变体）；协调者只独立核实了 7/90/95 与"Negative 命名 9 个"，19 为 worker 分类，未逐个复核。
- 冲突：新增的 SingleWriter、SingleWriterLive、SelectiveUndo、PreviewAccept、LogBackup 均未体现在描述里。原模型的 332/756 状态数本身正确（协调者重跑：Collaboration 332、Workflow 756，EarlyAck/ValueUndo/StaleCommit 均 exit 12，见 `evidence/COORDINATOR-EVIDENCE.md` §C）。

### V3　weak 组折叠最佳项
- 引文：`src/advisory/types.ts:60` "weak: no candidate is clean. Nothing is recommended and the best one is still shown."；`src/advisory/index.ts:66` "the best candidate stays shown."
- 命令（在 `/workspace/codex/ws/perler-pr1-w2`）：`node --no-warnings probes/advisory-weak.mjs`
- 输出：`{"group":"weak","recommendedId":null,"reports":[{"id":"only-broken","score":3,"state":"folded", ...}]}`
- 冲突：`index.ts:86` 无条件把带 `broken` 的候选置为 `folded`，覆盖了 weak 组"最佳项仍展示"。折叠项仍可选，所以冲突在默认展示状态，不是丢候选。

### V4　note 影响推荐
- 引文：`src/advisory/types.ts:27` "note: shown to the user, no effect on state."
- 命令：`node --no-warnings probes/advisory-note.mjs`（W2 目录）；`node --disable-warning=ExperimentalWarning probes/advisory.mjs notes`（W3 目录）
- 输出：同一对候选（豆数同为 16384，分数 100/98 或 100/97），去掉 `colour-shift` note 时高分者 `recommended`；加上 note 后高分者变 `shown`，低分者变 `recommended`。
- 冲突：`src/advisory/index.ts:82` 比较器 `a.flags.length - b.flags.length` 排在分数之前，note 被计入。

### V5　"读取不超过 256 px"与全图读取
- 引文：`src/advisory/types.ts:10` "The evaluator never reads more than a 256 px canvas."
- 命令（W3 目录）：`node --disable-warning=ExperimentalWarning probes/advisory.mjs reads`
- 输出：`{"width":512,"height":512,"candidates":1,"sourceByteReads":1048576,...}`；2 个候选为 `2097152`。
- 冲突：`measure.ts:91-95` `baseCanvas` 先遍历整张原图，`index.ts:74` 每个候选各调一次；只有之后的度量画布长边限 256。**注意**：该句放在 `rgba` 字段注释里，可以读成"输入读取上限"（与代码冲突），也可以读成"度量画布上限"（与代码一致）。保留为低严重度。

## 2. 各 worker 的数量

| Worker | 镜头 | 原始发现 | 保留为已核实 | 丢弃（协调者复核后） | worker 自己丢弃的候选 |
|---|---|---|---|---|---|
| W1 | 说法 vs 代码 | 3（F1–F3） | 2（→V1、V2） | 1（F3 Draft，见 §4） | 5 |
| W2 | 内部矛盾 | 5（F1–F5） | 4（→V1、V2、V3、V4） | 1（F3 Draft） | 7 |
| W3 | 夸大 | 4（F1–F4） | 4（→V1、V3、V4、V5） | 0 | 7 |
| W4 | 实施顺序 | 0 | 0 | 0 | 10 |

合并：V1 = W1-F1+W2-F1+W3-F1；V2 = W1-F2+W2-F2；V3 = W2-F4+W3-F2；V4 = W2-F5+W3-F3；V5 = W3-F4。已核实合计 5 条（原始发现共 12 条，其中 2 条 Draft 快照发现按既有协调者复核记录丢弃；余下 10 条合并为 5 条）。

## 3. 未构成发现的检查（历史通过项）

- W3 报告记载其在 TLC（版本 `2026.11.03.180953`，与文档的 TLC 2.19 JAR 不是同一个）上重跑 **90/90** 配置：状态数、深度、退出码全部与证据文件一致（40 个正向配置通过，50 个负向/覆盖配置 exit 12）。证据文件中的 142 个模型/配置 SHA-256 全部匹配（`workers/w3-RESULT.md:111–117`；本次也逐项静态计算哈希确认匹配，未运行模型）。`VERIFIED-FINDINGS.md` 早先写的 88/90 是 W3 运行中途的读数（笔误，已更正）；最终为 90/90。
- W3 记载 `npx vitest run` 3 个文件 33 个测试通过；`npx tsc --noEmit` exit 0；`node docs/formal/SelectiveUndoSourceCheck.mjs` 13 项通过（`workers/w3-RESULT.md:114–116`）。W1 运行的是两个 advisory 文件、20 个测试，另有类型检查和 13 项源码检查；不将 W1 写成完整 33 项测试的来源。
- W4：设计文档 `docs/agent-collaboration-design.md:164-168` 的五阶段顺序，未发现已证实的依赖错误或循环（W4 丢弃 10 条候选，见其 `RESULT.md`）。
- 协调者另重跑（原始输出见 `evidence/COORDINATOR-EVIDENCE.md` §C）：Collaboration、Workflow、EarlyAck、ValueUndo、StaleCommit 五个原始配置，状态数/退出码与 PR 描述一致。

## 4. 已丢弃：Draft 状态不一致（F3）

- 快照：`pinned/pr.json`（2026-11-12 23:58 +08:00 抓取）`isDraft=false`，与 `pr-body.md:24` 的 "The PR remains **Draft**" 不一致。W1、W2 据此提出。
- 复核（协调者，只读 `gh`）：2026-11-13 约 00:10 +08:00 `isDraft=true`，`updatedAt=2026-11-12T15:58:57Z`；timeline 事件 `convert_to_draft` 发生于 2026-11-12T15:58:57Z（23:58:57 +08:00），账号 BianQue；此前 `ready_for_review` 为 2026-11-12T13:53:36Z。原始输出见 `evidence/COORDINATOR-EVIDENCE.md` §A。
- 结论：该说法现在是对的，F3 不可复现，丢弃。
- 归属：本次审问期间未执行任何 `gh` 写命令（只用了 `pr view`、`api .../timeline`、`git ls-remote`），所以状态变化不是审问造成的。用户于 2026-11-13 16:01 +08:00 确认，23:58:57 的 `convert_to_draft` 由本人操作。R1 已关闭。

## 5. 范围外备注（未核实）

- PR 共 4 条评论（协调者只读 `gh pr view --json comments` 所见）。其中有数字说法（如"最大误差 4.5e-5"、"Node 中每个候选约 0.1 秒"），超出"PR 描述"范围，本次未核实。
- 私人两张照片的预处理实验、NumPy 参考实现的生成器不在仓库内，无法复现。
- 历史 W3 报告使用较新 TLC；所引 TLC 2.19 JAR 未重跑。本次复审未下载或运行 TLC。

## 6. 审问方法与工作目录

- 4 个并行 `codex-run` 会话，各自一份新克隆（文件与目录已去写权限，推送地址设为 `DISABLED_NO_PUSH`）：`/workspace/codex/ws/perler-pr1-w1`…`w4`。四个目录均有 `BRIEF.md`、`RESULT.md`、`probes/`；其中 W1–W3 另有 `scratch/`，W4 无。证据副本在 `evidence/`。
- 协调者重跑 V1–V5 的探针及 5 个原始 TLC 配置；90 个配置的全量执行归属 W3，不是协调者重跑。
- 既有 `/workspace/perler-pr1` 及其他 perler 目录：本次所有克隆都在 `/workspace/codex/ws/` 下新建，未对这些目录执行任何命令。

## 已决

- R1（2026-11-13 16:01 +08:00）：23:58:57 +08:00 的 `convert_to_draft` 由用户本人操作。F3 仍按不可复现丢弃，不恢复为缺陷。

## 已决（续）

- R2（2026-11-13 16:05 +08:00）：按默认执行。S5-c 只澄清措辞，不把 V5 当作必须优化输入读取的承诺，也不在此刻裁定作者原意。
- R3（2026-11-13 16:05 +08:00）：按默认执行。当前不补充评论、私人实验或旧版 TLC 2.19 等材料来扩大可复现范围，也不据此作新发现。

## 待用户审

无。用户已于 2026-11-13 16:05 +08:00 批准其余项按默认建议执行。
