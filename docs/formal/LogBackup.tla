------------------------------ MODULE LogBackup ------------------------------
(*
  Protocol-hazard model: after a durable checkpoint, an old log
  prefix may be dropped only when it is no longer required by
  unacked commits or still-valid recovery paths. Replay of the
  durable checkpoint plus the remaining suffix must equal the
  pre-compact project state.

  Restoring a backup must first check project identity and the
  log prefix (or a trusted digest of that prefix, modeled here
  as the prefix sequence itself). A matching prefix may continue.
  A fork, an identity mismatch, or an older backup that is not
  a prefix of the live log is a class-4 hard stop. The backup
  must not be silently written into the live log.

  The service log is the recovery source of truth. A checkpoint
  is a rebuildable cache, not a second source of truth that can
  overwrite the log. Compaction may only drop a strict prefix
  older than a durable checkpoint; it must not rewrite or delete
  mid-history operations as a way to "clean" the log.

  Gated flags are for witnesses only:
    AllowCompactBeforeDurable     drop a prefix against a pending
                                  (not yet durable) checkpoint
    AllowCompactWithUnacked       drop a prefix that an unacked
                                  base still depends on
    AllowRestoreStaleOrDivergent  write the backup into the live
                                  log without the prefix check
    AllowExplicitReplace          an explicit identity or epoch
                                  change that leaves the old live
                                  log unmerged. This is an open
                                  product choice, not a default.

  Open product choices, not decided here:
    (a) After compact, whether operations that lived only in the
        discarded prefix remain selectively undoable. The model
        records last.reason on a legal compact, and treats those
        operations as not selectively undoable for conservative
        v1 bookkeeping only. That is not a product default.
    (b) Whether the user may explicitly replace the live
        collaboration project with a backup. If the flag is
        false, ExplicitReplace is absent. If true, it must be a
        gated new identity or epoch, never an automatic merge
        onto the same live log.

  Class 4 is only for restore hard stops: identity mismatch,
  log fork, or a restore that would diverge the live log.
  A refused compact is not class 4.

  Bounds exist only so TLC can exhaust the state space. This is
  a model, not an application feature, and not an unbounded proof.
  Retention days or a maximum operation count are not product
  policy.
*)
EXTENDS Naturals, Sequences, TLC

CONSTANTS Scenario, MaxOps,
          AllowCompactBeforeDurable,
          AllowCompactWithUnacked,
          AllowRestoreStaleOrDivergent,
          AllowExplicitReplace

VARIABLES projectId, epoch, hist, phys, dropped, ckpt, pending,
          unacked, backup, last, class4, forked, pc

vars == <<projectId, epoch, hist, phys, dropped, ckpt, pending,
          unacked, backup, last, class4, forked, pc>>

NoneCkpt == [status |-> "none", rev |-> 0, snapshot |-> 0, prefix |-> <<>>]
NoneUnacked == [id |-> 0, value |-> 0, base |-> <<>>]
NoneBackup == [present |-> FALSE, pid |-> "P", image |-> <<>>]
ForkMarker == 9

Prefix(xs, ys) == Len(xs) <= Len(ys) /\ xs = SubSeq(ys, 1, Len(xs))
Related(xs, ys) == Prefix(xs, ys) \/ Prefix(ys, xs)

RECURSIVE Replay(_)
Replay(xs) == IF xs = <<>> THEN 0 ELSE Head(xs) + Replay(Tail(xs))

SuffixFrom(s, start) ==
  IF start > Len(s) THEN <<>> ELSE SubSeq(s, start, Len(s))

(* Physical log is the retained suffix. A durable checkpoint stores
   the trusted prefix (used as a digest) plus a replayable snapshot.
   A pending checkpoint is a separate in-flight write; it does not
   survive a crash and cannot justify dropping a prefix. Starting a
   pending write must not erase an existing durable checkpoint. *)
RecoverableLog ==
  IF ckpt.status = "durable" /\ dropped > 0 /\ Len(ckpt.prefix) >= dropped
  THEN SubSeq(ckpt.prefix, 1, dropped) \o phys
  ELSE phys

RecoverableState == Replay(RecoverableLog)

ForkImage(xs) ==
  IF xs = <<>> THEN <<ForkMarker>>
  ELSE Append(SubSeq(xs, 1, Len(xs) - 1), ForkMarker)

LastRec(act, reason, cls) ==
  [action |-> act, reason |-> reason, class |-> cls,
   preLog |-> RecoverableLog, prePhys |-> phys, preDropped |-> dropped,
   preEpoch |-> epoch, preUnacked |-> unacked, prePid |-> projectId,
   preState |-> RecoverableState, preHist |-> hist]

