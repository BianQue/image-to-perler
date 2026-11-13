状态：草稿，待用户审阅

Head：bdc9c0adc8f0be4b329bf43b7babdae45693cae7  
Base（main）：ac598aa3102a1a2b54bef680d78cb46baa16ae9b  
Merge base：ac598aa3102a1a2b54bef680d78cb46baa16ae9b

## PR 总表

| id | 阶段 | 目标 | depends on | 规模 |
|---|---|---|---|---|
| S1-a | S1 | 校正范围，固定记录契约 | 已决默认 | S |
| S1-b | S1 | 提取内存会话和普通历史 | S1-a | M |
| S1-c | S1 | 接入局部编辑、笔画和普通撤销重做 | S1-b | M |
| S1-d | S1 | 记录结构、字段及项目替换 | S1-c | M |
| S2-a | S2 | 同坐标补偿与冲突判定 | S1-d、Q8 | M |
| S2-b | S2 | 几何映射恢复及屏障 | S2-a、Q5 | M |
| S2-c | S2 | 隔离预览、拒绝、重新推导后接受 | S2-b、Q4、Q10 | M |
| S3-a | S3 | 持久日志、扫描与重放 | S2-c、Q1、Q9 | M |
| S3-b | S3 | 持久写入权与去重 | S3-a | M |
| S3-c | S3 | 受限服务与客户端 | S3-b、Q9 | M |
| S3-d | S3 | 浏览器待发与持久回执发布 | S3-c | M |
| S3-e | S3 | 恢复对账和标签页接管 | S3-d | M |
| S3-f | S3 | 不删除历史的检查点 | S3-e、Q2 | M |
| S3-g | S3 | 不可变备份和保守恢复 | S3-e、Q3 | M |
| S3-h | S3 | 故障及生命周期验收 | S3-f、S3-g、Q9 | M |
| S4-a | S4 | 分离解码、量化调用和绘制 | S3-h、Q7 | M |
| S4-b | S4 | 候选展示与确认应用 | S4-a | M |
| S4-c | S4 | 固定修订生成三件套 | S4-b | M |
| S4-d | S4 | 可靠落盘与不覆盖重试 | S4-c | M |
| S5-a | S5 | 修复偏弱组最佳项折叠 | S4-d、Q13 | S |
| S5-b | S5 | 修复 note 改变推荐 | S4-d、Q13 | S |
| S5-c | S5 | 澄清原图读取成本 | S4-d | S |
| S5-d | S5 | 更新 Skill 和使用说明 | S5-a、S5-b、S5-c | S |
| S5-e | S5 | 真实图校准预算和评分 | S5-d、Q6、Q7 | M |
| S5-f | S5 | 校准后接入两轮搜索 | S5-e、Q6、Q11 | M |
| S5-g | S5 | 离线、浏览器及下载验收 | S5-f | M |

## 依赖表

blocks 为直接后继；Q 为下文待决项。下一阶段以整个上一阶段验收完成为前提。

| PR id | depends on | blocks | stage |
|---|---|---|---|
| S1-a | 已决默认（原 Q12） | S1-b | S1 |
| S1-b | S1-a | S1-c | S1 |
| S1-c | S1-b | S1-d | S1 |
| S1-d | S1-c | S2-a | S1 |
| S2-a | S1-d、Q8 | S2-b | S2 |
| S2-b | S2-a、Q5 | S2-c | S2 |
| S2-c | S2-b、Q4、Q10 | S3-a | S2 |
| S3-a | S2-c、Q1、Q9 | S3-b | S3 |
| S3-b | S3-a | S3-c | S3 |
| S3-c | S3-b、Q9 | S3-d | S3 |
| S3-d | S3-c | S3-e | S3 |
| S3-e | S3-d | S3-f、S3-g | S3 |
| S3-f | S3-e、Q2 | S3-h | S3 |
| S3-g | S3-e、Q3 | S3-h | S3 |
| S3-h | S3-f、S3-g、Q9 | S4-a | S3 |
| S4-a | S3-h、Q7 | S4-b | S4 |
| S4-b | S4-a | S4-c | S4 |
| S4-c | S4-b | S4-d | S4 |
| S4-d | S4-c | S5-a、S5-b、S5-c | S4 |
| S5-a | S4-d、Q13 | S5-d | S5 |
| S5-b | S4-d、Q13 | S5-d | S5 |
| S5-c | S4-d | S5-d | S5 |
| S5-d | S5-a、S5-b、S5-c | S5-e | S5 |
| S5-e | S5-d、Q6、Q7 | S5-f | S5 |
| S5-f | S5-e、Q6、Q11 | S5-g | S5 |
| S5-g | S5-f | 无 | S5 |

关键路径（依赖链，不估工期）：S1-a…S1-d → S2-a…S2-c → S3-a…S3-e → {S3-f、S3-g} → S3-h → S4-a…S4-d → {S5-a、S5-b、S5-c} → S5-d → S5-e → S5-f → S5-g。Q0–Q13 已按默认建议落定；实现须遵守这些默认，不得静默改强或改弱契约。状态图约束检查通过前，不开始写实现代码。


## 所有 PR 的状态与流程规则（Status and process rules for all PRs）

- 所有 PR 从 draft 开始。用户审阅本计划前不开始实现；未经用户明确同意，不合并、不标为 ready-for-review。本次不改外部 PR、不提交、不推送、不评论、不打标签。
- 每份 PR 描述按运行时代码、测试/夹具、工具/依赖/CI、设计/使用文档、形式模型/配置/证据分类列出实际变更路径，对照 diff；无变化类别写无，防止 V1、V2。S1-a 只准备原 PR 描述草稿，发布另须授权。
- 模型/配置/状态数、测试数、耗时及资源上限必须附重跑命令、环境、SHA、实际范围和退出码；不拿旧证据当本次结果，不累加重叠状态空间，不把见证 exit 12 当正向安全通过，防止 V2 及 V5 式措辞缺口。
- 下文验收是未来预期；“基线命令与输出”节保留原计划编写会话的历史记录，非本次复审新跑结果。命令默认在获准的实现工作树根目录运行。现有 `npm test` 承载各 PR 新增 Vitest 测试；新命令注明创建 PR，后继才引用。复现历史写入型命令须先复制至 scratch/work/，不能在 repo/ 中执行。
- 建议规模按人工维护代码/测试/文档增删行：S ≤150，M 151–450，L 451–800；lockfile/生成物单列。每 PR 一个审查主题，超过 M 在原阶段再拆；这些估算及 26 个 PR 的拆分仍待 Q12 审阅。
- S1/S2 只验本地语义，持久成功/重启恢复留 S3，见 Q10。S4 不接 advisory 搜索；S5-e 校准结论审阅后 S5-f 才接入。不同产品选择先调整计划，不暗中倒置顺序。

已读设计全文、九份指定配套文档及相关代码，复核 ORDER-W4.md 的五项原文：

1. “1. 提取会话与操作记录，保留现有编辑表现。验证局部修改、笔画、普通撤销和重做。”（docs/agent-collaboration-design.md:164）
2. “2. 验证选择性撤销：保留无关人工修改；识别同格冲突、改回原值、制作标记变化和结构变换。”（docs/agent-collaboration-design.md:165）
3. “3. 接入本地服务与客户端并持久保存协作历史。验证两端同步、活动笔画、重复请求、断线响应、错误会话、标签页切换、重启恢复及状态与历史一致性。”（docs/agent-collaboration-design.md:166）
4. “4. 分离候选流程与导出。验证试算不改当前作品，三种交付文件一致、失败不误报完成、重试不覆盖旧版。”（docs/agent-collaboration-design.md:167）
5. “5. 更新 Skill 与使用说明，用真实图片校准两轮搜索和评分，再验收离线构建、浏览器与下载行为。”（docs/agent-collaboration-design.md:168）

