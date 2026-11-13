--------------------------- MODULE SingleWriter ---------------------------
EXTENDS Naturals, Sequences, FiniteSets, TLC
CONSTANTS Tabs, MaxOps, MaxEpoch, MaxRequests, MaxBrowserCrashes,
          MaxServiceCrashes, MaxNet, Bug, ForeignTab
VARIABLES b, journal, ops, disk, work, serviceUp, net, everAcked,
          browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity
vars == <<b, journal, ops, disk, work, serviceUp, net, everAcked,
          browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>
Ids(xs) == {xs[i] : i \in 1..Len(xs)}
Prefix(xs, ys) == Len(xs) <= Len(ys) /\ xs = SubSeq(ys, 1, Len(xs))
RECURSIVE Replay(_)
Replay(xs) == IF xs = <<>> THEN 0 ELSE Replay(Tail(xs)) + Head(xs)
None == [kind |-> "none", tab |-> 0, req |-> 0, pid |-> "P", epoch |-> 0, id |-> 0, log |-> <<>>]
Project(t) == IF t = ForeignTab THEN "Q" ELSE "P"
Live(t) == b[t].up /\ b[t].online /\ ~b[t].paused
Fence(m) == m.epoch = disk.epoch /\ m.tab = disk.holder
            /\ m.req = disk.request
Fresh(m) == ops[m.id].base = disk.log /\ ops[m.id].before = Replay(disk.log)
Known(m) == m.id \in Ids(disk.log)
Hello(t) == [kind |-> "hello", tab |-> t, req |-> b[t].req,
              pid |-> Project(t), epoch |-> b[t].epoch, id |-> 0,
              log |-> b[t].view]
Commit(t) == [kind |-> "commit", tab |-> t, req |-> b[t].req,
              pid |-> Project(t), epoch |-> b[t].epoch,
              id |-> b[t].pending, log |-> <<>>]
Sync(m, ep) == [kind |-> "sync", tab |-> m.tab, req |-> m.req,
                pid |-> "P", epoch |-> ep, id |-> 0, log |-> disk.log]
Ack(m) == [kind |-> "ack", tab |-> m.tab, req |-> m.req,
           pid |-> "P", epoch |-> m.epoch, id |-> m.id, log |-> disk.log]
LastDurableRev == Len(disk.log)
AuthorizedWriters == {t \in Tabs : Live(t) /\ b[t].mode = "ready"
                      /\ b[t].epoch = disk.epoch /\ t = disk.holder
                      /\ b[t].req = disk.request}
Init ==
  /\ b = [t \in Tabs |-> [up |-> TRUE, online |-> TRUE, paused |-> FALSE,
          mode |-> "recover", req |-> 1, epoch |-> 0, view |-> <<>>,
          value |-> 0, pending |-> 0, saved |-> {}]]
  /\ journal = [t \in Tabs |-> 0]
  /\ ops = <<>>
  /\ disk = [log |-> <<>>, epoch |-> 0, holder |-> 0, request |-> 0,
              tickets |-> [t \in Tabs |-> 0]]
  /\ work = None /\ serviceUp = TRUE /\ net = {} /\ everAcked = {}
  /\ browserCrashes = 0 /\ serviceCrashes = 0
  /\ badFence = FALSE /\ badOverwrite = FALSE /\ badIdentity = FALSE

SendHello(t) ==
  /\ Live(t) /\ b[t].mode = "recover"
  /\ net' = net \cup {Hello(t)} /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Grant(m) ==
  /\ serviceUp /\ m \in net /\ m.kind = "hello"
  /\ m.pid = "P" \/ Bug = "filename"
  /\ m.req > disk.tickets[m.tab] /\ disk.epoch < MaxEpoch
  /\ work = None \/ Bug = "grantRace"
  /\ disk' = [disk EXCEPT !.epoch = @ + 1, !.holder = m.tab,
          !.request = m.req, !.tickets[m.tab] = m.req]
  /\ net' \in {(net \ {m}) \cup {Sync(m, disk.epoch + 1)},
                net \cup {Sync(m, disk.epoch + 1)}}
  /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