Init ==
  /\ projectId = "P" /\ epoch = 1
  /\ hist = <<>> /\ phys = <<>> /\ dropped = 0
  /\ ckpt = NoneCkpt /\ pending = NoneCkpt
  /\ unacked = NoneUnacked /\ backup = NoneBackup
  /\ last = LastRec("init", "ok", 0)
  /\ class4 = FALSE /\ forked = FALSE /\ pc = 0

StartCheckpoint ==
  /\ pending' = [status |-> "pending",
                  rev |-> Len(RecoverableLog),
                  snapshot |-> RecoverableState,
                  prefix |-> RecoverableLog]
  /\ last' = LastRec("startCheckpoint", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, unacked,
                 backup, class4, forked>>

Checkpoint ==
  /\ ckpt' = [status |-> "durable",
               rev |-> Len(RecoverableLog),
               snapshot |-> RecoverableState,
               prefix |-> RecoverableLog]
  /\ last' = LastRec("checkpoint", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, pending, unacked,
                 backup, class4, forked>>

PersistCheckpoint ==
  /\ pending.status = "pending"
  /\ dropped <= pending.rev
  /\ ckpt' = [pending EXCEPT !.status = "durable"]
  /\ pending' = NoneCkpt
  /\ last' = LastRec("persistCheckpoint", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, unacked,
                 backup, class4, forked>>

Commit ==
  /\ unacked.id = 0
  /\ Len(hist) < MaxOps
  /\ LET v == Len(hist) + 1
     IN /\ hist' = Append(hist, v)
        /\ phys' = Append(phys, v)
        /\ last' = LastRec("commit", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, dropped, ckpt, pending, unacked, backup,
                 class4, forked>>

Journal ==
  /\ unacked.id = 0
  /\ Len(hist) < MaxOps
  /\ unacked' = [id |-> Len(hist) + 1,
                 value |-> Len(hist) + 1,
                 base |-> RecoverableLog]
  /\ last' = LastRec("journal", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, backup,
                 class4, forked>>

(* Directed only: an unacked base that is a proper prefix of the
   current log, so a later compact of a longer checkpoint prefix
   would drop bytes this recovery path still needs. Intermediate
   prefix digests are not stored. *)
JournalMid ==
  /\ unacked.id = 0
  /\ Len(RecoverableLog) >= 2
  /\ Len(hist) < MaxOps
  /\ unacked' = [id |-> Len(hist) + 1,
                 value |-> Len(hist) + 1,
                 base |-> SubSeq(RecoverableLog, 1, 1)]
  /\ last' = LastRec("journalMid", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, backup,
                 class4, forked>>

FlushUnacked ==
  /\ unacked.id # 0
  /\ unacked.base = RecoverableLog
  /\ Len(hist) < MaxOps
  /\ hist' = Append(hist, unacked.value)
  /\ phys' = Append(phys, unacked.value)
  /\ unacked' = NoneUnacked
  /\ last' = LastRec("flush", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, dropped, ckpt, pending, backup, class4, forked>>

CanDropPrefix ==
  /\ ckpt.status = "durable"
  /\ dropped < ckpt.rev
  /\ ckpt.rev = Len(ckpt.prefix)
  /\ Prefix(ckpt.prefix, RecoverableLog)

DropToCheckpoint ==
  /\ phys' = SuffixFrom(phys, ckpt.rev - dropped + 1)
  /\ dropped' = ckpt.rev

(* Good compact: durable checkpoint, and no unacked op whose base
   is shorter than the dropped prefix (those still-valid recovery
   paths would need an intermediate digest that is not kept). *)
Compact ==
  /\ CanDropPrefix
  /\ unacked.id = 0 \/ Len(unacked.base) >= ckpt.rev
  /\ DropToCheckpoint
  /\ last' = LastRec("compact",
                     "prefix-selective-undo-left-open", 0)
  /\ UNCHANGED <<projectId, epoch, hist, ckpt, pending, unacked, backup,
                 class4, forked>>

CompactBeforeDurable ==
  /\ AllowCompactBeforeDurable
  /\ pending.status = "pending"
  /\ dropped < pending.rev
  /\ Prefix(pending.prefix, RecoverableLog)
  /\ phys' = SuffixFrom(phys, pending.rev - dropped + 1)
  /\ dropped' = pending.rev
  /\ last' = LastRec("compactBeforeDurable", "not-durable", 0)
  /\ UNCHANGED <<projectId, epoch, hist, ckpt, pending, unacked, backup,
                 class4, forked>>

