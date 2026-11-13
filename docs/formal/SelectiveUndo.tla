------------------------- MODULE SelectiveUndo -------------------------
EXTENDS Naturals, Integers, Sequences, FiniteSets, TLC
CONSTANTS Scenario, MaxOps, ValueGuard, SkipCoord, PaletteGuess,
          ColorOnly, DropConflict
VARIABLES grid, w, h, paletteEpoch, projectEpoch, history, undone, audit
vars == <<grid, w, h, paletteEpoch, projectEpoch, history, undone, audit>>
Colors == 0..2
LocalKinds == {"Paint", "Done", "Replace", "Undo"}
NoAudit == [active |-> FALSE]
Identity(n) == [i \in 1..n |-> i]
Cell(c, d, v, id) == [c |-> c, d |-> d, v |-> v, id |-> id]
InitialGrid == [i \in 1..6 |-> Cell(IF i = 5 THEN 0 ELSE IF i = 6 THEN 2 ELSE 1,
                                    i = 1, 0, i)]
Init == /\ grid = InitialGrid /\ w = 3 /\ h = 2
        /\ paletteEpoch = 0 /\ projectEpoch = 0
        /\ history = <<>> /\ undone = {} /\ audit = NoAudit
NextId == Len(history) + 1
AllowedColors == IF paletteEpoch = 0 THEN Colors ELSE {0, 1}
Record(kind, next, nw, nh, mp, fp, pe, ep) ==
  [kind |-> kind, before |-> grid, after |-> next, footprint |-> fp,
   map |-> mp, oldW |-> w, oldH |-> h, newW |-> nw, newH |-> nh,
   palette |-> pe, project |-> ep, id |-> NextId,
   author |-> IF NextId=1 THEN "Agent" ELSE "Human"]
AppendOp(kind, next, nw, nh, mp, fp, pe, ep) ==
  /\ history' = Append(history, Record(kind, next, nw, nh, mp, fp, pe, ep))
  /\ grid' = next /\ w' = nw /\ h' = nh
  /\ paletteEpoch' = pe /\ projectEpoch' = ep
  /\ UNCHANGED <<undone, audit>>
