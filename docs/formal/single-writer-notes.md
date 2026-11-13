# SingleWriter 模型索引

这组文件是协议提案，不是应用实现。正常安全模型允许故障和无限等待，不设置公平性。`SingleWriterLive` 另查稳定环境的最终对账。具体结果见 [形式验证说明](README.md#singlewriter-扩展模型)。

## 状态与抽象

- `b[t]` 是标签页易失内存。包含是否打开、是否冻结、是否联网、恢复阶段、请求代次、世代、日志视图、状态值、待确认 ID 和当前显示的持久 ID。
- `journal[t]` 是浏览器已完成事务的本地待发记录。它与页面内存分开，`CrashBrowser` 不清除它。
- `ops` 为每个新 ID 固定负载。模型用操作 ID 本身作为增量，完整日志序列保留顺序。`Replay` 是日志重放函数。真实 JSON、豆格及前后值结构没有建模。
- `disk` 保存日志和当前写入权。`LastDurableRev` 是日志长度。日志项代表完整可恢复记录，不是只保存一个裸 ID。
- `work` 是服务内存中的一条收到或已完成持久化的记录。`CrashService` 清空它，不清空 `disk`。
- `net` 是至多 MaxNet 个不同消息的集合。任意消息可先投递。投递时保留消息代表重复投递，`Drop` 代表丢失。
- `everAcked` 是只用于验证的历史观察值。它记录曾被用户看见的成功，不随进程崩溃清除。
- `badFence`、`badOverwrite` 和 `badIdentity` 是验证观察值，不是应用预期的数据结构。

## 完整动作

| 动作 | 所属方 | 含义 |
| --- | --- | --- |
| SendHello | 页面 | 发送带项目、请求代次及视图修订的恢复请求 |
| Grant | 服务与磁盘 | 在项目队列空闲时持久分配新世代及持有者，生成同步响应 |
| RepeatHello | 服务 | 重复当前授予请求，不重复增加世代 |
| ReceiveSync | 页面 | 核对身份、代次和日志，重放、保留可重发尾部，或进入 blocked |
| JournalAndPreview | 页面及本地记录 | 固定完成的修改意图并形成待发记录，再展示等待保存的视图 |
| SendCommit | 页面 | 发送原操作 ID，允许重复发送 |
| ReceiveCommit | 服务 | 接收未知操作，检查身份、当前写入权和基础日志前缀 |
| Flush | 磁盘 | 一条完整记录持久化，把服务 work 从 commit 改为 flushed |
| ReplyWork | 服务 | 为刚完成持久化的记录生成回执，清空 work |
| ReplyKnown | 服务 | 为重复 ID 返回既有持久结果，不产生新修改 |
| EarlyReply | 仅变异 | 未持久化即生成回执 |
| ReceiveAck | 页面 | 接受匹配的持久回执，清理待发记录并更新已保存标记 |
| Drop | 信道 | 丢弃任意在途消息 |
| Disconnect、Reconnect | 页面 | 断开，或以新的请求代次进入恢复 |
| Freeze、Wake | 页面 | 保留内存的冻结及唤醒。故意允许旧页面醒来时仍认为自己有权写入 |
| CrashBrowser、Reopen | 页面 | 丢失易失内存，重开后从本地待发记录恢复 |
| CrashService、RestartService | 服务 | 丢失未持久 work，从保留的磁盘状态继续 |

Grant 的写盘与回信入信道是一个抽象动作。回信可以立刻丢失，所以覆盖了“世代已持久化、页面尚未获知”的窗口。模型未验证真正的世代记录 fsync 实现。

## 安全性质

| 名称 | 精确解释 |
| --- | --- |
| AcknowledgedIsDurable | 任一页面显示为已保存的操作 ID 都在磁盘日志 |
| NoLostAckedOp | 曾显示成功的 ID 跨崩溃仍在磁盘日志 |
| NoDuplicateApply | 日志没有重复 ID |
| SingleActiveWriter | 当前获服务授权的活动页面至多一个，且未接纳旧世代新写入。失联页面可能仍自认为有权限 |
| NoSilentOverwrite | 接收新操作时没有绕过基础日志及旧值前提。原模型另查局部版本、结构版本和选择性撤销 |
| ProjectIdentity | 未把 Q 项目页面恢复到 P 项目的协作历史 |
| ConvergenceAfterRecovery | 当前有权写入且无待确认操作的页面，其日志视图与状态等于磁盘重放 |
| BrowserReplayConsistent | 页面状态值与其自身日志视图一致，包括待保存预览 |
| TypeOK | 边界、ID、世代及计数符合配置 |

前两个性质部分重合，但观察对象不同。页面崩溃会清除当前 saved，`everAcked` 不清除，因此仍能检查已经给过用户的成功承诺。

## 配置边界

所有配置都关闭死锁检查。有限预算用尽或冲突阻断不代表协议错误，但不能由此宣称始终有进展。

- `SingleWriter`、`SingleWriterFP1`：2 标签页，2 新操作，2 世代，2 请求代次，浏览器崩溃总数和服务崩溃次数各 2，最多 2 个不同在途消息。FP1 使用第二个状态指纹多项式重跑同一状态空间。
- `SingleWriterRestartTwice`：1 标签页，1 操作，3 世代，3 请求代次，浏览器和服务各 2 次崩溃。
- `SingleWriterIdentity`：2 标签页，其中一个属于 Q，P 服务正常拒绝。该配置不含崩溃，仍包含断线和重连。
- `SingleWriterEarlyAck`、`SingleWriterNoFence`、`SingleWriterNoDedupe`、`SingleWriterFilename`：分别削弱持久回执、世代检查、重复 ID 返回原结果路径及项目身份校验。
- `SingleWriterGrantRace`：允许 Grant 插入未完成 work，且去掉 Flush 的世代复查。它测试“只在接收时检查一次世代”的协议候选，不是只删除单行守卫。
- `SingleWriterCover*`：用故意为假的“目标不可达”不变量找覆盖见证。退出 12 表示目标可达，不表示正向协议有缺陷。

`SingleWriterNoDedupe` 的变异精确含义是把已知 ID 重新走施加修改的路径，并允许这个错误重试分支越过旧基础版本。严格保留整份 baseRev 检查而仅删除结果缓存，重复请求可能被拒绝而不重复修改。因此该反例不能用来声称“只删去任何一种去重实现都必然重复应用”。它证明协议必须定义重复 ID 的结果路径，不能把重试当作新的增量执行。

## 活性检查的条件

`SingleWriterLive` 从 8 种初态开始：一个已形成待发记录的操作，磁盘尚未保存或已保存，页面运行或崩溃，服务运行或崩溃。之后不再有新修改、接管或崩溃。投递动作消费消息，不再丢包，并对发送、投递、页面重开、服务重启、写盘及回执施加弱公平。

`EventualReconciliation` 要求最终服务在线、页面 ready、待确认操作清空、该 ID 出现在日志，且页面状态等于日志重放。这是稳定环境后缀的有限模型检查，不是整个任意故障系统的最终恢复定理。