RepeatHello(m) ==
  /\ serviceUp /\ m \in net /\ m.kind = "hello"
  /\ m.pid = "P" \/ Bug = "filename"
  /\ m.tab = disk.holder /\ m.req = disk.request
  /\ work = None
  /\ net' \in {(net \ {m}) \cup {Sync(m, disk.epoch)},
                net \cup {Sync(m, disk.epoch)}}
  /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

ReceiveSync(m) ==
  /\ m \in net /\ m.kind = "sync" /\ Live(m.tab)
  /\ LET t == m.tab
         p == b[t].pending
         committed == p # 0 /\ p \in Ids(m.log)
         tail == IF p = 0 THEN FALSE
                 ELSE ops[p].base = m.log /\ b[t].view = Append(m.log, p)
         clean == p = 0 /\ Prefix(b[t].view, m.log)
         coherent == committed \/ tail \/ clean
     IN /\ b[t].mode = "recover" /\ m.req = b[t].req
        /\ m.epoch >= b[t].epoch
        /\ m.pid = Project(t) \/ Bug = "filename"
        /\ b' = [b EXCEPT ![t].epoch = m.epoch,
                  ![t].mode = IF coherent THEN "ready" ELSE "blocked",
                  ![t].view = IF committed \/ clean THEN m.log ELSE @,
                  ![t].value = IF committed \/ clean THEN Replay(m.log) ELSE @,
                  ![t].pending = IF committed THEN 0 ELSE @,
                  ![t].saved = IF committed \/ clean THEN Ids(m.log) ELSE @]
        /\ journal' = [journal EXCEPT ![t] = IF committed THEN 0 ELSE @]
        /\ everAcked' = IF committed \/ clean THEN everAcked \cup Ids(m.log)
                        ELSE everAcked
        /\ badIdentity' = (badIdentity \/ (Project(t) # m.pid))
  /\ net' \in {net \ {m}, net}
  /\ UNCHANGED <<ops, disk, work, serviceUp, browserCrashes, serviceCrashes, badFence, badOverwrite>>

JournalAndPreview(t) ==
  /\ Live(t) /\ b[t].mode = "ready" /\ b[t].pending = 0
  /\ Project(t) = "P" /\ Len(ops) < MaxOps
  /\ LET id == Len(ops) + 1
     IN /\ ops' = Append(ops, [owner |-> t, base |-> b[t].view,
                      before |-> b[t].value, after |-> b[t].value + id])
        /\ journal' = [journal EXCEPT ![t] = id]
        /\ b' = [b EXCEPT ![t].pending = id,
                  ![t].view = Append(@, id), ![t].value = @ + id]
  /\ UNCHANGED <<disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

SendCommit(t) ==
  /\ Live(t) /\ b[t].mode = "ready" /\ b[t].pending # 0
  /\ net' = net \cup {Commit(t)} /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

ReceiveCommit(m) ==
  /\ serviceUp /\ work = None /\ m \in net /\ m.kind = "commit"
  /\ m.pid = "P" /\ (Fence(m) \/ Bug = "noFence")
  /\ ~Known(m) \/ Bug = "noDedupe"
  /\ (Fresh(m) \/ (Bug = "noDedupe" /\ Known(m)))
  /\ Len(disk.log) < MaxOps + 1
  /\ work' = m
  /\ badFence' = (badFence \/ ~Fence(m))
  /\ badOverwrite' = (badOverwrite \/ (~Fresh(m) /\ ~Known(m)))
  /\ net' \in {net \ {m}, net}
  /\ UNCHANGED <<b, journal, ops, disk, serviceUp, everAcked, browserCrashes, serviceCrashes, badIdentity>>

