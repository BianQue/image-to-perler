# 单写者协议的实现验收清单

状态：待实现后执行。对应 [单写者协议草案](single-writer-recovery.md)。本轮只执行了 TLC，没有执行下列应用测试。

## 测试环境与观察值

实现提供只读诊断值和可控阻断点。记录 `projectId`、`tabId`、页面实例、`epoch`、`opId`、`baseRev`、`lastDurableRev`、待发记录、服务日志行数及状态摘要。测试不伪造用户消息 ID 或生产数据。

为每个服务子进程创建独立临时目录。故障测试分别终止浏览器渲染进程及服务进程。普通 page.close、reload 和模拟离线不能替代进程崩溃。测试写盘保证时要另用虚拟机断电或故障文件系统，SIGKILL 不等于切断磁盘电源。

## 故障注入

| 测试 | 注入位置与操作 | 必须观察到的结果 | 对应性质 |
| --- | --- | --- | --- |
| F1 | 笔画预览中，未形成待发记录时终止页面 | 不出现已保存或 Agent 成功。恢复到最后已提交修订，说明未完成预览可能丢失 | AcknowledgedIsDurable |
| F2 | 完成本地待发事务，尚未发送时终止页面，再重开 | 原 opId 及负载恢复。握手后最多追加一次 | NoLostAckedOp、NoDuplicateApply |
| F3 | send 返回后，在服务接收前断网 | UI 仍等待保存。重连先查询日志，再重发原 ID | AcknowledgedIsDurable |
| F4 | 服务校验通过后、持久化前终止服务 | 没有成功回执。重启从磁盘恢复后允许同 ID 重试，且前提重新校验 | NoSilentOverwrite |
| F5 | 写入完整记录但 fsync 尚未返回时终止服务，分别模拟尾记录消失或保留 | 两种结果都能对账。未确认不等于未执行，不能盲目换 ID | NoDuplicateApply |
| F6 | fsync 成功后拦截 ack，再终止两个进程 | 重启能查到完整记录和原结果。重放不会重复施加增量 | AcknowledgedIsDurable、NoLostAckedOp |
| F7 | 收到 ack 后终止页面，分别在清理 journal 前后重开 | 页面与日志一致，旧 journal 的残留不会生成第二条操作 | ConvergenceAfterRecovery、NoDuplicateApply |
| F8 | 同一请求投递两次，第二次发生在另一操作之后 | 返回原修订和原负载结果，日志中 ID 只出现一次 | NoDuplicateApply |
| F9 | 相同 opId 携带不同负载 | 返回 OP_ID_REUSE，日志及状态不变 | 负载绑定，实现附加要求，未由本模型验证 |
| F10 | 服务接收 epoch 1 的提交后暂停写盘。请求 B 接管 epoch 2 | 必须先完成旧提交再授予新世代，或者中止旧提交。不能新世代已授予后才写旧提交 | SingleActiveWriter，SingleWriterGrantRace 反例 |
| F11 | 授予新世代后立即重启服务，再投递旧页面请求 | 世代号不回退，未知旧操作遭拒。查询已知旧 ID 只返回原回执 | SingleActiveWriter |
| F12 | 两次页面崩溃和两次服务崩溃，交替插入重试 | 所有已回执 ID 仍在日志。修订连续，重复 ID 数为零 | NoLostAckedOp、NoDuplicateApply |
| F13 | 同名不同 projectId、同修订不同摘要、不同会话历史 | 拒绝绑定或进入 blocked，保留待发负载，不自动选较大修订 | ProjectIdentity、NoSilentOverwrite |
| F14 | 对失联页面的基础修订写入另一修改，然后重连旧页面 | 自动重发只限可证明相接的尾部。分叉进入 blocked | NoSilentOverwrite |
| F15 | 日志尾部短写、校验错误、fsync EIO、ENOSPC | 不回执成功。允许丢弃未确认的无效尾部，中间损坏及已确认历史缺失必须阻断 | AcknowledgedIsDurable，磁盘实现额外验收 |
| F16 | checkpoint 临时写、文件同步、rename、目录同步各步骤断电 | 只选有效快照加连续日志。未持久发布的快照不能令旧日志提前删除 | NoLostAckedOp，模型外存储验收 |

## Playwright 与实际浏览器

1. 打开 A、B 两个页面。只给 A 正式写入权。A 活动笔画期间发送 Agent 命令，命令等待笔画完成再重新校验，最终每个意图只有一个撤销步骤。
2. 在服务写盘完成前检查状态文本。页面可以有预览，但不能出现“已保存”，Agent 请求也不能返回成功。
3. 让 A 失联或冻结，再在 B 中显式接管。唤醒 A，投递旧请求。服务必须拒绝新写入，A 不得把拒绝响应当成成功。
4. 为 A 导航到另一页面再返回。只有实际观测 `pageshow.persisted === true` 才算覆盖 bfcache，不以 goBack 本身算通过。验证恢复先握手，再启用正式提交。
5. 在 Chromium 中用受支持的 CDP 生命周期测试冻结与恢复。再用 `chrome://discards` 人工核验真实丢弃。不要用脚本手动 dispatchEvent 假装浏览器丢弃。
6. 杀死渲染进程时不运行页面清理回调，检查恢复。分别在 Chromium、Firefox、WebKit 跑重载和双标签页测试，不把一种浏览器的生命周期经验推广给其他浏览器。
7. 对应用消息层拦截器排列丢失、重复和跨重连迟到的 hello、sync、commit、ack。WebSocket 单连接本身有序，测试的乱序来自不同连接及异步请求，不是假装 TCP 随机交换帧。
8. 同时触发 resume、pageshow 和 close 恢复路径，确保只启动一个恢复请求。旧响应不能回退新修订。
9. 恢复原图后逐项核验 Project、2D、3D、历史、用量和导出快照的修订一致。render 调用次数不能代替用户可见的一致性。
10. 执行普通撤销、重做、选择性撤销及原模型 ABA 反例。确认这些操作都经过同一个提交和持久化队列。保持无关人工编辑，不按当前颜色相等自动覆盖。

## 通过标准

每次测试保留故障位置、原 ID、服务日志和最终摘要。测试必须同时断言结果正确及不应发生的副作用未发生。不用“连接恢复了”代替“作品、日志和历史已核对一致”。

协议尚未实现，因此这份清单不是测试通过报告。只有独立存储故障测试完成后，才能把模型的原子磁盘假设升级成所选平台的实现保证。