Paint(S, c, kind) ==
  LET changed == {i \in S : grid[i].c # c}
      next == [i \in DOMAIN grid |-> IF i \in changed
                THEN Cell(c, FALSE, NextId, grid[i].id) ELSE grid[i]]
  IN /\ S \subseteq DOMAIN grid /\ c \in AllowedColors /\ changed # {}
     /\ AppendOp(kind, next, w, h, Identity(w*h), changed,
                  paletteEpoch, projectEpoch)
Done(i) ==
  /\ i \in DOMAIN grid /\ grid[i].c # 0
  /\ AppendOp("Done", [grid EXCEPT ![i] = Cell(@.c, ~@.d, NextId, @.id)],
               w, h, Identity(w*h), {i}, paletteEpoch, projectEpoch)
Replace(a,b) == Paint({i \in DOMAIN grid : grid[i].c = a}, b, "Replace")
X(i) == (i-1) % w
Y(i) == (i-1) \div w
Geom(kind) ==
  LET nw == IF kind = "Rotate" THEN h ELSE w
      nh == IF kind = "Rotate" THEN w ELSE h
      mp == [i \in DOMAIN grid |->
        IF kind = "Rotate" THEN X(i)*nw + (nw-1-Y(i)) + 1
        ELSE IF kind = "FlipH" THEN Y(i)*nw + (nw-1-X(i)) + 1
        ELSE (nh-1-Y(i))*nw + X(i) + 1]
      next == [j \in 1..(nw*nh) |-> grid[CHOOSE i \in DOMAIN grid : mp[i]=j]]
  IN AppendOp(kind, next, nw, nh, mp, DOMAIN grid, paletteEpoch, projectEpoch)
Crop ==
  LET nw == w-1
      mp == [i \in DOMAIN grid |-> IF X(i) < nw THEN Y(i)*nw+X(i)+1 ELSE 0]
      next == [j \in 1..(nw*h) |-> grid[CHOOSE i \in DOMAIN grid : mp[i]=j]]
  IN /\ w > 1
     /\ AppendOp("Crop", next, nw, h, mp, DOMAIN next, paletteEpoch, projectEpoch)
PaletteMap ==
  LET next == [i \in DOMAIN grid |-> IF grid[i].c = 2
                 THEN Cell(1, grid[i].d, NextId, grid[i].id) ELSE grid[i]]
  IN /\ paletteEpoch = 0
     /\ AppendOp("Palette", next, w, h, Identity(w*h), DOMAIN grid,
                  paletteEpoch+1, projectEpoch)
ProjectReplace ==
  LET next == [i \in 1..6 |-> Cell(1, FALSE, NextId, 6*(NextId+1)+i)]
  IN AppendOp("Project", next, 3, 2, [i \in DOMAIN grid |-> 0], DOMAIN grid,
               paletteEpoch, projectEpoch+1)

\* Production-style mapping: compose every subsequent positional map.
RECURSIVE Lift(_,_,_)
Lift(p, j, n) == IF p = 0 \/ j > n THEN p
                 ELSE Lift(history[j].map[p], j+1, n)
Mapped(k,p) == IF SkipCoord THEN (IF p \in DOMAIN grid THEN p ELSE 0)
               ELSE Lift(p, k+1, Len(history))
\* Independent reference: stable identities, never calls Lift or Geom.
RefPosition(k,p) ==
  LET matches == {q \in DOMAIN grid : grid[q].id = history[k].after[p].id}
  IN IF matches = {} THEN 0 ELSE CHOOSE q \in matches : TRUE
PairEqual(a,b) == a.c=b.c /\ a.d=b.d
Supported(k) == history[k].kind \in LocalKinds \ {"Undo"}
                \/ (PaletteGuess /\ history[k].kind = "Palette")
BarrierFree(k) == history[k].project = projectEpoch
                  /\ history[k].palette = paletteEpoch
RefSafe(k,p) ==
  LET q == RefPosition(k,p)
  IN Supported(k) /\ BarrierFree(k) /\ q # 0
     /\ IF q=0 THEN FALSE ELSE grid[q].v = history[k].after[p].v
Guard(k,p) ==
  LET q == Mapped(k,p)
  IN Supported(k) /\ BarrierFree(k) /\ q # 0
     /\ IF q=0 THEN FALSE
        ELSE IF ValueGuard THEN PairEqual(grid[q], history[k].after[p])
             ELSE grid[q].v = history[k].after[p].v
Reason(k,p) ==
  IF ~Supported(k) THEN "unsupported"
  ELSE IF history[k].project # projectEpoch THEN "project-replaced"
  ELSE IF history[k].palette # paletteEpoch THEN "palette-barrier"
  ELSE IF RefPosition(k,p)=0 THEN "cropped"
  ELSE "stale-version"

\* Independent replay oracle: replay committed effects, NOT UI commands.
\* Local predicates (fill/replace/toggle) have already been materialized.
\* Structural layout is reconstructed from stable identity, not Lift/map.
PairGrid(g) == [q \in DOMAIN g |-> <<g[q].c, g[q].d>>]
RefApply(g, rec) ==
  IF rec.kind \in LocalKinds THEN
    [q \in DOMAIN g |-> IF q \in rec.footprint
       THEN Cell(rec.after[q].c, rec.after[q].d, rec.after[q].v, g[q].id)
       ELSE g[q]]
  ELSE IF rec.kind="Project" THEN rec.after
  ELSE IF rec.kind="Palette" THEN
    [q \in DOMAIN g |-> Cell(IF g[q].c=2 THEN 1 ELSE g[q].c,
                             g[q].d, g[q].v, g[q].id)]
  ELSE [q \in DOMAIN rec.after |->
    g[CHOOSE p \in DOMAIN g : g[p].id=rec.after[q].id]]
RECURSIVE ReplayWithout(_, _)
ReplayWithout(k,n) == IF n=0 THEN InitialGrid
                     ELSE IF n=k THEN ReplayWithout(k,n-1)
                     ELSE RefApply(ReplayWithout(k,n-1),history[n])


\* A diagnostic oracle, intentionally re-executing the Replace predicate.
\* Its disagreement is a documented policy boundary, not a production fix.
RawApply(g,rec) ==
  IF rec.kind="Replace" THEN
    LET p == CHOOSE p \in rec.footprint : TRUE
        from == rec.before[p].c
        to == rec.after[p].c
    IN [q \in DOMAIN g |-> IF g[q].c=from
          THEN Cell(to,FALSE,g[q].v,g[q].id) ELSE g[q]]
  ELSE RefApply(g,rec)
RECURSIVE RawWithout(_, _)
RawWithout(k,n) == IF n=0 THEN InitialGrid
                  ELSE IF n=k THEN RawWithout(k,n-1)
                  ELSE RawApply(RawWithout(k,n-1),history[n])

SelectiveUndo(k) ==
  LET rec == history[k]
      accepted == {p \in rec.footprint : Guard(k,p)}
      safe == {p \in rec.footprint : RefSafe(k,p)}
      dests == {Mapped(k,p) : p \in accepted}
      refDests == {RefPosition(k,p) : p \in safe}
      rejected == rec.footprint \ accepted
      reported == IF DropConflict THEN {} ELSE rejected
      next == [q \in DOMAIN grid |->
        IF q \in dests THEN
          LET p == CHOOSE p \in accepted : Mapped(k,p)=q
              c == IF PaletteGuess /\ rec.kind="Palette"
                   THEN (IF grid[q].c=1 THEN 2 ELSE grid[q].c)
                   ELSE rec.before[p].c
              d == IF ColorOnly THEN grid[q].d ELSE rec.before[p].d
          IN Cell(c, d, NextId, grid[q].id)
        ELSE grid[q]]
      aba == {p \in rec.footprint :
        LET q == RefPosition(k,p)
        IN IF q=0 THEN FALSE ELSE
             grid[q].v # rec.after[p].v /\ PairEqual(grid[q], rec.after[p])}
  IN /\ k \in 1..Len(history) /\ k \notin undone /\ rec.kind # "Undo"
     /\ history' = Append(history, Record("Undo", next, w, h, Identity(w*h),
                                         dests, paletteEpoch, projectEpoch))
     /\ grid' = next /\ undone' = undone \cup {k}
     /\ audit' = [active |-> TRUE, target |-> k, kind |-> rec.kind,
          accepted |-> accepted, safe |-> safe, rejected |-> rejected,
          reported |-> reported, reasons |-> [p \in rejected |-> Reason(k,p)],
          dests |-> dests, refDests |-> refDests,
          positions |-> [p \in rec.footprint |-> RefPosition(k,p)],
          before |-> grid, after |-> next, sourceBefore |-> rec.before,
          sourceAfter |-> rec.after, aba |-> aba, undoVersion |-> NextId,
          replay |-> IF rec.kind \in LocalKinds \ {"Undo"}
                     THEN ReplayWithout(k,Len(history)) ELSE grid,
          status |-> IF reported={} THEN "success"
                     ELSE IF accepted={} THEN "conflict" ELSE "partial"]
     /\ UNCHANGED <<w, h, paletteEpoch, projectEpoch>>

