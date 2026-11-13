---------------------------- MODULE PreviewAccept ----------------------------
(*
  Protocol-hazard model: the Agent only previews a resolution plan;
  the human chooses whether to accept. Preview lives in an overlay.
  Accept must re-derive compensation against the current log prefix.

  AllowStaleAccept enables the forbidden AcceptStale action, which
  applies a compensation computed on an old prefix without rebasing.

  Stale-policy choice is left open: after a proposal becomes stale,
  both RePreview and Reclassify are legal. Applying the old
  compensation is not.

  Class 4 is never assigned by preview machinery. Typed conflicts
  stay in classes 1-3. This is a model, not an application feature.
*)
EXTENDS Naturals, Integers, Sequences, FiniteSets, TLC
CONSTANTS Scenario, MaxOps, MaxMeta, AllowStaleAccept
VARIABLES grid, w, h, paletteEpoch, projectEpoch, history, undone,
          proposal, last, metaCount, class4, forked
vars == <<grid, w, h, paletteEpoch, projectEpoch, history, undone,
          proposal, last, metaCount, class4, forked>>

Colors == 0..2
Cell(c, d, v, id) == [c |-> c, d |-> d, v |-> v, id |-> id]
Identity(n) == [i \in 1..n |-> i]
InitialGrid == [i \in 1..6 |-> Cell(IF i = 5 THEN 0 ELSE IF i = 6 THEN 2 ELSE 1,
                                    i = 1, 0, i)]
AllowedColors == IF paletteEpoch = 0 THEN Colors ELSE {0, 1}
NextId == Len(history) + 1
SupportedKind(kind) == kind \in {"Paint", "Done", "Replace", "Compensate"}
PairEqual(a, b) == a.c = b.c /\ a.d = b.d
PairGrid(g) == [q \in DOMAIN g |-> <<g[q].c, g[q].d>>]

EmptyFn == [p \in {} |-> 0]
EmptyRestore == [p \in {} |-> [c |-> 0, d |-> FALSE]]
EmptyReasons == [p \in {} |-> "none"]
NoProposal ==
  [active |-> FALSE, target |-> 0, prefixLen |-> 0,
   accepted |-> {}, safe |-> {}, dests |-> {}, rejected |-> {},
   destOf |-> EmptyFn, restore |-> EmptyRestore,
   reasons |-> EmptyReasons, class |-> 0]
LastRec(act, cls, tgt, dests, reDests, acc, reAcc, safe, refD, coll) ==
  [action |-> act, class |-> cls, target |-> tgt,
   dests |-> dests, rederivedDests |-> reDests,
   accepted |-> acc, rederivedAccepted |-> reAcc,
   safe |-> safe, refDests |-> refD, collateral |-> coll,
   logLen |-> Len(history), grid |-> grid, w |-> w, h |-> h,
   palette |-> paletteEpoch, project |-> projectEpoch, undone |-> undone]

Init ==
  /\ grid = InitialGrid /\ w = 3 /\ h = 2
  /\ paletteEpoch = 0 /\ projectEpoch = 0
  /\ history = <<>> /\ undone = {}
  /\ proposal = NoProposal
  /\ last = LastRec("init", 0, 0, {}, {}, {}, {}, {}, {}, {})
  /\ metaCount = 0 /\ class4 = FALSE /\ forked = FALSE

Record(kind, next, nw, nh, mp, fp, pe, ep, author, inv) ==
  [kind |-> kind, before |-> grid, after |-> next, footprint |-> fp,
   map |-> mp, oldW |-> w, oldH |-> h, newW |-> nw, newH |-> nh,
   palette |-> pe, project |-> ep, id |-> NextId,
   author |-> author, inverseOf |-> inv]

AppendEdit(kind, next, nw, nh, mp, fp, pe, ep, author) ==
  /\ history' = Append(history, Record(kind, next, nw, nh, mp, fp, pe, ep, author, 0))
  /\ grid' = next /\ w' = nw /\ h' = nh
  /\ paletteEpoch' = pe /\ projectEpoch' = ep
  /\ last' = LastRec("edit", 0, 0, {}, {}, {}, {}, {}, {}, {})
  /\ UNCHANGED <<undone, proposal, metaCount, class4, forked>>