CompactWithUnacked ==
  /\ AllowCompactWithUnacked
  /\ CanDropPrefix
  /\ unacked.id # 0
  /\ Len(unacked.base) < ckpt.rev
  /\ DropToCheckpoint
  /\ last' = LastRec("compactWithUnacked", "unacked-depends", 0)
  /\ UNCHANGED <<projectId, epoch, hist, ckpt, pending, unacked, backup,
                 class4, forked>>

Backup ==
  /\ backup' = [present |-> TRUE, pid |-> projectId,
                image |-> RecoverableLog]
  /\ last' = LastRec("backup", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, unacked,
                 class4, forked>>

OfferFork ==
  /\ Len(RecoverableLog) >= 1
  /\ backup' = [present |-> TRUE, pid |-> "P",
                image |-> ForkImage(RecoverableLog)]
  /\ last' = LastRec("offerFork", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, unacked,
                 class4, forked>>

OfferMismatch ==
  /\ backup' = [present |-> TRUE, pid |-> "Q",
                image |-> RecoverableLog]
  /\ last' = LastRec("offerMismatch", "ok", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, unacked,
                 class4, forked>>

MatchingBackup ==
  backup.present /\ backup.pid = projectId
  /\ Prefix(backup.image, RecoverableLog)

(* Conservative: restore is a no-op when the backup identity
   matches and the backup image is a prefix of, or equal to, the
   live recoverable log. A backup with extra ops is not applied,
   even if the live log happens to be a prefix of the backup. *)
RestoreMatching ==
  /\ MatchingBackup
  /\ last' = LastRec("restoreMatching", "already-included", 0)
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, unacked,
                 backup, class4, forked>>

RejectReason ==
  IF ~backup.present THEN "no-backup"
  ELSE IF backup.pid # projectId THEN "identity-mismatch"
  ELSE IF Prefix(backup.image, RecoverableLog) THEN "already-included"
  ELSE IF Prefix(RecoverableLog, backup.image) THEN "unproven-suffix"
  ELSE "fork"

RejectRestore ==
  /\ backup.present
  /\ ~MatchingBackup
  /\ last' = LastRec("rejectRestore", RejectReason, 4)
  /\ class4' = TRUE
  /\ UNCHANGED <<projectId, epoch, hist, phys, dropped, ckpt, pending, unacked,
                 backup, forked>>

(* Forbidden default-bad action: install a backup into the live
   log without the prefix check. Covers rewinding to an older
   matching snapshot and installing a divergent suffix. *)
RestoreStaleOrDivergent ==
  /\ AllowRestoreStaleOrDivergent
  /\ backup.present
  /\ phys' = backup.image
  /\ dropped' = 0
  /\ ckpt' = NoneCkpt
  /\ projectId' = backup.pid
  /\ last' = LastRec("restoreStaleOrDivergent", "silent-install", 0)
  /\ pending' = NoneCkpt
  /\ forked' = (forked \/ backup.image # hist \/ backup.pid # projectId)
  /\ UNCHANGED <<epoch, hist, unacked, backup, class4>>

(* Open product choice. Not enabled unless the flag is true.
   Starts a new epoch and adopts the backup as a new history.
   The old live log is not merged. Unacked local work is kept
   but not applied to the new history. *)
ExplicitReplace ==
  /\ AllowExplicitReplace
  /\ backup.present
  /\ epoch' = epoch + 1
  /\ projectId' = backup.pid
  /\ hist' = backup.image
  /\ phys' = backup.image
  /\ dropped' = 0
  /\ ckpt' = NoneCkpt
  /\ last' = LastRec("explicitReplace", "open-product-choice", 0)
  /\ pending' = NoneCkpt
  /\ UNCHANGED <<unacked, backup, class4, forked>>

ExploreStep ==
  Commit \/ Journal \/ FlushUnacked \/ StartCheckpoint
  \/ PersistCheckpoint \/ Checkpoint \/ Compact \/ Backup
  \/ OfferFork \/ OfferMismatch \/ RestoreMatching \/ RejectRestore

Advance(n) == pc' = n

LegalCompactPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ Checkpoint /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ Compact /\ Advance(5)

LegalRestorePath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ Backup /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ RestoreMatching /\ Advance(5)

RejectForkPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ OfferFork /\ Advance(3)
  \/ /\ pc = 3 /\ RejectRestore /\ Advance(4)

RejectIdentityPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ OfferMismatch /\ Advance(2)
  \/ /\ pc = 2 /\ RejectRestore /\ Advance(3)

RejectKeepsJournalPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Journal /\ Advance(2)
  \/ /\ pc = 2 /\ OfferFork /\ Advance(3)
  \/ /\ pc = 3 /\ RejectRestore /\ Advance(4)

CompactThenRestorePath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ Checkpoint /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ Compact /\ Advance(5)
  \/ /\ pc = 5 /\ Backup /\ Advance(6)
  \/ /\ pc = 6 /\ RestoreMatching /\ Advance(7)

CompactBeforeDurablePath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ StartCheckpoint /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ CompactBeforeDurable /\ Advance(5)

CompactUnackedPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ JournalMid /\ Advance(3)
  \/ /\ pc = 3 /\ Checkpoint /\ Advance(4)
  \/ /\ pc = 4 /\ CompactWithUnacked /\ Advance(5)

RestoreStalePath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ Backup /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ RestoreStaleOrDivergent /\ Advance(5)

RestoreDivergentPath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ OfferFork /\ Advance(3)
  \/ /\ pc = 3 /\ RestoreStaleOrDivergent /\ Advance(4)

ExplicitReplacePath ==
  \/ /\ pc = 0 /\ Commit /\ Advance(1)
  \/ /\ pc = 1 /\ Commit /\ Advance(2)
  \/ /\ pc = 2 /\ Backup /\ Advance(3)
  \/ /\ pc = 3 /\ Commit /\ Advance(4)
  \/ /\ pc = 4 /\ Journal /\ Advance(5)
  \/ /\ pc = 5 /\ ExplicitReplace /\ Advance(6)

ScenarioStep ==
  CASE Scenario = "Explore" -> ExploreStep /\ UNCHANGED pc
    [] Scenario = "LegalCompact" -> LegalCompactPath
    [] Scenario = "LegalRestore" -> LegalRestorePath
    [] Scenario = "RejectFork" -> RejectForkPath
    [] Scenario = "RejectIdentity" -> RejectIdentityPath
    [] Scenario = "RejectKeepsJournal" -> RejectKeepsJournalPath
    [] Scenario = "CompactThenRestore" -> CompactThenRestorePath
    [] Scenario = "CompactBeforeDurable" -> CompactBeforeDurablePath
    [] Scenario = "CompactUnacked" -> CompactUnackedPath
    [] Scenario = "RestoreStale" -> RestoreStalePath
    [] Scenario = "RestoreDivergent" -> RestoreDivergentPath
    [] Scenario = "ExplicitReplace" -> ExplicitReplacePath

Next == ScenarioStep \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ projectId \in {"P", "Q"}
  /\ epoch \in 1..3
  /\ Len(hist) <= MaxOps
  /\ Len(phys) <= MaxOps
  /\ dropped \in 0..MaxOps
  /\ ckpt.status \in {"none", "durable"}
  /\ ckpt.rev \in 0..MaxOps
  /\ Len(ckpt.prefix) = ckpt.rev
  /\ pending.status \in {"none", "pending"}
  /\ pending.rev \in 0..MaxOps
  /\ Len(pending.prefix) = pending.rev
  /\ unacked.id \in 0..(MaxOps + 1)
  /\ last.class \in 0..4
  /\ pc \in 0..7

(* A checkpoint write, including making a pending one durable,
   must not itself delete history. *)
CheckpointDoesNotDelete ==
  last.action \in {"checkpoint", "startCheckpoint", "persistCheckpoint"}
    => /\ phys = last.prePhys
       /\ dropped = last.preDropped
       /\ hist = last.preHist
       /\ RecoverableLog = last.preLog

(* After a good compact, checkpoint plus suffix replays to the
   pre-compact project state, and the logical log is unchanged. *)
CompactPreservesState ==
  last.action = "compact" =>
    /\ last.class # 4
    /\ ckpt.status = "durable"
    /\ dropped = ckpt.rev
    /\ RecoverableState = last.preState
    /\ RecoverableLog = last.preLog
    /\ hist = last.preHist
    /\ Replay(ckpt.prefix \o phys) = last.preState
    /\ Replay(ckpt.prefix \o phys) = ckpt.snapshot + Replay(phys)

(* After compact, an unacked base shorter than the dropped prefix
   is no longer verifiable: the checkpoint stores the digest of
   the whole prefix, not every intermediate prefix. *)