ExploreStep ==
  \/ \E S \in {{1}, {w*h}, {1,w*h}}, c \in AllowedColors : Paint(S,c,"Paint")
  \/ \E i \in {1,w*h} : Done(i)
  \/ \E a,b \in AllowedColors : Replace(a,b)
  \/ Geom("Rotate") \/ Geom("FlipH") \/ Geom("FlipV")
  \/ Crop \/ PaletteMap \/ ProjectReplace
  \/ \E k \in 1..Len(history) : SelectiveUndo(k)
ABAPath == CASE Len(history)=0 -> Paint({1},2,"Paint")
             [] Len(history)=1 -> Paint({1},0,"Paint")
             [] Len(history)=2 -> Paint({1},2,"Paint")
             [] OTHER -> SelectiveUndo(1)
RotatePath == CASE Len(history)=0 -> Paint({1,w*h},2,"Paint")
                [] Len(history)=1 -> Geom("Rotate")
                [] Len(history)=2 -> Paint({w*h},0,"Paint")
                [] OTHER -> SelectiveUndo(1)
FlipPath(kind) == CASE Len(history)=0 -> Paint({1},2,"Paint")
                   [] Len(history)=1 -> Geom(kind)
                   [] Len(history)=2 -> Paint({w*h},0,"Paint")
                   [] OTHER -> SelectiveUndo(1)
ChainPath == CASE Len(history)=0 -> Paint({1,w*h},0,"Paint")
              [] Len(history)=1 -> Geom("Rotate")
              [] Len(history)=2 -> Geom("FlipV")
              [] Len(history)=3 -> Crop
              [] OTHER -> SelectiveUndo(1)
ReadDependencyPath == CASE Len(history)=0 -> Paint({1},2,"Paint")
                       [] Len(history)=1 -> Replace(1,0)
                       [] OTHER -> SelectiveUndo(1)
PartialPath == CASE Len(history)=0 -> Paint({1,w*h},0,"Paint")
                 [] Len(history)=1 -> Paint({w*h},1,"Paint")
                 [] OTHER -> SelectiveUndo(1)
CropPath == CASE Len(history)=0 -> Paint({1,w*h},0,"Paint")
              [] Len(history)=1 -> Crop
              [] OTHER -> SelectiveUndo(1)
PalettePath == CASE Len(history)=0 -> Paint({1},2,"Paint")
                 [] Len(history)=1 -> PaletteMap
                 [] OTHER -> SelectiveUndo(1)
PaletteInversePath == IF Len(history)=0 THEN PaletteMap ELSE SelectiveUndo(1)
DonePath == IF Len(history)=0 THEN Paint({1},2,"Paint") ELSE SelectiveUndo(1)
ProjectPath == CASE Len(history)=0 -> Paint({1},2,"Paint")
                 [] Len(history)=1 -> ProjectReplace
                 [] OTHER -> SelectiveUndo(1)
RepeatPath == CASE Len(history)=0 -> Paint({1},2,"Paint")
                [] Len(history)=1 -> Paint({w*h},1,"Paint")
                [] Len(history)=2 -> SelectiveUndo(1)
                [] OTHER -> SelectiveUndo(2)