Paint(S, c, kind, author) ==
  LET changed == {i \in S : grid[i].c # c}
      next == [i \in DOMAIN grid |-> IF i \in changed
                THEN Cell(c, FALSE, NextId, grid[i].id) ELSE grid[i]]
  IN /\ S \subseteq DOMAIN grid /\ c \in AllowedColors /\ changed # {}
     /\ Len(history) < MaxOps
     /\ AppendEdit(kind, next, w, h, Identity(w*h), changed,
                   paletteEpoch, projectEpoch, author)

Done(i, author) ==
  /\ i \in DOMAIN grid /\ grid[i].c # 0 /\ Len(history) < MaxOps
  /\ AppendEdit("Done", [grid EXCEPT ![i] = Cell(@.c, ~@.d, NextId, @.id)],
                w, h, Identity(w*h), {i}, paletteEpoch, projectEpoch, author)

Replace(a, b, author) == Paint({i \in DOMAIN grid : grid[i].c = a}, b, "Replace", author)

X(i) == (i-1) % w
Y(i) == (i-1) \div w
Geom(kind, author) ==
  LET nw == IF kind = "Rotate" THEN h ELSE w
      nh == IF kind = "Rotate" THEN w ELSE h
      mp == [i \in DOMAIN grid |->
        IF kind = "Rotate" THEN X(i)*nw + (nw-1-Y(i)) + 1
        ELSE IF kind = "FlipH" THEN Y(i)*nw + (nw-1-X(i)) + 1
        ELSE (nh-1-Y(i))*nw + X(i) + 1]
      next == [j \in 1..(nw*nh) |-> grid[CHOOSE i \in DOMAIN grid : mp[i]=j]]
  IN /\ Len(history) < MaxOps
     /\ AppendEdit(kind, next, nw, nh, mp, DOMAIN grid,
                   paletteEpoch, projectEpoch, author)

Crop(author) ==
  LET nw == w-1
      mp == [i \in DOMAIN grid |-> IF X(i) < nw THEN Y(i)*nw+X(i)+1 ELSE 0]
      next == [j \in 1..(nw*h) |-> grid[CHOOSE i \in DOMAIN grid : mp[i]=j]]
  IN /\ w > 1 /\ Len(history) < MaxOps
     /\ AppendEdit("Crop", next, nw, h, mp, DOMAIN next,
                   paletteEpoch, projectEpoch, author)

PaletteMap(author) ==
  LET next == [i \in DOMAIN grid |-> IF grid[i].c = 2
                 THEN Cell(1, grid[i].d, NextId, grid[i].id) ELSE grid[i]]
  IN /\ paletteEpoch = 0 /\ Len(history) < MaxOps
     /\ AppendEdit("Palette", next, w, h, Identity(w*h), DOMAIN grid,
                   paletteEpoch+1, projectEpoch, author)

ProjectReplace(author) ==
  LET next == [i \in 1..6 |-> Cell(1, FALSE, NextId, 6*(NextId+1)+i)]
  IN /\ Len(history) < MaxOps
     /\ AppendEdit("Project", next, 3, 2, [i \in DOMAIN grid |-> 0],
                   DOMAIN grid, paletteEpoch, projectEpoch+1, author)

RECURSIVE Lift(_, _, _)
Lift(p, j, n) == IF p = 0 \/ j > n THEN p ELSE Lift(history[j].map[p], j+1, n)
Mapped(k, p) == Lift(p, k+1, Len(history))
RefPositionOn(k, p, g) ==
  LET matches == {q \in DOMAIN g : g[q].id = history[k].after[p].id}
  IN IF matches = {} THEN 0 ELSE CHOOSE q \in matches : TRUE
RefPosition(k, p) == RefPositionOn(k, p, grid)
Supported(k) == SupportedKind(history[k].kind)
BarrierFree(k) == history[k].project = projectEpoch
                  /\ history[k].palette = paletteEpoch
RefSafeOn(k, p, g) ==
  LET q == RefPositionOn(k, p, g)
  IN Supported(k) /\ history[k].project = projectEpoch
     /\ history[k].palette = paletteEpoch
     /\ q # 0 /\ g[q].v = history[k].after[p].v
RefSafe(k, p) == RefSafeOn(k, p, grid)
Guard(k, p) ==
  LET q == Mapped(k, p)
  IN Supported(k) /\ BarrierFree(k) /\ q # 0
     /\ IF q = 0 THEN FALSE ELSE grid[q].v = history[k].after[p].v
Reason(k, p) ==
  IF ~Supported(k) THEN "unsupported"
  ELSE IF history[k].project # projectEpoch THEN "project-replaced"
  ELSE IF history[k].palette # paletteEpoch THEN "palette-barrier"
  ELSE IF RefPosition(k, p) = 0 THEN "cropped"
  ELSE "stale-version"
FullySafeOn(k, g) ==
  history[k].footprint # {}
  /\ \A p \in history[k].footprint : RefSafeOn(k, p, g)
FullySafe(k) == FullySafeOn(k, grid)
PlanClass(acc, rej, reasons) ==
  IF rej = {} THEN 1
  ELSE IF acc # {} THEN 2
  ELSE IF \E p \in rej : reasons[p] \in
            {"palette-barrier", "stale-version", "unsupported", "project-replaced"}
       THEN 3
  ELSE 2

Plan(k) ==
  LET rec == history[k]
      acc == {p \in rec.footprint : Guard(k, p)}
      safe == {p \in rec.footprint : RefSafe(k, p)}
      dests == {Mapped(k, p) : p \in acc}
      refD == {RefPosition(k, p) : p \in safe}
      rej == rec.footprint \ acc
      reasons == [p \in rej |-> Reason(k, p)]
      next == [q \in DOMAIN grid |->
        IF q \in dests THEN
          LET p == CHOOSE p \in acc : Mapped(k, p) = q
          IN Cell(rec.before[p].c, rec.before[p].d, NextId, grid[q].id)
        ELSE grid[q]]
      cls == PlanClass(acc, rej, reasons)
  IN [accepted |-> acc, safe |-> safe, dests |-> dests, refDests |-> refD,
      rejected |-> rej, reasons |-> reasons, next |-> next, class |-> cls,
      destOf |-> [p \in acc |-> Mapped(k, p)],
      restore |-> [p \in acc |-> [c |-> rec.before[p].c, d |-> rec.before[p].d]]]

IsStale == proposal.active /\ proposal.prefixLen # Len(history)
CanMeta == metaCount < MaxMeta

MakeProposal(k, plan, act) ==
  /\ proposal' = [active |-> TRUE, target |-> k, prefixLen |-> Len(history),
                  accepted |-> plan.accepted, safe |-> plan.safe,
                  dests |-> plan.dests, rejected |-> plan.rejected,
                  destOf |-> plan.destOf, restore |-> plan.restore,
                  reasons |-> plan.reasons, class |-> plan.class]
  /\ last' = LastRec(act, plan.class, k, plan.dests, plan.dests,
                     plan.accepted, plan.accepted, plan.safe,
                     plan.refDests, {})
  /\ metaCount' = metaCount + 1
  /\ UNCHANGED <<grid, w, h, paletteEpoch, projectEpoch, history, undone,
                 class4, forked>>