基线映射：git diff 确认下列工作台、Python、Skill、README、开发说明、CI 与 pinned main 相同；advisory 只在 head。

| 阶段 | main 已有文件与行为 | 现有测试/检查 | head 新增或仍仅拟议 |
|---|---|---|---|
| S1 | src/core.ts:3 Project v1；src/main.ts:79 草稿、:83 commit、:156 笔画、:235–236 undo/redo；src/view3d.ts:51 三维回调 | tests/core.test.ts 格式/编辑/变换；docs/implementation-review.md 是旧浏览器记录 | 共享会话、opId/作者、版本/依赖及统一记录未实现 |
| S2 | src/core.ts:80 局部操作、:110 rotate/flip、:123 resize；src/main.ts:66 换板、:193 移动 | tests/core.test.ts；head 的 docs/formal/SelectiveUndoSourceCheck.mjs 检查现有操作 | 选择性撤销、补偿、预览接受及任意 crop 未实现；模型不是功能 |
| S3 | src/main.ts:32 全局草稿键；package.json:7 只有 Vite 开发服务；vite.config.ts 单文件构建 | 无服务/故障自动测试；head 的 docs/single-writer-recovery-tests.md 为待执行清单 | 身份/epoch、客户端、日志/journal、恢复、检查点/备份均为提案 |
| S4 | src/main.ts:260 解码后安装、:126 draw 读全局 project、:245 下载；src/core.ts:132 quantize、:157 CSV | tests/core.test.ts 量化/CSV；tests/test_cli.py 只验旧输出 | 候选隔离、同修订三件套、可靠落盘/重试未实现 |
| S5 | SKILL.md、README.md、docs/development.md、.github/workflows/ci.yml；scripts/{cli,core,html}.py 是独立旧格式；scripts/convert-palettes.mjs 生成 src/palettes.ts | tests/core.test.ts、tests/test_core.py、tests/test_cli.py；CI 无浏览器套件 | head 新增 src/advisory/{index,measure,types}.ts、tests/advisory*.ts、tests/advisory-reference.json；未接搜索。两轮搜索、真实图校准及预处理应用未实现 |

以下文件布局、工具选型、PR 切分、验收方法及额外约束，凡原文未明确规定者均为建议，未作为已确认设计；“可能新增”均指本条 PR 创建，后继复用时注明创建者。既有命令须先具备依赖；脚本存在不等于当前能运行。

所有 PR 的“禁止区域”继承以下边界，并在各项补充专属限制：

