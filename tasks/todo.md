# Chronovault — Hackathon Build Plan

> Private digital time capsules on Miden. Lock assets and a message, set an unlock time, and pick a recipient. Nobody sees what's inside until it opens.

## Deliverables

1. **Hackathon MVP** — template structure, basic React frontend, `feedback.md`
2. **Aeonaxsys Port** (stretch) — Next.js rewrite, deploy on aeonaxsys.com

## Scope Lock

- ONE capsule type, ONE asset, ONE recipient
- One contract: time-capsule note script with dual unlock (timestamp OR block height)
- Message payload as Felt-encoded ASCII in note inputs
- One-page frontend with Create / Open tabs
- Asset attachment (optional tokens locked in capsule)

---

## Phase 0: Setup & Lock Scope ✅ DONE
## Phase 1: Contracts ✅ DONE
## Phase 2: MockChain Tests ✅ DONE
## Phase 3: Local Node Validation ✅ DONE — GATE PASSED
## Phase 4: Artifact Copy ✅ DONE (testnet deploy skipped — see `feedback.md`)
## Phase 5: Frontend MVP ✅ DONE

18 tests pass (4 suites), types are clean, and the build succeeds. Two-tab UI: Create (form with timestamp/block-height unlock, asset attachment, message, public/private toggle → seal → share note data) and Open (manual refresh for public notes + manual note data input for private notes).

## Phase 6: Polish & Bug Fixes ✅ DONE (partially — blocked by wallet extension)

### Completed (sessions 3 + 4)
- [x] Added timestamp-based unlock (`tx::get_block_timestamp()`) — primary unlock path
- [x] Kept block height unlock as secondary path
- [x] Removed dead man's switch / heartbeat (not architecturally possible on Miden — note inputs are immutable, and cross-account reads are impossible in note scripts)
- [x] Heartbeat contract left on disk but disconnected from UI and note script
- [x] Updated note input layout: `[0] unlock_timestamp, [1] unlock_height, [2] recipient_prefix, [3] recipient_suffix, [4..] message`
- [x] Max Felt sentinel (`18446744069414584320`) used for "disabled" conditions
- [x] 4 MockChain tests updated and passing
- [x] Added asset attachment — wallet assets queried via `requestAssets()`, `FungibleAsset` packed into `NoteAssets`
- [x] Fixed auto-refresh spam — removed `useEffect` auto-fire on connect, fully manual refresh
- [x] Added public-capsule-only indicator on refresh
- [x] Added "How it works" collapsible guide
- [x] Timestamp picker (datetime-local input) with min-date validation
- [x] Block height mode shows current block + computed unlock block
- [x] All 18 frontend tests passing, build is clean
- [x] Root-caused both bugs (session 4)
- [x] Proved contract logic correct via WebClient execution path
- [x] Fixed error handling — errors propagate, no false "Capsule opened!" on failure
- [x] Fixed message timing — message only shown after successful transaction
- [x] Updated feedback.md with session 4 findings

### 🔴 BLOCKED — Wallet Extension Limitations

- [ ] **Capsule unlock not enforced** — wallet extension does not execute custom note scripts during `requestTransaction(CustomTransaction)`. Contract logic proven correct via WebClient path. Cannot fix from application code.
- [ ] **Extension bricks on `importNotes`** — including note bytes in `createCustomTransaction` corrupts extension state, requiring full reinstall. Without them, extension has no note to consume. Cannot fix from application code.

Both bugs have the same root cause: the Miden wallet extension does not support custom note script consumption through the adapter API. Once this is fixed upstream, the application code is ready, and no changes are needed.

### Not attempted
- [ ] Browser walkthrough of full demo flow (blocked by above)
- [ ] Aeonaxsys port (stretch goal, not started)

## Stretch: Aeonaxsys Port (only if MVP done)
- [ ] Port frontend to Next.js
- [ ] Deploy on aeonaxsys.com

---

## Architecture Notes

### Why no dead man's switch
Miden note inputs are immutable at creation time. Note scripts cannot read external account storage (cross-account reads are impossible). The heartbeat component can record pings, but no mechanism exists for a note to check whether pings occurred. A co-consumed "ping note" approach was considered, but the recipient controls which notes to co-consume and could simply omit the ping. The feature was removed rather than shipped as a lie.

### Current note input layout
```
[0] unlock_timestamp  — unix seconds, max Felt = disabled
[1] unlock_height     — block number, max Felt = disabled
[2] recipient prefix  — AccountId.prefix()
[3] recipient suffix  — AccountId.suffix()
[4..] message         — Felt-encoded ASCII chars
```

### Max Felt sentinel
Goldilocks field: p = 2^64 - 2^32 + 1 = 18446744069414584321
Max value: p - 1 = 18446744069414584320
Used as "never" / "disabled" for unlock conditions.

### Asset attachment
`FungibleAsset(faucetAccountId, amount)` packed into `NoteAssets([asset])`. Wallet assets queried via `useMidenFiWallet().requestAssets()`. Contract receives via `active_note::get_assets()` → `native_account::add_asset()`.

---

## Lessons

- `cargo-miden` not pre-installed — template docs don't mention this.
- `miden-node` also not pre-installed.
- Binaries run from `integration/` dir — relative paths work from there.
- Debug mode produces massive trace output — not an error, just noisy.
- Cross-account reads impossible in note scripts — bake external state into note inputs at creation time.
- `AccountId` is two felts: `.prefix().as_felt()` + `.suffix()`.
- The `wide-arithmetic` warning on every build is expected and harmless.
- Local node needs clean state every session.
- `tx::get_block_timestamp()` is available in note scripts — returns unix seconds.
- Max Felt value is NOT `u64::MAX` — it's `p - 1` (Goldilocks prime field).
- Note inputs are immutable after creation — no mechanism to update them.
- Heartbeat / dead man's switch requires mutable state that notes cannot access.
- `NoteFile.fromOutputNote()` strips metadata — use `Note.serialize()` / `Note.deserialize()` instead.