Preview(k) ==
  /\ CanMeta
  /\ k \in 1..Len(history) /\ k \notin undone
  /\ LET plan == Plan(k)
         act == IF proposal.active THEN "repreview" ELSE "preview"
     IN MakeProposal(k, plan, act)

Reject ==
  /\ CanMeta /\ proposal.active
  /\ proposal' = NoProposal
  /\ last' = LastRec("reject", 0, 0, {}, {}, {}, {}, {}, {}, {})
  /\ metaCount' = metaCount + 1
  /\ UNCHANGED <<grid, w, h, paletteEpoch, projectEpoch, history, undone,
                 class4, forked>>

Reclassify ==
  /\ CanMeta /\ proposal.active
  /\ LET k == proposal.target
         plan == Plan(k)
     IN /\ proposal' = NoProposal
        /\ last' = LastRec("reclassify", plan.class, k, {}, plan.dests,
                           {}, plan.accepted, plan.safe, plan.refDests, {})
        /\ metaCount' = metaCount + 1
        /\ UNCHANGED <<grid, w, h, paletteEpoch, projectEpoch, history,
                       undone, class4, forked>>

AcceptRebased ==
  /\ CanMeta /\ proposal.active
  /\ LET k == proposal.target
         plan == Plan(k)
     IN IF plan.accepted # {}
        THEN /\ Len(history) < MaxOps
             /\ history' = Append(history,
                  Record("Compensate", plan.next, w, h, Identity(w*h),
                         plan.dests, paletteEpoch, projectEpoch, "Human", k))
             /\ grid' = plan.next
             /\ undone' = undone \cup {k}
             /\ proposal' = NoProposal
             /\ last' = LastRec("acceptRebased", plan.class, k,
                                plan.dests, plan.dests, plan.accepted,
                                plan.accepted, plan.safe, plan.refDests, {})
             /\ metaCount' = metaCount + 1
             /\ UNCHANGED <<w, h, paletteEpoch, projectEpoch, class4, forked>>
        ELSE /\ proposal' = proposal
             /\ last' = LastRec("conflict", plan.class, k, {}, plan.dests,
                                {}, plan.accepted, plan.safe, plan.refDests, {})
             /\ metaCount' = metaCount + 1
             /\ UNCHANGED <<grid, w, h, paletteEpoch, projectEpoch, history,
                            undone, class4, forked>>

