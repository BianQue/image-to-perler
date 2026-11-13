------------------------------ MODULE Workflow ------------------------------
EXTENDS Integers, FiniteSets, TLC
VARIABLES phase, round, approved, externalConsent, uploads, writes,
          snapshot, current, files, reported, lowAccepted
vars == <<phase, round, approved, externalConsent, uploads, writes,
          snapshot, current, files, reported, lowAccepted>>
Init ==
  /\ phase = "ready" /\ round = 0 /\ approved = FALSE
  /\ externalConsent = FALSE /\ uploads = 0 /\ writes = 0
  /\ snapshot = 0 /\ current = 0 /\ files = [i \in 1..3 |-> -1]
  /\ reported = FALSE /\ lowAccepted = FALSE
Consent ==
  /\ ~externalConsent /\ externalConsent' = TRUE
  /\ UNCHANGED <<phase, round, approved, uploads, writes, snapshot,
                 current, files, reported, lowAccepted>>
Generate ==
  /\ externalConsent /\ uploads < 2 /\ phase = "ready"
  /\ uploads' = uploads + 1 /\ externalConsent' = FALSE
  /\ UNCHANGED <<phase, round, approved, writes, snapshot,
                 current, files, reported, lowAccepted>>
Evaluate ==
  /\ phase = "ready" /\ round < 2
  /\ round' = round + 1 /\ phase' \in {"passed", "failed"}
  /\ UNCHANGED <<approved, externalConsent, uploads, writes, snapshot,
                 current, files, reported, lowAccepted>>
Refine ==
  /\ phase = "failed" /\ round < 2 /\ phase' = "ready"
  /\ UNCHANGED <<round, approved, externalConsent, uploads, writes,
                 snapshot, current, files, reported, lowAccepted>>
Accept ==
  /\ phase \in {"passed", "failed"}
  /\ approved' = TRUE /\ lowAccepted' = (phase = "failed")
  /\ phase' = "selected"
  /\ UNCHANGED <<round, externalConsent, uploads, writes, snapshot,
                 current, files, reported>>
Apply ==
  /\ phase = "selected" /\ approved /\ writes = 0
  /\ writes' = 1 /\ current' = 1 /\ phase' = "editing"
  /\ UNCHANGED <<round, approved, externalConsent, uploads, snapshot,
                 files, reported, lowAccepted>>
Export ==
  /\ phase = "editing" /\ phase' = "exporting" /\ snapshot' = current
  /\ UNCHANGED <<round, approved, externalConsent, uploads, writes,
                 current, files, reported, lowAccepted>>
Human ==
  /\ phase \in {"editing", "exporting"} /\ current < 2
  /\ current' = current + 1
  /\ UNCHANGED <<phase, round, approved, externalConsent, uploads, writes,
                 snapshot, files, reported, lowAccepted>>
WriteFile ==
  /\ phase = "exporting"
  /\ \E i \in 1..3:
       /\ files[i] = -1
       /\ files' = [files EXCEPT ![i] = snapshot]
  /\ UNCHANGED <<phase, round, approved, externalConsent, uploads, writes,
                 snapshot, current, reported, lowAccepted>>
Report ==
  /\ phase = "exporting" /\ \A i \in 1..3: files[i] = snapshot
  /\ reported' = TRUE /\ phase' = "delivered"
  /\ UNCHANGED <<round, approved, externalConsent, uploads, writes,
                 snapshot, current, files, lowAccepted>>
Next == Consent \/ Generate \/ Evaluate \/ Refine \/ Accept \/ Apply \/
        Export \/ Human \/ WriteFile \/ Report
Spec == Init /\ [][Next]_vars
BoundedSearch == round <= 2
ConfirmedApply == writes > 0 => approved
PreviewIsIsolated == phase \in {"ready", "passed", "failed", "selected"} => writes = 0
ConsistentDelivery == \A i \in 1..3: files[i] # -1 => files[i] = snapshot
NoFalseCompletion == reported => \A i \in 1..3: files[i] = snapshot
=============================================================================