Flush ==
  /\ serviceUp /\ work # None /\ work.kind = "commit"
  /\ ~Known(work) \/ Bug = "noDedupe"
  /\ Fence(work) \/ Bug \in {"noFence", "grantRace"}
  /\ disk' = [disk EXCEPT !.log = Append(@, work.id)]
  /\ work' = [work EXCEPT !.kind = "flushed"]
  /\ badFence' = (badFence \/ ~Fence(work))
  /\ UNCHANGED <<b, journal, ops, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badOverwrite, badIdentity>>

ReplyWork ==
  /\ serviceUp /\ work # None /\ Known(work)
  /\ net' = net \cup {Ack(work)} /\ Cardinality(net') <= MaxNet
  /\ work' = None
  /\ UNCHANGED <<b, journal, ops, disk, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

ReplyKnown(m) ==
  /\ serviceUp /\ m \in net /\ m.kind = "commit" /\ m.pid = "P"
  /\ Known(m) /\ Bug # "noDedupe"
  \* Dedupe before freshness/fencing returns an old durable receipt, not a new write.
  /\ net' \in {(net \ {m}) \cup {Ack(m)}, net \cup {Ack(m)}}
  /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

EarlyReply ==
  /\ Bug = "earlyAck" /\ serviceUp /\ work # None /\ ~Known(work)
  /\ net' = net \cup {Ack(work)} /\ Cardinality(net') <= MaxNet
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

ReceiveAck(m) ==
  /\ m \in net /\ m.kind = "ack" /\ Live(m.tab)
  /\ LET t == m.tab
     IN /\ m.pid = Project(t) /\ m.req = b[t].req
        /\ m.id = b[t].pending /\ m.epoch = b[t].epoch
        /\ b' = [b EXCEPT ![t].pending = 0,
                    ![t].saved = @ \cup {m.id}]
        /\ journal' = [journal EXCEPT ![t] = 0]
        /\ everAcked' = everAcked \cup {m.id}
  /\ net' \in {net \ {m}, net}
  /\ UNCHANGED <<ops, disk, work, serviceUp, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Drop(m) ==
  /\ m \in net /\ net' = net \ {m}
  /\ UNCHANGED <<b, journal, ops, disk, work, serviceUp, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Disconnect(t) ==
  /\ Live(t)
  /\ b' = [b EXCEPT ![t].online = FALSE]
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Reconnect(t) ==
  /\ b[t].up /\ ~b[t].paused /\ ~b[t].online /\ b[t].req < MaxRequests
  /\ b' = [b EXCEPT ![t].online = TRUE, ![t].mode = "recover", ![t].req = @ + 1]
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Freeze(t) ==
  /\ Live(t)
  /\ b' = [b EXCEPT ![t].paused = TRUE, ![t].online = FALSE]
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

Wake(t) ==
  /\ b[t].up /\ b[t].paused
  \* An old page can wake believing it still owns the project. Fence at service.
  /\ b' = [b EXCEPT ![t].paused = FALSE, ![t].online = TRUE]
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

CrashBrowser(t) ==
  /\ b[t].up /\ browserCrashes < MaxBrowserCrashes
  /\ b' = [b EXCEPT ![t].up = FALSE, ![t].online = FALSE,
                ![t].paused = FALSE, ![t].mode = "recover", ![t].epoch = 0,
                ![t].view = <<>>, ![t].value = 0, ![t].pending = 0, ![t].saved = {}]
  /\ browserCrashes' = browserCrashes + 1
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, serviceCrashes, badFence, badOverwrite, badIdentity>>

Reopen(t) ==
  /\ ~b[t].up /\ b[t].req < MaxRequests
  /\ LET p == journal[t]
     IN /\ b' = [b EXCEPT ![t].up = TRUE, ![t].online = TRUE,
                    ![t].req = @ + 1, ![t].pending = p,
                    ![t].view = IF p = 0 THEN <<>> ELSE Append(ops[p].base, p),
                    ![t].value = IF p = 0 THEN 0 ELSE ops[p].after]
  /\ UNCHANGED <<journal, ops, disk, work, serviceUp, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