AcceptStale ==
  /\ AllowStaleAccept
  /\ CanMeta /\ proposal.active /\ proposal.accepted # {}
  /\ Len(history) < MaxOps
  /\ LET k == proposal.target
         dests == {d \in proposal.dests : d \in DOMAIN grid}
         next == [q \in DOMAIN grid |->
           IF q \in dests THEN
             LET p == CHOOSE p \in proposal.accepted : proposal.destOf[p] = q
             IN Cell(proposal.restore[p].c, proposal.restore[p].d,
                     NextId, grid[q].id)
           ELSE grid[q]]
         plan == Plan(k)
         coll == {j \in 1..Len(history) :
                    j # k /\ j \notin undone /\ FullySafe(j)
                    /\ ~FullySafeOn(j, next)}
     IN /\ history' = Append(history,
              Record("Compensate", next, w, h, Identity(w*h),
                     dests, paletteEpoch, projectEpoch, "Human", k))
        /\ grid' = next
        /\ undone' = undone \cup {k}
        /\ proposal' = NoProposal
        /\ last' = LastRec("acceptStale", plan.class, k, dests,
                           plan.dests, proposal.accepted, plan.accepted,
                           plan.safe, plan.refDests, coll)
        /\ metaCount' = metaCount + 1
        /\ UNCHANGED <<w, h, paletteEpoch, projectEpoch, class4, forked>>

EditStep ==
  \/ \E S \in {{1}, {w*h}, {1, w*h}}, c \in AllowedColors,
        a \in {"Agent", "Human"} : Paint(S, c, "Paint", a)
  \/ \E i \in {1, w*h}, a \in {"Agent", "Human"} : Done(i, a)
  \/ \E x, y \in AllowedColors, a \in {"Agent", "Human"} : Replace(x, y, a)
  \/ Geom("Rotate", "Human") \/ Geom("FlipH", "Human") \/ Geom("FlipV", "Human")
  \/ Crop("Human") \/ PaletteMap("Human") \/ ProjectReplace("Human")

MetaStep ==
  \/ \E k \in 1..Len(history) : Preview(k)
  \/ Reject \/ Reclassify \/ AcceptRebased
  \/ AcceptStale

ExploreStep == EditStep \/ MetaStep

RejectPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ metaCount = 0 -> Preview(1)
    [] metaCount = 1 -> Reject
    [] metaCount = 2 -> Preview(1)
    [] metaCount = 3 -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RejectAfterEditPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Paint({w*h}, 0, "Paint", "Human")
    [] Len(history) = 2 /\ proposal.active -> Reject
    [] OTHER -> UNCHANGED vars

RebaseRotatePath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Geom("Rotate", "Human")
    [] Len(history) = 2 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RebaseHumanPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Paint({1}, 0, "Paint", "Human")
    [] /\ Len(history) = 2 /\ proposal.active /\ last.action # "conflict"
       -> AcceptRebased
    [] /\ last.action = "conflict" -> (Reclassify \/ Preview(proposal.target))
    [] OTHER -> UNCHANGED vars

RebaseHumanRePreviewPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Paint({1}, 0, "Paint", "Human")
    [] /\ Len(history) = 2 /\ proposal.active /\ last.action # "conflict"
       -> AcceptRebased
    [] last.action = "conflict" -> Preview(proposal.target)
    [] OTHER -> UNCHANGED vars

RebaseHumanReclassifyPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Paint({1}, 0, "Paint", "Human")
    [] /\ Len(history) = 2 /\ proposal.active /\ last.action # "conflict"
       -> AcceptRebased
    [] last.action = "conflict" -> Reclassify
    [] OTHER -> UNCHANGED vars

LaterUndoPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> AcceptRebased
    [] Len(history) = 2 /\ ~proposal.active -> Preview(2)
    [] Len(history) = 2 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RebaseCropPath ==
  CASE Len(history) = 0 -> Paint({1, w*h}, 0, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active /\ last.action # "acceptRebased"
       -> Crop("Human")
    [] Len(history) = 2 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 2 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RebasePalettePath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> PaletteMap("Human")
    [] Len(history) = 2 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RebaseABAPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 -> Paint({1}, 0, "Paint", "Human")
    [] Len(history) = 2 -> Paint({1}, 2, "Paint", "Human")
    [] Len(history) = 3 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 3 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

RebaseProjectPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> ProjectReplace("Human")
    [] Len(history) = 2 /\ proposal.active -> AcceptRebased
    [] OTHER -> UNCHANGED vars

StaleRotatePath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 -> Paint({4}, 0, "Paint", "Human")
    [] Len(history) = 2 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 2 /\ proposal.active -> Geom("Rotate", "Human")
    [] Len(history) = 3 /\ proposal.active -> AcceptStale
    [] OTHER -> UNCHANGED vars

StaleHumanPath ==
  CASE Len(history) = 0 -> Paint({1}, 2, "Paint", "Agent")
    [] Len(history) = 1 /\ ~proposal.active -> Preview(1)
    [] Len(history) = 1 /\ proposal.active -> Paint({1}, 0, "Paint", "Human")
    [] Len(history) = 2 /\ proposal.active -> AcceptStale
    [] OTHER -> UNCHANGED vars

ScenarioStep ==
  CASE Scenario = "Explore" -> ExploreStep
    [] Scenario = "Reject" -> RejectPath
    [] Scenario = "RejectAfterEdit" -> RejectAfterEditPath
    [] Scenario = "RebaseRotate" -> RebaseRotatePath
    [] Scenario = "RebaseHuman" -> RebaseHumanPath
    [] Scenario = "RebaseHumanRePreview" -> RebaseHumanRePreviewPath
    [] Scenario = "RebaseHumanReclassify" -> RebaseHumanReclassifyPath
    [] Scenario = "LaterUndo" -> LaterUndoPath
    [] Scenario = "RebaseCrop" -> RebaseCropPath
    [] Scenario = "RebasePalette" -> RebasePalettePath
    [] Scenario = "RebaseABA" -> RebaseABAPath
    [] Scenario = "RebaseProject" -> RebaseProjectPath
    [] Scenario = "StaleRotate" -> StaleRotatePath
    [] Scenario = "StaleHuman" -> StaleHumanPath

Next == ScenarioStep \/ UNCHANGED vars
Spec == Init /\ [][Next]_vars

TypeOK ==
  /\ w \in 1..3 /\ h \in 1..3 /\ DOMAIN grid = 1..(w*h)
  /\ \A q \in DOMAIN grid :
       /\ grid[q].c \in AllowedColors \/ grid[q].c \in Colors
       /\ grid[q].d \in BOOLEAN
       /\ grid[q].v \in 0..Len(history)
       /\ grid[q].id \in Nat
  /\ Cardinality({grid[q].id : q \in DOMAIN grid}) = w*h
  /\ Len(history) <= MaxOps
  /\ metaCount \in 0..MaxMeta
  /\ last.class \in 0..3
  /\ last.action \in {"init", "edit", "preview", "repreview", "reject",
                      "reclassify", "acceptRebased", "conflict", "acceptStale"}
  /\ class4 = FALSE
  /\ forked = FALSE
  /\ proposal.active \in BOOLEAN
  /\ proposal.target \in 0..Len(history)

\* Preview, reject, re-preview, reclassify, and a typed conflict
\* leave the durable log and working project untouched.
MetaDoesNotWrite ==
  last.action \in {"preview", "repreview", "reject", "reclassify", "conflict"}
    => /\ last.logLen = Len(history)
       /\ last.grid = grid
       /\ last.w = w /\ last.h = h
       /\ last.palette = paletteEpoch
       /\ last.project = projectEpoch
       /\ last.undone = undone

\* Reject itself does not change undoability. FullySafe depends only
\* on the durable state, and Reject leaves that state unchanged.
RejectKeepsUndoability ==
  last.action # "reject"
    \/ /\ last.logLen = Len(history)
       /\ last.grid = grid
       /\ last.w = w /\ last.h = h
       /\ last.palette = paletteEpoch
       /\ last.project = projectEpoch
       /\ last.undone = undone

\* A stronger form used on the Reject path: after reject then
\* re-preview and accept, the inverse matches the original before image.
CorrectAccept ==
  IF last.action # "acceptRebased" THEN TRUE ELSE
  LET rec == history[Len(history)]
      k == rec.inverseOf
  IN /\ rec.kind = "Compensate"
     /\ last.accepted = last.safe
     /\ last.dests = last.rederivedDests
     /\ last.dests = last.refDests
     /\ last.logLen + 1 = Len(history)
     /\ \A p \in last.accepted :
          LET q == RefPosition(k, p)
          IN /\ q # 0
             /\ PairEqual(grid[q], history[k].before[p])
             /\ grid[q].v = rec.id
             /\ grid[q].id = history[k].after[p].id

PreserveLaterEdits ==
  last.action # "acceptRebased"
    \/ \A q \in DOMAIN last.grid \ last.dests : grid[q] = last.grid[q]

\* A successful accept is itself a normal logged write and is
\* immediately undoable under the same version-and-identity rules.
CompensateUndoable ==
  IF last.action # "acceptRebased" THEN TRUE ELSE
  LET n == Len(history)
  IN /\ history[n].kind = "Compensate"
     /\ history[n].footprint = last.dests
     /\ \A p \in history[n].footprint : RefSafe(n, p)

NoSilentOverwrite ==
  last.action # "acceptRebased" \/ last.accepted \subseteq last.safe

NoClass4 == last.class # 4 /\ ~class4
NoFork == ~forked
ColorDoneConsistency == \A q \in DOMAIN grid : grid[q].c = 0 => ~grid[q].d

\* Typed conflict does not append, does not invent class 4, and
\* leaves a live proposal so RePreview or Reclassify may follow.
ConflictIsTyped ==
  last.action # "conflict"
    \/ /\ last.class \in {2, 3}
       /\ last.rederivedAccepted = {}
       /\ proposal.active
       /\ last.logLen = Len(history)

\* Applying a stale proposal is harmless only if it coincides with
\* a current re-derivation and does not steal another op's undoability.
\* Enabled stale-accept paths are expected to violate this.
StaleAcceptHarmless ==
  last.action # "acceptStale"
    \/ (last.dests = last.rederivedDests
        /\ last.accepted = last.rederivedAccepted
        /\ last.collateral = {})

\* Coverage (negated in witness configs).
WitnessRebaseRotate ==
  last.action = "acceptRebased"
  /\ last.dests # {}
  /\ \E j \in 1..Len(history) : history[j].kind = "Rotate"
WitnessLaterUndo ==
  last.action = "acceptRebased"
  /\ Len(history) = 3
  /\ history[2].kind = "Compensate"
  /\ history[3].kind = "Compensate"
  /\ history[3].inverseOf = 2
WitnessRejectRestored ==
  last.action = "acceptRebased"
  /\ last.target = 1
  /\ last.dests # {}
  /\ \E j \in 1..Len(history) : history[j].kind # "Compensate"
     => TRUE
WitnessRePreview == last.action = "repreview" /\ IsStale = FALSE
WitnessReclassify == last.action = "reclassify"
WitnessConflict == last.action = "conflict" /\ last.class = 3
WitnessPartial == last.action = "acceptRebased" /\ last.class = 2
WitnessStaleHarm == last.action = "acceptStale" /\ ~StaleAcceptHarmless
NotRebaseRotate == ~WitnessRebaseRotate
NotLaterUndo == ~WitnessLaterUndo
NotRejectRestored == ~WitnessRejectRestored
NotRePreview == ~WitnessRePreview
NotReclassify == ~WitnessReclassify
NotConflict == ~WitnessConflict
NotPartial == ~WitnessPartial
=============================================================================