UnackedNotStranded ==
  \/ unacked.id = 0
  \/ dropped = 0
  \/ /\ Len(unacked.base) >= dropped
     /\ Prefix(unacked.base, RecoverableLog)

(* In the good protocol the recoverable log is exactly the
   append-only ghost history. *)
RecoverableMatchesHist == RecoverableLog = hist

NoFork == ~forked
NoSilentLiveOverwrite == RecoverableMatchesHist /\ ~forked

RestoreRefusesSafely ==
  last.action = "rejectRestore" =>
    /\ last.class = 4
    /\ class4
    /\ last.reason \in {"identity-mismatch", "fork", "unproven-suffix"}
    /\ phys = last.prePhys
    /\ dropped = last.preDropped
    /\ epoch = last.preEpoch
    /\ unacked = last.preUnacked
    /\ hist = last.preHist
    /\ projectId = last.prePid
    /\ RecoverableLog = last.preLog

UnackedPreservedOnReject ==
  last.action = "rejectRestore" => unacked = last.preUnacked

Class4OnlyOnHardStop ==
  last.class = 4 <=> last.action = "rejectRestore"

CompactNotClass4 ==
  last.action \in {"compact", "compactBeforeDurable",
                   "compactWithUnacked", "checkpoint",
                   "startCheckpoint", "persistCheckpoint",
                   "backup", "commit", "journal", "journalMid",
                   "flush"} => last.class # 4

HistAppendOnly ==
  last.action = "explicitReplace"
    \/ hist = last.preHist
    \/ hist = Append(last.preHist, Len(hist))

(* Conservative v1 bookkeeping only: discarded-prefix operations
   are recorded as not selectively undoable. This is not a
   product default; the choice remains open. *)
PrefixOpsNotSelectivelyUndoable ==
  last.action = "compact" =>
    last.reason = "prefix-selective-undo-left-open"

SafetyOK ==
  /\ TypeOK
  /\ CheckpointDoesNotDelete
  /\ CompactPreservesState
  /\ UnackedNotStranded
  /\ RecoverableMatchesHist
  /\ NoFork
  /\ NoSilentLiveOverwrite
  /\ RestoreRefusesSafely
  /\ UnackedPreservedOnReject
  /\ Class4OnlyOnHardStop
  /\ CompactNotClass4
  /\ HistAppendOnly
  /\ PrefixOpsNotSelectivelyUndoable

NotLegalCompact ==
  ~(/\ last.action = "compact"
    /\ last.class # 4
    /\ ckpt.status = "durable"
    /\ dropped = ckpt.rev
    /\ dropped > 0
    /\ Len(phys) > 0
    /\ Replay(ckpt.prefix \o phys) = last.preState
    /\ RecoverableLog = hist
    /\ RecoverableLog = last.preLog
   )

NotLegalRestore ==
  ~(/\ last.action = "restoreMatching"
    /\ last.class # 4
    /\ backup.present
    /\ backup.pid = projectId
    /\ Prefix(backup.image, RecoverableLog)
    /\ Len(backup.image) < Len(RecoverableLog)
    /\ RecoverableLog = last.preLog
    /\ unacked = last.preUnacked
    /\ epoch = last.preEpoch
    /\ hist = last.preHist
   )

NotRejectFork ==
  ~(/\ last.action = "rejectRestore"
    /\ last.class = 4
    /\ last.reason = "fork"
    /\ RecoverableLog = last.preLog
    /\ unacked = last.preUnacked
    /\ hist = last.preHist
   )

NotRejectIdentity ==
  ~(/\ last.action = "rejectRestore"
    /\ last.class = 4
    /\ last.reason = "identity-mismatch"
    /\ RecoverableLog = last.preLog
    /\ projectId = last.prePid
   )

NotRejectKeepsJournal ==
  ~(/\ last.action = "rejectRestore"
    /\ last.class = 4
    /\ unacked.id # 0
    /\ unacked = last.preUnacked
    /\ RecoverableLog = last.preLog
   )

NotCompactThenRestore ==
  ~(/\ last.action = "restoreMatching"
    /\ dropped > 0
    /\ ckpt.status = "durable"
    /\ backup.present
    /\ Prefix(backup.image, RecoverableLog)
    /\ RecoverableLog = hist
    /\ last.class # 4
   )

NotExplicitReplace ==
  ~(/\ last.action = "explicitReplace"
    /\ epoch = last.preEpoch + 1
    /\ RecoverableLog = backup.image
    /\ last.preHist # backup.image
    /\ unacked = last.preUnacked
    /\ unacked.id # 0
    /\ last.class # 4
   )
=============================================================================
