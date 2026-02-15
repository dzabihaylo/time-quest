# Phase 7: Schema Evolution + Adaptive Difficulty - Research

**Researched:** 2026-02-14
**Confidence:** HIGH

## Summary

Research complete. See plans for implementation details.

Key findings:
- SchemaV4 is a clean lightweight migration (additive with defaults)
- EMA with alpha=0.3 and monotonic ratchet is the algorithm
- accuracyPercent must remain difficulty-independent (only rating changes)
- 4 new files needed, ~7 files modified
- Primary integration point is GameSessionViewModel.completeActiveTask()
