# Accepted collaboration baseline — 2026-11-13

Date: 2026-11-13. Timezone: UTC+8 (Asia/Taipei).
Pinned design head: `bdc9c0adc8f0be4b329bf43b7babdae45693cae7`.
Pinned main and merge base: `ac598aa3102a1a2b54bef680d78cb46baa16ae9b`.

This pull request records the accepted design, formal models, and audit artifacts. It includes no runtime source and enables no features. It is not the whole historic design branch: [pull request 1](https://github.com/BianQue/image-to-perler/pull/1) contains advisory source and tests, remains OPEN and draft, and is not to be merged. Advisory source remains unmerged there and is scheduled in later implementation pull requests.

The four reports below are verbatim accepted review artifacts. Their original task restrictions, workspace paths, relative evidence links, and references to “this round” describe their historical review context, not this baseline publication. External workspace evidence is not bundled here; these reports do not claim that its links resolve from this repository. The operator subsequently authorized this separate documentation baseline. The historic whole-branch assessment remains intact; only documentation is selected for this PR.

- [Interrogation and findings](INTERROGATION.md)
- [Accepted staged plan, including S1-a](PLAN.md)
- [Locked defaults](DEFAULT-DECISIONS.md)
- [Constraint-check report](CONSTRAINT-CHECK.md)
- [Operation-record contract](../../operation-record-contract.md)
- [Formal inventory and reproduction commands](../../formal/README.md)

GitHub tracking issues are deferred; none are opened by this baseline. Issue names in the plan denote planned work only. V3, V4, and V5 remain implementation risks scheduled in S5-a, S5-b, and S5-c respectively.

The constraint check was a finite-model and static check, not implementation acceptance and not an unbounded proof. Holds: Q2, Q3, Q4, Q5, Q8, Q10, Q12, Q13, P1. Not checked: Q1, Q6, Q7, Q9, Q11, R2, R3. That review round reran 26 official short configs and did not rerun the remaining 64 official configs. Historical runs are not fresh acceptance. This baseline packaging does not rerun TLC, application tests, browser tests, or fault injection.