ScenarioStep == CASE Scenario="Explore" -> ExploreStep
                 [] Scenario="ABA" -> ABAPath
                 [] Scenario="Rotate" -> RotatePath
                 [] Scenario="FlipH" -> FlipPath("FlipH")
                 [] Scenario="FlipV" -> FlipPath("FlipV")
                 [] Scenario="Chain" -> ChainPath
                 [] Scenario="ReadDependency" -> ReadDependencyPath
                 [] Scenario="Partial" -> PartialPath
                 [] Scenario="Crop" -> CropPath
                 [] Scenario="Palette" -> PalettePath
                 [] Scenario="PaletteInverse" -> PaletteInversePath
                 [] Scenario="Done" -> DonePath
                 [] Scenario="Project" -> ProjectPath
                 [] Scenario="Repeat" -> RepeatPath
Next == \/ /\ Len(history) < MaxOps /\ ScenarioStep
        \/ /\ Len(history) = MaxOps /\ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK == /\ w \in 1..3 /\ h \in 1..3 /\ DOMAIN grid=1..(w*h)
          /\ \A q \in DOMAIN grid :
               /\ grid[q].c \in AllowedColors /\ grid[q].d \in BOOLEAN
               /\ grid[q].v \in 0..Len(history) /\ grid[q].id \in Nat
          /\ Cardinality({grid[q].id : q \in DOMAIN grid}) = w*h
NoSilentOverwrite == IF ~audit.active THEN TRUE ELSE audit.accepted \subseteq audit.safe
PreserveLaterEdits == IF ~audit.active THEN TRUE ELSE
  \A q \in DOMAIN audit.before \ audit.refDests : audit.after[q] = audit.before[q]
CorrectInverse == IF ~audit.active THEN TRUE ELSE
  /\ audit.accepted = audit.safe
  /\ IF audit.kind \in LocalKinds \ {"Undo"} /\ audit.rejected={}
      THEN PairGrid(audit.after)=PairGrid(audit.replay) ELSE TRUE
  /\ \A p \in audit.accepted :
       LET q == audit.positions[p]
       IN /\ q # 0
          /\ PairEqual(audit.after[q],audit.sourceBefore[p])
          /\ audit.after[q].v = audit.undoVersion
          /\ audit.after[q].id = audit.sourceAfter[p].id
          /\ audit.after[q].v > audit.before[q].v
          /\ IF audit.kind \in LocalKinds \ {"Undo"}
              THEN PairEqual(audit.after[q],audit.replay[q]) ELSE TRUE
ColorDoneConsistency == \A q \in DOMAIN grid : grid[q].c=0 => ~grid[q].d
ConflictReported == IF ~audit.active THEN TRUE ELSE
  /\ audit.reported = audit.rejected
  /\ (audit.status="success" <=> audit.rejected={})
  /\ (audit.status="partial" <=> (audit.accepted # {} /\ audit.rejected # {}))
  /\ DOMAIN audit.reasons = audit.rejected
  /\ \A p \in audit.rejected : audit.reasons[p] \in
       {"unsupported","project-replaced","palette-barrier","cropped","stale-version"}
ABADetected == IF ~audit.active THEN TRUE ELSE
  audit.aba \subseteq (audit.rejected \cap audit.reported)

WitnessPartial == IF ~audit.active THEN FALSE ELSE
                   audit.accepted # {} /\ audit.rejected # {}
WitnessRotate == IF ~audit.active THEN FALSE ELSE
                  audit.accepted # {} /\ \E j \in 1..Len(history): history[j].kind="Rotate"
WitnessFlip == IF ~audit.active THEN FALSE ELSE
                audit.accepted # {} /\ \E j \in 1..Len(history): history[j].kind \in {"FlipH","FlipV"}
WitnessConflict == IF ~audit.active THEN FALSE ELSE audit.reported # {}
WitnessABA == IF ~audit.active THEN FALSE ELSE audit.aba # {} /\ audit.aba \subseteq audit.reported
WitnessRestore == IF ~audit.active THEN FALSE ELSE audit.accepted # {}
WitnessRepeat == Cardinality(undone)=2
WitnessRawReplayGap == IF ~audit.active THEN FALSE ELSE
  audit.kind \in LocalKinds \ {"Undo"} /\ audit.rejected={} /\
  PairGrid(audit.after) # PairGrid(RawWithout(audit.target,audit.undoVersion-1))
NotRawReplayGap == ~WitnessRawReplayGap
NotPartial == ~WitnessPartial
NotRotate == ~WitnessRotate
NotFlip == ~WitnessFlip
NotConflict == ~WitnessConflict
NotABA == ~WitnessABA
NotRestore == ~WitnessRestore
NotRepeat == ~WitnessRepeat
=============================================================================