- G1：不改 Project JSON v1，不把身份/历史塞进通用导出。来源 docs/agent-collaboration-design.md:86,172、docs/development.md:21,29、src/core.ts:3,50。
- G2：离线构建仅 dist/index.html，不强制连服务、不接管 file://。来源 docs/agent-collaboration-design.md:73,118、docs/development.md:5、.github/workflows/ci.yml:25–26。
- G3：不改 quantize 的 RGB 距离、高频选色、alpha 阈值；不改 Python 旧格式、品牌数据、示例产物。来源 docs/agent-collaboration-design.md:144,172、docs/development.md:27,33、SKILL.md:34。预处理张力见 Q7。
- G4：S5 校准前不把 src/advisory/ 接入搜索，不将临时阈值当客观精度。来源 docs/agent-collaboration-design.md:81,168,188；仅 S5-f 在 S5-e 完成后解除接线禁令。
- G5：不做云端多人、账户/计费、纯网页聊天适配、自动接管离线页；不绑定生图供应商、不擅自外发。来源 docs/agent-collaboration-design.md:17,75,154,156,158。
- G6：实现 PR 不改 docs/formal/*.tla、*.cfg、旧 evidence/ 来迎合实现，模型不证明应用。来源 docs/formal/README.md:3,139,261、docs/single-writer-recovery-tests.md:49。若确需模型变更，单独说明契约变化和重跑配置并重新审阅计划。源码检查抽取原换板 handler（docs/formal/README.md:363），S1 保留可检查形状，不删除检查掩盖回归。

## S1-a：范围与记录契约

- 目标：维护者能按真实分支范围审阅最小会话记录契约。
- 精确范围与可能文件：可能修改现有 docs/agent-collaboration-design.md 的现状/模型表述，可能新增 docs/operation-record-contract.md，列出全部 Project 修改入口和必要字段；可能修订工作区现有 ./pr-body.md 本地描述草稿（非仓库路径，不发布）。原模型数字只限定于原模型或改为链接，不概括全部模型。
- 依赖：已决默认（原 Q12：保留 26 个 PR 切分；超 M 时在同阶段再拆）；“合并本文仅记录设计，不启用功能或承诺发布时间。”（docs/agent-collaboration-design.md:19）；“所有改变 Project 的入口都必须产生记录，或产生显式“不支持自动恢复”的屏障。”（docs/selective-undo-after-transform.md:135）。实现基线按 Q0 已决：以 pinned head 的说明、设计文档、形式模型、advisory 源码与测试的整体为真实设计草稿，不以“documentation-only”单独划界，也不把代码从设计中拆出。
- 验收：`git diff --name-status ac598aa3102a1a2b54bef680d78cb46baa16ae9b bdc9c0adc8f0be4b329bf43b7babdae45693cae7 -- src tests` 应列出 advisory 源码/测试新增，描述逐类覆盖；`rg --files docs/formal -g '*.tla' -g '*.cfg'` 与索引逐项一致。审阅者按 src/main.ts 每个 Project 写入口核对记录表，不引用无重跑命令的计数。
- 禁止区域：G1–G6；不改运行时、不发布描述、不把已撤销的 draft 状态发现重新列为缺陷。
- Findings：拟解决 V1、V2 的文档/描述错报；原 PR 描述实际更新仍待授权。V3–V5 不修复。
- 规模与审查重点：S（80–150 行）；检查已有能力、拟议能力和模型证据是否分开。

## S1-b：共享内存会话

- 目标：编辑状态与普通历史可脱离 DOM 验证，并保留原有撤销表现。
- 精确范围与可能文件：可能新增 src/session/operations.ts、src/session/session.ts、src/session/history.ts、tests/session.test.ts；可能修改现有 src/main.ts:9,20,83 状态引用。元数据包裹 Project，记录配对前后像；普通 undo/redo 产生新记录/版本，50 份快照上限与协作日志分开。
- 依赖：S1-a；“普通撤销、重做和补偿操作必须共用记录模型。”（docs/agent-collaboration-design.md:138）。
- 验收：`npm run typecheck`、`npm test` 预期 exit 0；新增测试验证无变化不增历史、undo/redo 恢复完整 Project、新编辑清 redo、版本不倒退、快照不共享可变数组；现有 tests/core.test.ts 格式/编辑断言不变。
- 禁止区域：G1–G6；不实现服务/选择性撤销/持久成功提示；不把 50 项普通栈限制套到协作历史（src/main.ts:86、docs/agent-collaboration-design.md:86）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–400 行）；检查旧快照恢复与新版本记录能否同时成立。

## S1-c：局部编辑与笔画

- 目标：二维、三维及键盘的每次编辑意图只形成一个普通撤销步骤。
- 精确范围与可能文件：可能修改现有 src/main.ts 的 apply/finishStroke、选区填充/删除/移动、去孤点、undo/redo 和三维回调，可能修改 src/view3d.ts 接线；扩充 S1-b 会话与 tests/session.test.ts，可能新增 tests/strokes.test.ts。预览与提交分开，移动保存源/目标完整效果。
- 依赖：S1-b；“连续笔画最终作为一次提交”（docs/agent-collaboration-design.md:97）；“后续实现必须把撤销、重做、人工修改和 Agent 修改都收进同一队列。”（docs/single-writer-recovery.md:28）。
- 验收：`npm test`、`npm run typecheck`、`npm run build` 预期 exit 0。用 `npm run dev` 分别操作二维/三维笔画、Shift 线、选区移动、重复扫制作标记、pointercancel、失去捕获及空格键；每次意图一步 undo/redo，纯选区/平移/吸色不记数据历史，2D/3D/用量一致。
- 禁止区域：G1–G6；不改变工具语义，不因预览提前写正式历史（docs/agent-collaboration-design.md:128,130）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–450 行）；检查所有笔画结束路径是否仅提交一次。

## S1-d：结构与字段完整记录

- 目标：任何作品变更都留下可判定恢复边界的记录。
- 精确范围与可能文件：可能修改现有 src/main.ts 换板、rotate/flip、resize、新建/导入/打开/草稿恢复、name/boardSize；扩充 src/session/operations.ts（S1-b 创建），可能新增 tests/operation-records.test.ts。记录坐标映射、尺寸、项目/色板 epoch、完整色号映射、删除前像、字段版本及不支持屏障；保持换板源码检查入口。
- 依赖：S1-c；“恢复旧值不恢复旧版本”（docs/selective-undo-after-transform.md:145）；“不能把旧格坐标默认为新项目身份”（同文件 :55）。
- 验收：`npm test`、`npm run typecheck`、`node docs/formal/SelectiveUndoSourceCheck.mjs` 预期 exit 0。按 S1-a 表逐入口操作，均须有记录；字段修改不误增坐标变换，打开同名 JSON 不继承协作身份；普通 undo/redo 可恢复结构及字段值，版本递增。
- 禁止区域：G1–G6；不增加任意 crop；不自动选择性撤销结构/移动/字段目标（docs/selective-undo-after-transform.md:74–78）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–400 行）；检查是否遗漏 Project 写入口。


## S2-a：同坐标局部补偿

- 目标：撤销指定 Agent 局部修改时保留后来无关的人工效果。
- 精确范围与可能文件：可能新增 src/session/selective-undo.ts、tests/selective-undo.test.ts、tests/selective-undo-reference.ts，扩充 S1-b 的 history.ts。以具体效果而非重执行旧条件命令为契约，配对恢复 colorId/completed；按版本判同格/ABA 冲突，记录 success/partial/conflict、inverseOf 及未解决集合。
- 依赖：S1-d、Q8；“本模型验证的是保留后续**已提交的具体效果**。”（docs/selective-undo-after-transform.md:25）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0；新增用例覆盖无关人工编辑保留、同格/ABA/done 冲突、空格不能 completed、安全集之外完全不变；与独立具体效果重放器比较，包含 fill/replace 旧条件重算反例，不以被测补偿算法当参考。
- 禁止区域：G1–G6；暂不跨结构自动补偿、不声称磁盘成功，不只按颜色相等恢复（docs/agent-collaboration-design.md:136）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–450 行）；检查颜色与完成标记是否作为一个版本单元。

## S2-b：映射与屏障

- 目标：旋转、翻转和现有缩小画布后仍能恢复安全格并报告丢失格。
- 精确范围与可能文件：可能新增 src/session/coordinate-map.ts、tests/undo-transforms.test.ts，扩充 S2-a 引擎及参考重放器。覆盖非方图 rotate/flip 链和现有 resize 右/下裁除的部分映射，设置色板/项目屏障；扩大尺寸若未证安全则明确冲突。
- 依赖：S2-a、Q5；“首版色板 epoch 是保守屏障，不论该次映射碰巧是否单射”（docs/selective-undo-after-transform.md:71）；“源码没有任意矩形裁剪工具。”（同文件 :59）。
- 验收：`npm test`、`node docs/formal/SelectiveUndoSourceCheck.mjs` 预期 exit 0；固定 seed 的多尺寸、长变换链与稳定格子身份参考比较，安全格不漏恢复、删除区逐项 conflict、其他格不变；换板、项目替换、结构/移动/字段目标不得自动恢复；partial 不能显示全部撤销。
- 禁止区域：G1–G6；不把删右列模型当任意 crop 实现，不猜色板逆、不自动扩大画布找回删除区（docs/selective-undo-after-transform.md:70,74–78,180）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–400 行）；检查映射定义域与删除格冲突是否完整。

## S2-c：预览、拒绝与接受

- 目标：用户可检查恢复方案，接受时不会把旧补偿覆盖到新的人工编辑上。
- 精确范围与可能文件：可能新增 src/session/undo-preview.ts、tests/undo-preview.test.ts，修改现有 src/main.ts、src/style.css 及 S2-a 引擎。覆盖层保存目标/前缀；拒绝只删覆盖层；接受在会话队列内重新推导；区分成功/部分/全部冲突。覆盖部分重试、撤补偿/重做、目标交叠；未支持项明确阻断，不能误标整笔完成。
- 依赖：S2-b、Q4、Q10；“预览和拒绝都不改日志和图纸。”（docs/preview-accept.md:34）；“成功响应还必须满足待解问题 1 的持久化确认协议”（docs/selective-undo-after-transform.md:95）。
- 验收：`npm test`、`npm run typecheck`、`npm run build` 预期 exit 0。观察预览/拒绝前后 Project 与记录摘要相同；预览后插入旋转、同格编辑、ABA、换板再接受，必须重新计算位置/冲突；全部冲突不追加记录；补偿可普通撤销/重做。S2 只显示本地语义结果，持久成功交 S3-d/S3-h。
- 禁止区域：G1–G6；旧预览不是写授权，不能自动覆盖人工后改格；过期预览不自动归为日志分叉硬停止（docs/preview-accept.md:13,22–24,32）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–450 行）；检查接受是否重推导而非复用旧写集。

## S3-a：日志与重放

- 目标：作品、历史和操作身份能从同一持久真源恢复。
- 精确范围与可能文件：可能新增 service/journal.ts、service/replay.ts、tests/journal.test.ts、docs/local-service.md，修改现有 package.json、package-lock.json、tsconfig.json 以检查服务代码。按 Q9 选存储；默认提案为长度/校验/身份/修订记录、短写循环、sync 后回执、完整性扫描及单服务实例排他访问。
- 依赖：S2-c、Q1、Q9；“操作日志是恢复真源。快照是可重建的加速缓存”（docs/single-writer-recovery.md:43）；“完成写入后调用 `FileHandle.sync()`，成功后才回执。”（同文件 :130）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0，类型检查包含 service；临时目录测试重放等于 Project/历史/版本摘要，短写、EIO、ENOSPC 不回成功；中间损坏和已确认记录缺失阻断，仅按可证明边界处理未确认无效尾部；第二实例拒绝同时写入。
- 禁止区域：G1–G6；不以分别写 Project/历史代替事务，不压缩/自动删历史，不把 SIGKILL 称为断电验收（docs/single-writer-recovery.md:128–146、docs/single-writer-recovery-tests.md:9）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（300–450 行）；检查成功回执是否对应完整可重放记录。

## S3-b：写入权与幂等

- 目标：重复操作只生效一次，交接后的旧标签页不能写新修改。
- 精确范围与可能文件：可能新增 service/authority.ts、service/project-queue.ts、src/session/protocol.ts、tests/authority.test.ts，扩充 service/journal.ts（S3-a 创建）。持久 epoch/holder/acquireRequestId；授予与写盘共用项目队列；身份先验、已知 opId 原结果查询、负载摘要绑定、未知操作严格基础前缀校验。
- 依赖：S3-a；“写入权的世代号 `epoch` 必须先持久保存，再发给浏览器。”（docs/single-writer-recovery.md:15）；“相同 ID 携带不同负载时返回 `OP_ID_REUSE`。”（同文件 :58）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0；覆盖 F8–F11：重复 ID 在后续修改之后仍回原结果，异负载拒绝；暂停旧提交写盘时接管，不能先授新 epoch 再写旧提交；重启 epoch 不回退，旧世代已知 ID 只返只读回执。
- 禁止区域：G1–G6；不按连接先后选写者、不靠租约时钟证明正确、不在服务重新计算编辑语义（docs/single-writer-recovery.md:9,18,79）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–400 行）；检查 Grant/Flush 竞态是否受同一队列约束。

## S3-c：服务与客户端

- 目标：Agent 可明确定位会话并发送受限作品命令。
- 精确范围与可能文件：可能新增 service/server.ts、scripts/collaboration-client.mjs、tests/service-api.test.ts，修改 S3-a 的 docs/local-service.md 和现有 package.json、package-lock.json。HTTP 客户端、浏览器持久连接转发、会话创建/查询；新协作项目未指定色板用 Artkal C，打开已有项目沿用原色板（docs/agent-collaboration-design.md:78），不改离线默认值；服务仅验证/持久化/转发，无工作台时明确不可提交。
- 依赖：S3-b、Q9；“本地命令行客户端通过 HTTP 请求服务。服务通过持久连接向工作台转发命令。”（docs/agent-collaboration-design.md:112）；“本地服务仅监听回环地址”（同文件 :158）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0；API 测试实际起临时服务，检查回环、凭据、Origin/Host、请求大小、结构校验、错误项目/会话、路径穿越和符号链接逃逸拒绝；没有工作台不能伪报成功。审阅者按本 PR 技术文档启动后可观察明确会话及连接状态。
- 禁止区域：G1–G6；无任意代码执行/任意文件写入，不把 Vite 当协作服务，不把凭据放入导出 HTML 或公开日志（docs/agent-collaboration-design.md:101,158,160）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（300–450 行）；检查接口是否限于结构化项目动作。

## S3-d：浏览器待发与发布

- 目标：工作台与 Agent 仅在持久回执后将修改显示为已保存。
- 精确范围与可能文件：可能新增 src/collaboration/client.ts、src/collaboration/pending.ts、tests/pending.test.ts、tests/browser/session.pw.ts、playwright.config.ts，修改 src/main.ts、会话队列、package.json、package-lock.json。本 PR 创建 `npm run test:browser`，Playwright 仅匹配 .pw.ts，与现有 Vitest 分开；IndexedDB 保存不可变请求，匹配 ack 才发布/清理。
- 依赖：S3-c；“首版每个项目只允许一个未确认的提交。”（docs/single-writer-recovery.md:11）；“人工提交也经过同一队列”（docs/agent-collaboration-design.md:130）。
- 验收：现有 `npm test`、`npm run typecheck`、`npm run build` 预期 exit 0；实际双端观察：二维/三维笔画和拖选区期间命令等待，结束后重检读集/结构；无关人工修改可兼容，fill 邻接依赖变动需重计划；sync 未完成仅有预览/等待保存；浏览器待发 journal 失败不发送、服务 journal 失败不回成功，ack 后双方修订与普通历史一致。本 PR 新增的浏览器测试按本 PR 说明实际执行并通过。
- 禁止区域：G1–G6；send/入队/缓冲区清零不是保存，浏览器 journal 不是服务成功，普通 undo/redo 不绕队列（docs/single-writer-recovery.md:45,64–70）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（300–450 行，lockfile 另列）；检查 UI 发布与 Agent 成功是否都晚于 ack。

## S3-e：恢复与标签页

- 目标：重连或重启后核对作品和历史，并拒绝旧页面迟到写入。
- 精确范围与可能文件：可能新增 src/collaboration/recovery.ts、tests/recovery.test.ts、tests/browser/recovery.pw.ts，修改 S3-d 客户端、src/main.ts 及服务。统一 reload/bfcache/重连/恢复路径及请求代次；覆盖服务领先、可信待发尾部、同修订异摘要、分叉、原记录缺失；提供显式页面选择/接管。
- 依赖：S3-d；“重新连接时必须核对状态和历史一致性”（docs/agent-collaboration-design.md:140）；“迟到的旧恢复响应不得让新页面回退。”（docs/single-writer-recovery.md:81）。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建）预期 exit 0；F2/F6/F7/F11–F14 中原 ID/负载不变且最多追加一次；同名异身份拒绝、分叉保留待发并 blocked；A 冻结、B 接管、A 唤醒后旧写拒绝；实际 `pageshow.persisted === true` 才算 bfcache，握手前禁止正式提交。
- 禁止区域：G1–G6；不自动取较大修订、不从页面终值捏造历史、不靠 unload/close 最后保存（docs/single-writer-recovery.md:89–90,120–124）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（300–450 行）；检查拒绝路径是否保留未确认负载。

## S3-f：检查点

- 目标：可用持久检查点加日志后缀恢复，而不牺牲旧历史。
- 精确范围与可能文件：可能新增 service/checkpoint.ts、tests/checkpoint.test.ts，修改 service/replay.ts、docs/local-service.md（均由 S3-a 创建）。临时写、文件 sync、同目录 rename、父目录 sync 和身份/修订/摘要校验；完整日志仍保留，压缩/自动清理不在默认提案内。
- 依赖：S3-e、Q2；“检查点本身不删历史。”（docs/log-backup.md:11）；“快照发布前不能删除仍用于恢复的日志。”（docs/single-writer-recovery.md:134）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0；临时写/sync/rename/目录 sync 各阶段失败，旧恢复路径有效且日志不删；检查点加后缀与完整日志重放一致。真实断电 F16 留 S3-h，单元模拟不能替代。
- 禁止区域：G1–G6；不实现 Compact、不把模型保守记账当产品保留默认值（docs/log-backup.md:89）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（180–300 行）；检查发布失败后原日志恢复仍可用。

## S3-g：备份与恢复判定

- 目标：历史备份可核对，旧或分叉备份不会静默覆盖现场作品。
- 精确范围与可能文件：可能新增 service/backup.ts、tests/backup.test.ts，修改 S3-c 的 scripts/collaboration-client.mjs、S3-d 的 src/collaboration/client.ts 及 docs/local-service.md（S3-a 创建）。固定身份和可恢复镜像，另存不可变备份；匹配前缀返回已包含；错身份、分叉和额外后缀拒绝并保留 journal；整份替换等待 Q3。
- 依赖：S3-e、Q3；“备份是一份不可变快照”（docs/log-backup.md:21）；“本模型也不自动快进”（同文件 :22）。
- 验收：`npm test`、`npm run typecheck` 预期 exit 0；备份后现场追加，再导入旧备份，现场不回退；同修订异摘要、异身份、分叉和较长备份拒绝，epoch/日志/待发不变；备份不随后来编辑变化。检查点加后缀备份组合由 S3-h 验证。
- 禁止区域：G1–G6；Project JSON 不是历史备份，不自动合并/快进，不默认开放 ExplicitReplace（docs/log-backup.md:22–25,91）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（200–350 行）；检查拒绝恢复是否没有写副作用。

## S3-h：故障与跨重启验收

- 目标：对声明支持的平台提供作品、历史和已确认操作一致的故障证据。
- 精确范围与可能文件：可能新增 tests/recovery-faults.test.ts、tests/browser/lifecycle.pw.ts、docs/recovery-acceptance.md，补充 S3-a–S3-e 的服务/客户端阻断点与现有 .github/workflows/ci.yml。复用前述测试，补齐 docs/single-writer-recovery-tests.md:15–30 的 F1–F16、:34–41,43 浏览器清单及检查点/备份组合；:42 先核对 Project、2D、3D、历史和用量，导出快照修订部分留 S4-c 接入、S5-g 最终恢复回归，避免依赖后续 S4，不另造协议。
- 依赖：S3-f、S3-g、Q9；“普通 page.close、reload 和模拟离线不能替代进程崩溃。”（docs/single-writer-recovery-tests.md:9）；“只有独立存储故障测试完成后，才能把模型的原子磁盘假设升级成所选平台的实现保证。”（同文件 :49）。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建）预期 exit 0；逐 F 编号记录故障点/opId/日志/最终摘要，真实终止渲染及服务进程，覆盖重复崩溃、ack 丢失、迟到消息、配额不足、驱逐、sync 错误。实际冻结/丢弃/bfcache 与 Chromium/Firefox/WebKit 重载/双页分别记录；独立故障文件系统或虚拟机断电验 F16，未执行的平台不得通过支持门槛。重启后撤旧 Agent 操作，核对 Project、2D、3D、历史、用量。
- 禁止区域：G1–G6；不以模型通过、render 次数或重连成功代替对账，不扩产品功能（docs/single-writer-recovery-tests.md:42,47）。
- Findings：防止重现 V1、V2 及 V5 式范围/成本措辞缺口；不修 advisory。
- 规模与审查重点：M（250–450 行，运行证据另列）；检查故障真实发生且禁止副作用被断言。


## S4-a：解码与渲染分离

- 目标：转换和预览渲染可在不安装当前作品的情况下调用。
- 精确范围与可能文件：可能从现有 src/main.ts:126,260 提取 src/images/decode.ts、src/render/pattern.ts，新增 tests/candidate-generation.test.ts、tests/browser/images.pw.ts；复用 src/core.ts 的 quantize/validateProject。绘制接收显式 Project 和选项，隔离过滤/选区/光标。
- 依赖：S3-h、Q7；“图像解码、预览渲染从“安装当前项目”中分离。”（docs/agent-collaboration-design.md:144）；现有算法见 docs/development.md:27。
- 验收：`npm test`、`npm run typecheck`、`npm run test:browser`（S3-d 创建）预期 exit 0；相同输入与既有 quantize 结果一致，透明/白色及 1–256 尺寸约束保留；生成成功/取消/失败均不改当前 Project、修订、草稿、历史，绘制不读取当前选区。
- 禁止区域：G1–G6；不实现预处理研究的 Lanczos/OKLab/k-medoids，不借提取改变量化结果（docs/image-preprocess-research.md:22–25,55）。
- Findings：防止重现 V1、V2；维持 V3–V5 隔离，不接筛选器。
- 规模与审查重点：M（200–350 行）；检查候选路径是否间接调用 install/commit。

## S4-b：候选展示与应用

- 目标：用户可比较候选，明确确认后才替换当前作品。
- 精确范围与可能文件：可能新增 src/candidates/store.ts、src/candidates/view.ts、tests/candidates.test.ts、tests/browser/candidates.pw.ts，修改 src/main.ts、src/style.css 和客户端结构化命令。独立存候选身份、底稿/色板/参数、Project；显示尺寸/实际色数/豆数，暂由调用方提供候选组，无自动搜索或筛选推荐。
- 依赖：S4-a；“会话建立后即打开工作台”（docs/agent-collaboration-design.md:120）；“一次修改意图对应一个普通撤销步骤。”（同文件 :83）。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建） 预期 exit 0；已有项目编辑时生成/切换/拒绝候选，Project/历史不变；确认后重检当前上下文并作为单一结构事务，undo 一步恢复旧作品；并发新编辑不能被旧确认覆盖。新图入口建会话即显示工作台，旧离线作品走保存再打开，均能展示候选。
- 禁止区域：G1–G6；不新增自动语义评分、不把配置色数当实际色数、不跨底稿/色板排序（docs/agent-collaboration-design.md:79–83）。
- Findings：防止重现 V1、V2；不得提前放大 V3、V4 的用户可见影响。
- 规模与审查重点：M（250–450 行）；检查确认绑定的候选及当前项目身份。

## S4-c：快照三件套

- 目标：JSON、PNG、CSV 表达同一份已提交修订。
- 精确范围与可能文件：可能新增 src/delivery/snapshot.ts、tests/delivery-snapshot.test.ts、tests/browser/delivery.pw.ts，修改 src/main.ts 导出入口及 S4-a 渲染模块。固定不可变 Project、revision、摘要和绘制选项；复用 serializeProject/exportCsv，PNG 同源；本 PR 只生成内容和校验信息，不写用户目录。
- 依赖：S4-b；“交付回执标明快照修订，不能暗示包含导出期间的新编辑。”（docs/agent-collaboration-design.md:146）。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建） 预期 exit 0；阻断 PNG 编码时继续编辑，JSON 解析值、CSV 总量及 PNG 指定格像素均对应原修订；重启恢复后再生成三件套，核对 docs/single-writer-recovery-tests.md:42 的导出快照修订；空图/透明/completed/尺寸正确；toBlob 空结果或编码失败不能产生成功交付状态。
- 禁止区域：G1–G6；不读生成期间的新 project，不将下载发起视为落盘，不强制 HTML/打印交付（docs/agent-collaboration-design.md:87,100,146）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（180–320 行）；检查三种内容是否真正共用冻结快照。

## S4-d：落盘与重试

- 目标：全部文件写入成功才报告完成，失败重试保留旧交付。
- 精确范围与可能文件：可能新增 service/delivery.ts、tests/delivery-files.test.ts，修改服务/客户端、S4-c 接线、docs/local-service.md（S3-a 创建）。限定用户输出根目录、排他新版本名称、deliveryId/快照/文件摘要；回执列路径、修订、校验及已写/失败项；重试复用原内容并核对已有文件，不重算作品。
- 依赖：S4-c；“文件另存新版本，全部成功后返回路径、修订和校验信息。文件写入失败时列出已写文件，并支持安全重试。”（docs/agent-collaboration-design.md:148）。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建） 预期 exit 0；三种文件各写入点分别注入失败、磁盘满、重启、丢回执，未全成功不报完成；重试旧版校验值不变、同 deliveryId 不换快照，同名异内容拒绝覆盖；路径穿越、符号链接逃逸、非指定目录拒绝；实读 JSON/PNG/CSV 核对一致。
- 禁止区域：G1–G6；不借用 Python generate 的失败删整目录策略，不写任意路径，不覆盖旧版（scripts/core.py 的 generate；docs/agent-collaboration-design.md:148,158）。
- Findings：防止重现 V1、V2；其余 none。
- 规模与审查重点：M（250–450 行）；检查不确定结果的重试是否仍绑定原快照。

## S5-a：V3 偏弱组显示

- 目标：全组偏弱且最佳项带 broken 时，最佳项仍展开但不推荐。
- 精确范围与可能文件：可能修改现有 src/advisory/index.ts:66,86、tests/advisory.test.ts，必要时澄清 src/advisory/types.ts:60；weak 最佳项 shown 优先于 broken 折叠，补 broken 单候选/全 broken/并列最佳回归。
- 依赖：S4-d、Q13；“weak: no candidate is clean. Nothing is recommended and the best one is still shown.”（src/advisory/types.ts:60）；V3 为已核实输入发现。
- 验收：`npm test -- tests/advisory.test.ts tests/advisory-parity.test.ts`、`npm run typecheck` 预期 exit 0；broken-only 组 recommendedId 为 null，现有排序的最佳项为 shown，所有候选仍可访问；有 clean 组保持原折叠规则。
- 禁止区域：G1–G6；不改度量轴、阈值、量化、搜索接线或参考数值夹具。
- Findings：拟解决 V3；防止重现 V1、V2，不顺带修 V4/V5。
- 规模与审查重点：S（30–80 行）；检查 broken-only 反例是否成为回归测试。

## S5-b：V4 note 不影响状态

- 目标：仅增加 note 提示不会改变推荐或折叠状态。
- 精确范围与可能文件：可能修改现有 src/advisory/index.ts:82、tests/advisory.test.ts；去掉 flags.length 推荐决胜条件，保留豆数、结构分及明确稳定并列规则；增加同豆数竞争候选仅 note 不同的对照。
- 依赖：S4-d、Q13；“note: shown to the user, no effect on state.”（src/advisory/types.ts:27）。
- 验收：`npm test -- tests/advisory.test.ts tests/advisory-parity.test.ts`、`npm run typecheck` 预期 exit 0；固定度量/豆数时 note 增删不改 recommendedId/states，warn 仍阻止推荐，提示文字仍显示。
- 禁止区域：G1–G6；不将 note 契约改成惩罚项来迎合现状，不改分数或参考夹具（src/advisory/types.ts:27,47）。
- Findings：拟解决 V4；防止重现 V1、V2，不顺带修 V3/V5。
- 规模与审查重点：S（30–100 行）；检查测试包含竞争候选而非单候选自测。

## S5-c：V5 成本措辞

- 目标：说明准确区分 256 px 度量画布和每候选完整原图读取成本。
- 精确范围与可能文件：可能仅修改现有 src/advisory/types.ts:10、src/advisory/index.ts、src/advisory/measure.ts:88 注释，新增 docs/advisory-cost.md；说明全图线性化和内存随源图增长、每候选重复执行。暂不做缓存/降采样优化，成本实测留 S5-e。
- 依赖：S4-d；“The evaluator never reads more than a 256 px canvas.”（src/advisory/types.ts:10）若被理解为输入读取上限，则与全图循环（src/advisory/measure.ts:91–95）、每候选调用（src/advisory/index.ts:74）不一致；若指度量画布上限则与代码一致，沿用 INTERROGATION.md V5 的低严重度措辞歧义，不升级为确定的性能缺陷。
- 验收：审阅 diff 只有注释/文档；逐行对照 baseCanvas 原图循环和 screen 的 candidates.map，文字不得声称只读 256 px 或成本与原图无关；`npm test -- tests/advisory-parity.test.ts` 预期原参考误差断言不变。
- 禁止区域：G1–G6；不改运行行为，不把输入报告的源字节计数当本 PR 新测量，不捏造耗时上限。
- Findings：拟解决 V5 的措辞歧义；是否优化由 S5-e 实测决定；防止重现 V1、V2。
- 规模与审查重点：S（20–60 行）；检查度量尺寸是否被误称原图读取上限。

## S5-d：Skill 与使用说明

- 目标：Agent 和用户可按真实已实现能力完成两个入口、确认、恢复和交付。
- 精确范围与可能文件：可能修改现有 SKILL.md、README.md、README_EN.md、docs/development.md，链接 S3 技术说明。包含已有项目保存再打开、新图启动即展示、既有色板沿用/新项目 Artkal C、确认权、持久保存/下载区别、默认三件套、JSON 无历史、恢复限制、每次外发授权；搜索明确待 S5-e/f 验收。
- 依赖：S5-a、S5-b、S5-c；“Skill 提供制作方法和工具使用说明”（docs/agent-collaboration-design.md:75）；“已有项目沿用色板，新项目未指定时采用 Artkal C。”（同文件 :78）。
- 验收：审阅者按文档各走一次旧项目和新图入口，直到确认、编辑、重启恢复、三件套交付；所有命令由此前 PR 提供并能找到帮助/错误说明；拒绝外发后仍能本地处理；未接入搜索不能写成可用功能。
- 禁止区域：G1–G6；不改 Python 默认参数、不称 boards.json 兼容 Project v1、不承诺协作数据绝不离开本机（SKILL.md:21,34、docs/agent-collaboration-design.md:154）。
- Findings：防止重现 V1、V2、V5 的范围/成本夸大；承接 V3/V4 修复契约。
- 规模与审查重点：S（100–150 行）；检查“完成/保存/恢复”与回执语义是否一致。

## S5-e：真实图片校准

- 目标：维护者能依据可复现案例决定候选预算和建议阈值是否可接受。
- 精确范围与可能文件：可能新增 scripts/calibrate-advisory.mjs、docs/calibration.md、tests/calibration-cases.json，可能修改现有 tests/advisory-fixtures.ts、advisory 阈值及行为测试；不接生产搜索。使用获准真实图片、独立验证样本，记录输入哈希/权限、候选、screen 分/警告、40/30/30 人工评审与必留特征、环境/耗时/内存及失败案例。离线测量候选，不冒充搜索接线。
- 依赖：S5-d、Q6、Q7；“80 分和筛选器阈值都是临时值”（docs/agent-collaboration-design.md:81）；“初筛必须运行但不做决定。80 分不验证真实效果，只作入围复看的临时门槛。”（同文件 :188）。
- 验收：审阅者按本 PR 新增脚本的记录命令/输入复测，应得到相同确定性度量和候选清单；独立样本与校准集分开，记录不达标/人工分歧、候选计算与最后 1–3 个复看的成本，含大原图/多候选。`npm test -- tests/advisory.test.ts tests/advisory-parity.test.ts` 预期 exit 0；度量轴不变则不重写 numpy 参考。仅程序图测试不能通过真实图门槛。
- 禁止区域：G1–G6；不公开私人研究照片、不自动生图、不称 80 为客观精度、不接搜索；授权素材不足则保持待验收（docs/image-preprocess-research.md:13,52–55、docs/agent-collaboration-design.md:75,81）。
- Findings：验证 V3/V4 不回退，以实测补足 V5 成本说明，防止重现 V1、V2。
- 规模与审查重点：M（200–400 行，素材/测量产物单列）；检查样本独立性及预算依据。

## S5-f：两轮搜索接入

- 目标：自动比较在预算内给出可解释建议，同时保留用户选择权。
- 精确范围与可能文件：可能新增 src/candidates/search.ts、tests/search.test.ts，修改 S4 界面、客户端、SKILL.md、校准说明。按 Q6 粗选再细化，守用户尺寸/色板/特征/色数约束及 256 格上限；每候选 screen，两轮合并排序，折叠仍可选、全弱不推荐；Agent 只复看最后 1–3 个，先最小已评审达标尺寸再减色；沿用 S3-c 的新项目 Artkal C 规则，不改离线默认色板。
- 依赖：S5-e 校准结论经用户审阅、Q6、Q11；“未指定尺寸时最多两轮比较”（docs/agent-collaboration-design.md:80）；“筛选器也尚未接入搜索流程”（同文件 :81）是本 PR 才改变的现状。
- 验收：`npm test`、`npm run test:browser`（S3-d 创建） 预期 exit 0；显式尺寸/色数、两轮耗尽、全弱/全 broken、note 对照、关键特征丢失逐例验证：不能自动第三轮或自动应用；两轮合并与同全集一次 screen 结果一致；不达标给原因并等待新授权。显示实际豆数/色数及临时标记，分开 screen 建议与最终 Agent 推荐。
- 禁止区域：G1–G3、G5–G6；G4 仅在 S5-e 后解除接线禁令，临时/建议性质不变；不称全局最优、不做瞳孔等局部识别、不固定自动 24 色（docs/agent-collaboration-design.md:79–82）。
- Findings：不得重现 V3、V4；资源说明承接 V5；防止重现 V1、V2。
- 规模与审查重点：M（250–450 行）；检查预算/警告/分数是否越权替用户决定。

## S5-g：最终离线与下载验收

- 目标：协作功能加入后，独立离线工作台和真实下载仍可用且内容正确。
- 精确范围与可能文件：可能新增 tests/browser/offline.pw.ts、docs/collaboration-acceptance.md，修改 .github/workflows/ci.yml、docs/development.md；回归只在对应边界小修并重跑相关检查，维持 Python CI，不覆盖旧验收记录。
- 依赖：S5-f；“构建成功不等于通过 file://、断网、WebGL 或下载验收。”（docs/development.md:5）；单文件 CI 见 .github/workflows/ci.yml:25–26。
- 验收：`npm run typecheck`、`npm test`、`npm run build`、`npm run test:browser`（S3-d 创建）预期 exit 0；按现有 .github/workflows/ci.yml:25–26 的单文件检查核对构建目录，预期仅 dist/index.html（由本条前述 `npm run build` 生成）。`python3 -m unittest discover -s tests -v` 保持旧工具行为。实际 file:// 且断网打开最终构建/导出 HTML，验证 2D/3D、undo/redo、标记、换板、保存重开、含 </script> 名称往返、下载 JSON/PNG/CSV、恢复后导出快照修订一致性（补齐 docs/single-writer-recovery-tests.md:42）、许可、WebGL 不可用提示、键盘和窄屏；离线页不自动连服务。
- 禁止区域：G1–G3、G5–G6 和 G4 的临时评分限制；不把 HTTP 打开当 file://、不把一种浏览器覆盖外推全部、不发布/打标签（SKILL.md:13,17、docs/development.md:39）。
- Findings：防止重现 V1–V5；记录实际检查范围，不把计划当通过报告。
- 规模与审查重点：M（200–400 行）；检查是否使用最终单文件和真实下载产物。


## 基线命令与输出（原计划编写会话记录）

以下为原稿保留的执行记录（另见 PLAN-session-RESULT.md:3）；本次复审只重查只读 Git/源码/元数据，未重跑下面的复制、测试或构建。

- `git -C repo rev-parse HEAD` → bdc9c0adc8f0be4b329bf43b7babdae45693cae7；`git -C repo merge-base HEAD ac598aa3102a1a2b54bef680d78cb46baa16ae9b` → pinned merge base。`git -C repo status --short` 无输出。
- `git -C repo diff --exit-code ac598aa3102a1a2b54bef680d78cb46baa16ae9b HEAD -- src/core.ts src/main.ts src/view3d.ts scripts tests/core.test.ts SKILL.md README.md docs/development.md .github/workflows/ci.yml package.json` → exit 0，无差异。`git -C repo diff --name-status ac598aa3102a1a2b54bef680d78cb46baa16ae9b HEAD -- src tests` 只列 advisory 源码和对应测试/夹具新增。
- `nl -ba repo/docs/agent-collaboration-design.md` → 完整阅读，:164–168 与 ORDER-W4.md 一致；九份指定配套文档及相关源码/测试/脚本/构建/CI 已静态阅读。
- `mkdir -p scratch && cp -r ./repo ./scratch/work && chmod -R u+w ./scratch/work` → exit 0。原会话以下测试都在其 scratch/work/；本复审工作区未保留该副本；Node v24.22.1，npm 11.21.1；无 python 别名，使用 python3。
- `npm run typecheck` → exit 127、tsc: not found；`npm test` → exit 127、vitest: not found；`npm run build` → exit 127、tsc: not found。未补装依赖、未使用网络；没有该会话 TypeScript/Vitest/构建通过结果，不拿 VERIFIED-FINDINGS.md 的历史通过数冒充重跑。
- `node docs/formal/SelectiveUndoSourceCheck.mjs` → exit 0，原文输出：`Source checks: 13 passed. These check existing pure operations, not a selective-undo implementation.`；另有 stripTypeScriptTypes ExperimentalWarning。
- `python3 -m unittest discover -s tests -v` → exit 0，`Ran 16 tests`、`OK`；仅覆盖既有 Python 工具，不证明协作或可靠交付。
- 未运行 TLC（本工作树无工具 JAR）、浏览器、真实存储故障、真实照片校准或网络审计。模型证据只作为计划依据。repo/ 保持只读，没有实现拟议接口。


## 待用户审

用户已于 2026-11-13 16:05 +08:00 批准：其余待审项全部先按下方默认建议执行。Q1–Q13 不再作为未决门槛阻塞实现 PR；执行前仍须完成状态图约束冲突检查。没有发现必须倒置 S1–S5 的已证依赖环。

## 已决

- Q0（2026-11-13 16:01 +08:00）：实现基线是 pinned head 的整体，即 PR 说明、设计文档、形式模型和已有代码（含 `src/advisory` 与测试）合在一起，才是真实的设计草稿。不以说明中的 “documentation-only” 单独划定范围，也不把代码从设计中拆出另纳。V1、V2 仍是说明与索引必须校正的错报，由 S1-a 修正，使记录范围与这份整体草稿一致。原 PR 的合入方式未另作指示；仍不自行合并、发布或改 draft 状态。

## 已按默认建议落定（2026-11-13 16:05 +08:00）

下列各项按原默认建议执行。原文选项与理由保留，供约束检查对照。


- Q1：历史目录与保留期怎样定？“历史目录怎么放、保留多久”（docs/agent-collaboration-design.md:160）；“备份目录怎么放、保留多久、怎么删，仍待评审。”（docs/log-backup.md:101）；选项：显式指定目录且不自动删；或平台标准目录配期限/配额；默认建议：首版显式本地目录、projectId 隔离、不自动删，配额不足停止写入并说明；告知保留旧作品内容，不将建议当既定无限保留承诺；阻塞：S3-a；S3-g 的目录/保留默认。
  已按默认建议执行。原未决原因：设计明确把目录和保留期留待评审，不能由本计划定为产品默认；S3-g 通过 S3-a 继承此门槛。 来源见本项所列文件/行。
- Q2：首版是否压缩，压缩后能否撤旧操作？“压缩后被丢掉前缀里的操作还能不能做选择性撤销”（docs/agent-collaboration-design.md:160）；“这不是已经选定的产品默认。”（docs/log-backup.md:89）；选项：不压缩；归档可撤所需记录后压缩；明确撤销截止点后压缩；默认建议：S3-f 只检查点、不删前缀。若必做压缩，在 S3 增列独立 PR 并重新审阅归档/截止提示；不拿普通 50 份快照上限截协作日志；阻塞：S3-f 范围确认；任何新增 Compact PR。
  已按默认建议执行。原未决原因：检查点与压缩不是同一承诺，删除前缀后的可撤范围尚未确定。 来源见本项所列文件/行。
- Q3：是否允许备份整份替换？“本轮不把它定为产品默认。若将来允许替换，那也必须是一次显式的身份或世代更换”（docs/log-backup.md:91）；选项：首版只匹配/拒绝；或明确确认身份/epoch 更换并替换；默认建议：S3-g 保守匹配/拒绝、保留待发；整份替换另列 S3 PR 后启用，不自动快进较长备份；阻塞：S3-g；若选替换，新增 PR 阻塞 S3-h。
  已按默认建议执行。原未决原因：模型的可达性见证不等于产品已开放整份替换；是否增加 PR 需用户选择。 来源见本项所列文件/行。
- Q4：过期预览默认再预览还是重新分类？“两种做法都合法。本轮不在其中挑选产品默认值。”（docs/preview-accept.md:97）；选项：RePreview；Reclassify 并丢旧方案；默认建议：RePreview，结果变化后再次明确确认；无进展说明原因，不循环偷偷接受；阻塞：S2-c。
  已按默认建议执行。原未决原因：两种策略在文档中均合法，模型不能决定交互默认值。 来源见本项所列文件/行。
- Q5：S2 是否包含任意 crop？“源码没有任意矩形裁剪工具。”（docs/selective-undo-after-transform.md:59）；“实现 crop 后验证任意偏移、四边删除”（同文件 :172），而阶段只要求“识别同格冲突、改回原值、制作标记变化和结构变换。”（docs/agent-collaboration-design.md:165）；选项：只验现有 resize 缩小；或在 S2 加 crop 实现及属性测试；默认建议：首版只验右/下缩小映射并保留删除区冲突；若必需任意 crop，在 S2 增列功能/映射 PR，不能将单列模型算作任意 crop 验收；阻塞：S2-b。
  已按默认建议执行。原未决原因：任意 crop 尚未实现，条件验收不能自动扩大本轮功能范围。 来源见本项所列文件/行。
- Q6：两轮候选数、耗时/内存上限、样本权限和人工预算怎样定？“两轮计算量可接受，瓶颈在逐张评审”（docs/agent-collaboration-design.md:188）；“Candidate ranges and iteration limits remain open.”（docs/color-budget-research.md:28）；选项：固定小候选表/资源上限；或实测后按可配置预算停止；默认建议：保留已确认两轮与最后 1–3 个复看；先测授权真实图再定每轮上限、最大源图和可接受资源，校准/验证样本分开；80 保持临时。研究的 94–360 次量化不是产品预算；阻塞：S5-e、S5-f。
  已按默认建议执行。原未决原因：现有结论没有提供可复验的产品资源预算；真实素材授权、预算与人工成本需用户确认。 来源见本项所列文件/行。
- Q7：通用预处理是否属于本轮？“复用 `quantize` 和现有校验”（docs/agent-collaboration-design.md:144）；研究要求“在 OKLab 中用加权贪心 k-medoids 从色板选出 24 色”（docs/image-preprocess-research.md:25），并写“尚未实现到应用中”（同文件 :55）；选项：保持现有 quantize 做候选/校准；或另加可选预处理/选色；默认建议：本计划不换量化。研究是独立实验，固定 24 与自动色数需区分；若必做，先决定在 S4 增候选路径还是 S5 做独立实验并重新列 PR，不在 S1 偷改算法；阻塞：S4-a 范围确认、S5-e 校准对象。
  已按默认建议执行。原未决原因：离线实验与当前量化契约不同，纳入与否会改变候选实现和校准对象。 来源见本项所列文件/行。
- Q8：撤销保留已提交效果还是重执行后续条件命令？“如果产品要保留的是后续命令的条件性意图，就必须再记录读集、区域连通性依赖及条件变化”（docs/selective-undo-after-transform.md:36）；选项：具体效果契约；条件意图重执行；默认建议：具体效果契约；新命令并发提交仍验读依赖。更强契约先补模型/计划，不偷换 CorrectInverse；阻塞：S2-a。
  已按默认建议执行。原未决原因：两种保留语义不同，现有模型只验证具体效果，不能替用户选择更强契约。 来源见本项所列文件/行。
- Q9：运行时、存储及可靠平台由谁验证？“本次没有选择具体数据库。”（docs/single-writer-recovery.md:138）；“Windows、macOS、网络盘及真实硬件的写盘语义需要分别验收”（同文件 :134）；“具体实现需对照所选运行时官方文档验证。”（docs/agent-collaboration-design.md:158）；选项：Node.js 24 追加日志；或明确事务/同步配置的嵌入式数据库；分别确认平台矩阵；默认建议：以现有 Node.js 24 为候选，先验本地文件系统追加日志和进程排他；实现者负责 F1–F16，维护者确认支持平台及独立存储故障环境；IndexedDB 被清理/驱逐不承诺恢复。本次无网络，官方运行时核查留实现前置；阻塞：S3-a、S3-c、S3-h。
  已按默认建议执行。原未决原因：尚未选定运行时/存储及支持平台；本次无网络，官方文档与真实故障环境核验需实现前完成。 来源见本项所列文件/行。
- Q10：S2 是否只验语义，将持久成功留 S3？“成功响应还必须满足待解问题 1 的持久化确认协议”（docs/selective-undo-after-transform.md:95）；“接入本地服务与客户端并持久保存协作历史”在 S3（docs/agent-collaboration-design.md:166）；选项：S2 内存语义、S3 集成故障验收；或要求 S2 即持久成功并明确调整设计；默认建议：保留设计顺序，S2 不发布持久成功承诺，S3-d/S3-h 补验。如果必须提前持久化，这是明确顺序偏离，应先修改设计，不能把 S3 偷移至 S2；阻塞：S2-c 阶段验收口径。
  已按默认建议执行。原未决原因：S2 局部语义与集成后的持久成功须区分；若要求后者提前完成，会改变明确的 S1–S5 顺序。 来源见本项所列文件/行。
- Q11：screen 建议和最终制作推荐怎样区分，24 是否仅旧实验预算？“推荐已评审候选中的最小达标尺寸”（docs/agent-collaboration-design.md:80）与“推荐在最佳分 10 分内豆数最少的候选”（同文件 :81）；“Treat 24 as an initial evaluation budget”（docs/color-budget-research.md:20），设计则“不固定为 24 色”（docs/agent-collaboration-design.md:79）；选项：分开 screen 建议和 Agent 最终推荐；或统一指标后重新校准；默认建议：分开：screen 排入围，Agent 复看特征后选最小已评审达标尺寸再减色；24 不成硬上限，空格造成的豆数少不等于尺寸小；阻塞：S5-f。
  已按默认建议执行。原未决原因：screen 排序与 Agent 制作推荐所用指标不同，研究的初始 24 色预算也不是设计硬上限。 来源见本项所列文件/行。
- Q12：确认 26 个 PR 的切分、S/M 行数估算和 S5-a/b/c 在 Skill 更新前完成的安排；建议保留当前拆分，超 M 时在同阶段再拆；阻塞 S1-a 及实现链。
  已按默认建议执行。原未决原因：docs/agent-collaboration-design.md:164–168 只规定五阶段，没有规定子 PR 数量或行数；S3-a、S3-d、S3-h 同时涉及存储、浏览器或故障验证，未实现前不能保证均落在 450 行以内，S5 内部顺序也是本计划建议。
- Q13：确认 V3 的 weak 最佳项优先展示，以及 V4 去掉 note 决胜后的并列规则；建议按 S5-a/b 保留 shown 和 note 不影响状态的契约；分别阻塞 S5-a、S5-b。
  已按默认建议执行。原未决原因：repo/src/advisory/index.ts:65–66 的 broken 折叠与 weak 展示承诺在全 broken 时冲突；repo/src/advisory/types.ts:27 规定 note 不影响状态，但未给出全部并列策略。已核实的矛盾不能替用户决定冲突规则的优先级。
- P1：历史测试记录不能充当本次复验；实现前需补齐依赖及对应平台的实际验收证据。
  已按默认建议执行。原未决原因：PLAN-session-RESULT.md:3 记录 tsc/vitest 缺失；workers/w3-RESULT.md:111–117 的历史通过属于另一轮环境。本次未跑 TLC、应用测试、构建、浏览器、真实存储故障或真实照片校准；外部核查及支持平台仍由 Q9 决定。