CrashService ==
  /\ serviceUp /\ serviceCrashes < MaxServiceCrashes
  /\ serviceUp' = FALSE /\ work' = None
  /\ serviceCrashes' = serviceCrashes + 1
  /\ UNCHANGED <<b, journal, ops, disk, net, everAcked, browserCrashes, badFence, badOverwrite, badIdentity>>

RestartService ==
  /\ ~serviceUp /\ serviceUp' = TRUE
  /\ UNCHANGED <<b, journal, ops, disk, work, net, everAcked, browserCrashes, serviceCrashes, badFence, badOverwrite, badIdentity>>

BrowserNext(t) == SendHello(t) \/ JournalAndPreview(t) \/ SendCommit(t)
                  \/ Disconnect(t) \/ Reconnect(t) \/ Freeze(t) \/ Wake(t)
                  \/ CrashBrowser(t) \/ Reopen(t)
MessageNext(m) == Grant(m) \/ RepeatHello(m) \/ ReceiveSync(m)
                  \/ ReceiveCommit(m) \/ ReplyKnown(m) \/ ReceiveAck(m) \/ Drop(m)
Next == (\E t \in Tabs: BrowserNext(t)) \/ (\E m \in net: MessageNext(m))
        \/ Flush \/ ReplyWork \/ EarlyReply \/ CrashService \/ RestartService
Spec == Init /\ [][Next]_vars
AcknowledgedIsDurable == \A t \in Tabs: b[t].saved \subseteq Ids(disk.log)
NoLostAckedOp == everAcked \subseteq Ids(disk.log)
NoDuplicateApply == Len(disk.log) = Cardinality(Ids(disk.log))
SingleActiveWriter == Cardinality(AuthorizedWriters) <= 1 /\ ~badFence
NoSilentOverwrite == ~badOverwrite
ProjectIdentity == ~badIdentity
ConvergenceAfterRecovery == \A t \in AuthorizedWriters:
  b[t].pending = 0 => b[t].view = disk.log /\ b[t].value = Replay(disk.log)
BrowserReplayConsistent == \A t \in Tabs: b[t].value = Replay(b[t].view)
NotTwoBrowserRecoveries == ~(browserCrashes = 2 /\ b[1].up
  /\ b[1].mode = "ready" /\ b[1].epoch = 3 /\ b[1].pending = 0)
NotTwoServiceRecoveries == ~(serviceCrashes = 2 /\ serviceUp
  /\ b[1].mode = "ready" /\ b[1].pending = 0 /\ Len(disk.log) = 1)
NotBrowserAheadResumed == ~(b[1].epoch = 2 /\ b[1].mode = "ready"
  /\ b[1].pending = 1 /\ disk.log = <<>> /\ b[1].view = <<1>>)
NotServiceAheadReplayed == ~(browserCrashes > 0 /\ b[1].epoch = 2
  /\ b[1].mode = "ready" /\ b[1].pending = 0 /\ disk.log = <<1>>
  /\ b[1].view = disk.log)
TypeOK ==
  /\ disk.epoch \in 0..MaxEpoch /\ disk.holder \in Tabs \cup {0}
  /\ Len(ops) <= MaxOps /\ Len(disk.log) <= MaxOps + 1
  /\ Ids(disk.log) \subseteq 1..Len(ops)
  /\ browserCrashes \in 0..MaxBrowserCrashes /\ serviceCrashes \in 0..MaxServiceCrashes
  /\ Cardinality(net) <= MaxNet
  /\ \A t \in Tabs: b[t].req \in 1..MaxRequests /\ b[t].pending \in 0..Len(ops)
=============================================================================
