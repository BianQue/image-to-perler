-------------------------- MODULE Collaboration --------------------------
EXTENDS Naturals, TLC
CONSTANT Bug
VARIABLES cells, versions, diskCells, diskVersions, phase, base, before,
          afterVersion, humanSteps, durableOp, ack, crashed, structure,
          baseStructure, bad
vars == <<cells, versions, diskCells, diskVersions, phase, base, before,
          afterVersion, humanSteps, durableOp, ack, crashed, structure,
          baseStructure, bad>>

Init ==
  /\ cells = <<0, 0>> /\ versions = <<0, 0>>
  /\ diskCells = cells /\ diskVersions = versions
  /\ phase = "idle" /\ base = versions /\ before = 0
  /\ afterVersion = 0 /\ humanSteps = 0
  /\ durableOp = FALSE /\ ack = FALSE /\ crashed = FALSE
  /\ structure = 0 /\ baseStructure = 0 /\ bad = FALSE

Plan ==
  /\ phase = "idle"
  /\ phase' = "planned" /\ base' = versions
  /\ before' = cells[1] /\ baseStructure' = structure
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, afterVersion,
                 humanSteps, durableOp, ack, crashed, structure, bad>>

\* Two committed human edits allow the ABA (change then change back) case.
Human ==
  /\ phase \in {"idle", "planned", "committed"}
  /\ humanSteps < 2
  /\ \E i \in 1..2:
       /\ cells' = [cells EXCEPT ![i] = 1 - @]
       /\ versions' = [versions EXCEPT ![i] = @ + 1]
  /\ diskCells' = cells' /\ diskVersions' = versions'
  /\ humanSteps' = humanSteps + 1
  /\ UNCHANGED <<phase, base, before, afterVersion, durableOp, ack,
                 crashed, structure, baseStructure, bad>>

StructuralChange ==
  /\ phase \in {"planned", "committed"} /\ structure = 0
  /\ structure' = 1
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, phase, base,
                 before, afterVersion, humanSteps, durableOp, ack,
                 crashed, baseStructure, bad>>

\* This operation reads and writes cell 1; cell 2 is independent.
Fresh == versions[1] = base[1] /\ structure = baseStructure
Prepare ==
  /\ phase = "planned"
  /\ Fresh \/ Bug = "staleCommit"
  /\ phase' = "prepared"
  /\ bad' = (bad \/ ~Fresh)
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, base, before,
                 afterVersion, humanSteps, durableOp, ack, crashed,
                 structure, baseStructure>>
Reject ==
  /\ phase = "planned" /\ ~Fresh /\ Bug # "staleCommit"
  /\ phase' = "conflict"
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, base, before,
                 afterVersion, humanSteps, durableOp, ack, crashed,
                 structure, baseStructure, bad>>

\* A prepared transaction excludes competing commits until persistence.
\* Project state, operation identity and history are one durable unit.
Persist ==
  /\ phase = "prepared"
  /\ diskCells' = [cells EXCEPT ![1] = 1 - @]
  /\ diskVersions' = [versions EXCEPT ![1] = @ + 1]
  /\ afterVersion' = versions[1] + 1
  /\ durableOp' = TRUE /\ phase' = "persisted"
  /\ UNCHANGED <<cells, versions, base, before, humanSteps, ack, crashed,
                 structure, baseStructure, bad>>
Publish ==
  /\ phase = "persisted"
  /\ cells' = diskCells /\ versions' = diskVersions
  /\ phase' = "committed" /\ ack' = TRUE
  /\ UNCHANGED <<diskCells, diskVersions, base, before, afterVersion,
                 humanSteps, durableOp, crashed, structure, baseStructure, bad>>
EarlyAck ==
  /\ Bug = "earlyAck" /\ phase = "prepared"
  /\ ack' = TRUE
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, phase, base,
                 before, afterVersion, humanSteps, durableOp, crashed,
                 structure, baseStructure, bad>>
CrashRecover ==
  /\ ~crashed
  /\ crashed' = TRUE /\ cells' = diskCells /\ versions' = diskVersions
  /\ phase' = IF phase \in {"prepared", "persisted"}
               THEN IF durableOp THEN "committed" ELSE "planned"
               ELSE phase
  /\ UNCHANGED <<diskCells, diskVersions, base, before, afterVersion,
                 humanSteps, durableOp, ack, structure, baseStructure, bad>>
Retry ==
  /\ durableOp /\ phase = "committed"
  /\ ack' = TRUE
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, phase, base,
                 before, afterVersion, humanSteps, durableOp, crashed,
                 structure, baseStructure, bad>>

UndoSafe == versions[1] = afterVersion /\ structure = baseStructure
UndoGuard == IF Bug = "valueUndo"
             THEN cells[1] = 1 - before /\ structure = baseStructure
             ELSE UndoSafe
Undo ==
  /\ phase = "committed" /\ UndoGuard
  /\ cells' = [cells EXCEPT ![1] = before]
  /\ versions' = [versions EXCEPT ![1] = @ + 1]
  /\ diskCells' = cells' /\ diskVersions' = versions'
  /\ phase' = "undone"
  /\ bad' = (bad \/ ~UndoSafe)
  /\ UNCHANGED <<base, before, afterVersion, humanSteps, durableOp, ack,
                 crashed, structure, baseStructure>>
UndoConflict ==
  /\ phase = "committed" /\ ~UndoGuard
  /\ phase' = "undoConflict"
  /\ UNCHANGED <<cells, versions, diskCells, diskVersions, base, before,
                 afterVersion, humanSteps, durableOp, ack, crashed,
                 structure, baseStructure, bad>>
Next == Plan \/ Human \/ StructuralChange \/ Prepare \/ Reject \/
        Persist \/ Publish \/ EarlyAck \/ CrashRecover \/ Retry \/
        Undo \/ UndoConflict
Spec == Init /\ [][Next]_vars
NoSilentOverwrite == ~bad
AcknowledgedIsDurable == ack => durableOp
ConsistentPublishedState ==
  phase # "persisted" => cells = diskCells /\ versions = diskVersions
TypeOK ==
  /\ cells \in [1..2 -> 0..1] /\ versions \in [1..2 -> 0..4]
  /\ humanSteps \in 0..2
=============================================================================
