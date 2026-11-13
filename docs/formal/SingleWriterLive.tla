------------------------- MODULE SingleWriterLive -------------------------
EXTENDS SingleWriter
\* Recovery-only suffix: one journaled operation, two possible disk seams,
\* browser/service initially either running or crashed. No new edits, takeovers,
\* freezes, losses or subsequent crashes after this stabilization point.
LiveInit ==
  /\ serviceUp \in BOOLEAN
  /\ b \in {[t \in Tabs |-> [up |-> u, online |-> u, paused |-> FALSE,
        mode |-> "recover", req |-> 1, epoch |-> 0,
        view |-> IF u THEN <<1>> ELSE <<>>,
        value |-> IF u THEN 1 ELSE 0, pending |-> IF u THEN 1 ELSE 0,
        saved |-> {}]] : u \in BOOLEAN}
  /\ journal = [t \in Tabs |-> 1]
  /\ ops = <<[owner |-> 1, base |-> <<>>, before |-> 0, after |-> 1]>>
  /\ disk \in {[log |-> xs, epoch |-> 0, holder |-> 0, request |-> 0,
                  tickets |-> [t \in Tabs |-> 0]] : xs \in {<<>>, <<1>>}}
  /\ work = None /\ net = {} /\ everAcked = {}
  /\ browserCrashes = 0 /\ serviceCrashes = 0
  /\ badFence = FALSE /\ badOverwrite = FALSE /\ badIdentity = FALSE
DeliverHello == \E m \in net: (Grant(m) \/ RepeatHello(m)) /\ m \notin net'
DeliverSync == \E m \in net: ReceiveSync(m) /\ m \notin net'
DeliverCommit == \E m \in net: (ReceiveCommit(m) \/ ReplyKnown(m)) /\ m \notin net'
DeliverAck == \E m \in net: ReceiveAck(m) /\ m \notin net'
LiveNext == SendHello(1) \/ SendCommit(1) \/ Reopen(1) \/ RestartService
            \/ DeliverHello \/ DeliverSync \/ DeliverCommit \/ DeliverAck
            \/ Flush \/ ReplyWork
LiveSpec == LiveInit /\ [][LiveNext]_vars
  /\ WF_vars(SendHello(1)) /\ WF_vars(SendCommit(1))
  /\ WF_vars(Reopen(1)) /\ WF_vars(RestartService)
  /\ WF_vars(DeliverHello) /\ WF_vars(DeliverSync)
  /\ WF_vars(DeliverCommit) /\ WF_vars(DeliverAck)
  /\ WF_vars(Flush) /\ WF_vars(ReplyWork)
Reconciled == b[1].up /\ serviceUp /\ b[1].mode = "ready"
              /\ b[1].pending = 0 /\ b[1].view = disk.log
              /\ b[1].value = Replay(disk.log) /\ 1 \in Ids(disk.log)
EventualReconciliation == <> Reconciled
=============================================================================
