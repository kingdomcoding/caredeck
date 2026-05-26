# ADR 008: Aid document verification stub

**Status:** Accepted
**Date:** 2026-05-26

## Context

The Aid wizard's signature UX moment is the small green "Successfully verified" label that appears under each uploaded document after ~1 second. The marketing pitch sells this as automated OCR + LLM-driven correctness checking.

Building a real verifier in Phase 10 would block the entire phase on training data, OCR tooling, model selection, and FERPA-equivalent legal review. The verifier is a *secondary* selling point of the Aid module — the *primary* one is the 13-section wizard itself.

## Decision

Ship a stub from Phase 10 onwards:

- An Ash action `Caredeck.Aid.verify_document/1` returns `{:ok, :verified}` after a 1-second async delay (Oban `:aid` queue).
- The `UploadedDocument` resource has a `verification_status` state machine: `:pending → :verifying → :verified | :failed`.
- The state machine is a real `AshStateMachine` — the *contract* is real, only the verifier *impl* is stub.
- A feature flag `:aid_verification_engine ∈ {:stub, :ocr, :llm}` lives in runtime config. Default `:stub`. The `:ocr` and `:llm` implementations land later behind the same interface.

The user-visible string ("Successfully verified") is the same whether the stub or a real verifier produced it.

## Consequences

**Gains:**

- Phase 10 ships the visible UX without the engineering tail of real OCR.
- Real verifier replacement is a single feature-flag flip + a worker swap; no UI changes.

**Costs:**

- The stub is a placeholder that must not be deployed to a real applicant population without replacement. A README warning + a runtime log line on stub-mode startup mitigates this.
- The state machine has a `:failed` state that the stub never produces. Phase 11's admin dashboard must still surface the failed-row UI path (covered by seed data showing both states).

## Alternatives considered

- **Don't model the state machine at all in Phase 10; just always say "verified".** Rejected: invalidates the entire `:aid` Oban queue and leaves a refactoring debt.
- **Build OCR in Phase 10.** Rejected: pushes Phase 10 from 7-9 days to ≥ 20 days.
