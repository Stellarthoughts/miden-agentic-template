# Agentic Miden Day — Feedback

## Project: Chronovault

Private digital time capsules on Miden. Lock assets and a message, set an unlock time, and pick a recipient. Nobody sees what's inside until it opens. Think of it as a blockchain lunchbox with a timer and a padlock.

---

## What We Built

- **Time-capsule note script** — dual unlock (timestamp via `tx::get_block_timestamp()` OR block height via `tx::get_block_number()`). Recipient verification, asset transfer, Felt-encoded message payload in note inputs. Input layout: `[unlock_timestamp, unlock_height, recipient_prefix, recipient_suffix, ...message_felts]`.
- **Heartbeat account component** (on disk, disconnected) — originally designed for a dead-man-switch feature. Architecturally impossible on Miden: note inputs are immutable post-creation, note scripts cannot cross-read other accounts' storage, and the recipient controls which notes to co-consume. Five approaches were tried; all were dead ends. Left as an artifact of optimism.
- **MockChain integration tests** — 4 tests covering block height unlock, sealed-too-early rejection, wrong-recipient rejection, and all-zero immediate unlock.
- **Local node validation** — full pipeline (create wallets → create capsule → publish → consume → verify) against `miden-node` v0.13.8.
- **React frontend** — two-tab UI (Create / Open). Create: a form with recipient, unlock condition (date/time picker or block height), optional asset attachment, message, and a public/private toggle; submits via wallet adapter. Open: manual refresh for public note discovery + manual capsule data input for private notes. Includes a collapsible user guide. 18 tests passing, types clean, build succeeds.

### Current Status

Everything works except the last mile. Contract compilation → MockChain tests → local node validation → frontend capsule creation → on-chain note publication → note data export as base64 blob — all solid. The consume flow is blocked by the wallet extension not executing custom MASM note scripts. Contract logic is proven correct at every layer we control. Details in the "Wallet Extension Wall" section below.

---

## Architecture Disclosure

This wasn't built by a single AI agent in a single context window. Here's the whole setup:

**Orchestrator:** Claude Opus 4.6 running as a persistent persona ("Molly") in OpenCode. Handles all architectural decisions, planning, code review, and user interaction. Has a private memory system stored in an Obsidian vault — session handoffs, personality notes, and project context — providing continuity across four sessions.

**Subagents:**

- **inkblot** (researcher) — SDK documentation research via Context7, web search for Miden docs, wallet adapter internals
- **crowbar** (implementer) — multi-file code implementation, the actual hands
- **canary** (verifier) — runs tests, lint, build, reports pass/fail
- **rat-scout** (reader) — codebase exploration, file reading, structure mapping
- **bouncer** (security) — security review of generated code (used during contract phase)

**Workflow across four sessions:**

1. Orchestrator planned the architecture (note IS the capsule, dual unlock, heartbeat component)
2. inkblot researched Miden SDK patterns (Felt arithmetic, note inputs, storage types, MockChain API)
3. crowbar implemented contracts, tests, and validation binary
4. canary verified each phase (build → test → local node)
5. For frontend: inkblot researched React SDK hooks, crowbar implemented components, canary verified
6. Orchestrator reviewed all code between phases and made architectural corrections
7. Session 3: inkblot researched `tx::get_block_timestamp()` availability and cross-account read constraints. Orchestrator killed the dead-man-switch. crowbar implemented timestamp unlock, asset attachment, and UX fixes
8. Session 4: inkblot researched wallet adapter internals and SDK consume paths. crowbar implemented three different consume strategies (wallet extension, WebClient, hybrid). Each exposed a different layer of the extension limitation. Orchestrator diagnosed the root cause as the wallet extension not supporting custom note script execution

The orchestrator never directly edited files (except for one trivial unused-import fix — old habits). All code changes went through subagents, and all code was reviewed by the orchestrator before proceeding. Yes, the AI agent reviewing AI agent code is recursive. We're aware.

---

## What Worked Well

**The template structure is excellent.** `project-template/` for contracts and `frontend-template/` for React is the right split. The `CLAUDE.md` files in each directory gave the AI agent enough context to work autonomously with minimal corrections. That's rare and genuinely appreciated.

**`cargo-miden` and the Rust SDK are remarkably AI-friendly.** The `#[component]` and `#[note]` macros mean contract code is clean, declarative, and easy to reason about. It feels like writing normal Rust with superpowers, not wrestling a framework. The `Value` and `StorageMap` types are intuitive. The `Felt` arithmetic pitfall doc saved us at least one session.

**MockChain is a killer feature for AI development.** Fast, deterministic, no network dependency. Test cycles in seconds, not minutes. For an AI agent that might need 10-15 iterations to get a contract right, this is the difference between "done in an hour" and "done tomorrow." It is the single most AI-agent-friendly part of the stack, and it's not close.

**The React SDK hooks (`@miden-sdk/react`) are well-designed.** `useConsume`, `useSyncState`, `useNotes`, `useTransaction` — consistent patterns, good TypeScript types, sensible defaults.

**The wallet adapter pattern is the right abstraction.** `Transaction.createCustomTransaction` + `requestTransaction` matches the MetaMask mental model every web3 developer already has. Good design choice — when the implementation catches up.

---

## What Needs Improvement

### Setup & Tooling

- **`cargo-miden` and `miden-node` aren't pre-installed, and template docs don't mention them.** The first 20 minutes were spent figuring out what was missing. A setup script or explicit prerequisites list would help. (Note from Pavel: I skipped the prerequisites steps, so this is partly on me — but agents could course-correct from a single line in AGENTS.md.)
- **The `wide-arithmetic` compiler warning on every build is noisy.** Harmless but confusing for AI agents and humans — looks like something is wrong.
- **Debug mode output is overwhelming.** `in_debug_mode(true)` produces thousands of lines. We thought tests were failing for the first five minutes. Default should be `false`.
- **Frontend WASM chunks over 500KB trigger Vite warnings.** Not a real problem, but either suppress it in `vite.config.ts` or document it.

### Documentation Gaps

- **`tx::get_block_timestamp()` should be documented prominently.** We discovered it by sending a research agent through SDK source code. It is extremely useful for time-locked notes — arguably the most user-friendly unlock primitive — but it is not mentioned anywhere in the template.
- **Note input immutability should be called out.** Template examples don't make it obvious that note inputs are baked at creation time. Major architectural implications.
- **Max Felt value needs a warning.** The Goldilocks prime field means max Felt is NOT `u64::MAX` — it's `p - 1 = 18446744069414584320`. We used `u64::MAX` as a sentinel at first and got silent wraparound. Deserves a "this is not what you think it is" callout in the pitfalls doc.
- **No cross-SDK type reference.** How `AccountId`, `Felt`, `NoteType` map between Rust and TypeScript had to be verified by reading both SDK sources.
- **Template assumes testnet deployment gates frontend work.** In practice, local node validation proves correctness, and the frontend SDK handles its own testnet connection. The real gate is "contracts work," not "contracts are deployed to testnet."
- **No documented way to import a browser extension wallet into the Rust client.** The Rust SDK and the browser extension are two separate worlds.

### Infrastructure

- **The testnet faucet page is broken** (as of Mar 13 2026). The wallet extension's built-in faucet button works. Minor but confusing.
- **`requestConsumableNotes()` triggers wallet UI popups.** Template should warn against auto-calling wallet adapter methods in `useEffect`.

---

## The Frontend SDK Gap

The frontend SDK has two disconnected worlds. Getting custom note scripts to work required understanding both and finding the narrow seam between them. This section is long because we want to save the next person from the same detective work.

### World 1: React SDK (`@miden-sdk/react`)

`useConsume`, `useNotes`, `useSyncState`, `useTransaction`, etc. These hooks talk to an internal WebClient instance with its own WASM-backed store (IndexedDB). This client can execute custom note scripts. But when `MidenFiSignerProvider` is used, it creates a local proxy signer account that is NOT the user's wallet account — so any note script that verifies the consuming account's ID will fail.

### World 2: Wallet Adapter (`@miden-sdk/miden-wallet-adapter`)

`requestTransaction`, `requestConsume`, `importPrivateNote`, etc. These methods talk to the Miden browser extension. The extension holds the user's real accounts and can sign transactions. But `requestConsume` / `ConsumeTransaction` only supports standard P2P token transfers.

### The path that should work for custom note scripts

1. Serialize the `Note` object directly (`note.serialize()`) — NOT through `NoteFile.fromOutputNote()` which strips metadata
2. Share the serialized bytes (base64-encoded) out-of-band to the recipient
3. On the recipient side, deserialize with `Note.deserialize(bytes)` — preserves full metadata, script, inputs, and recipient data
4. Build a `TransactionRequestBuilder().withInputNotes(...)` with the deserialized Note
5. Submit via `Transaction.createCustomTransaction()` + `requestTransaction()` through the wallet adapter

### Key discoveries

- `NoteFile.fromOutputNote()` creates a details-only variant without metadata → causes "Input Note Record does not contain metadata" errors on consume
- `Note.serialize()` / `Note.deserialize()` preserves everything and round-trips correctly. This is the approach you want
- `useConsume` from the React SDK uses the proxy signer account, which fails recipient verification in custom scripts
- `MidenProvider` blocks initialization when `MidenFiSignerProvider` is present but wallet isn't connected — wallet connect UI must be outside the `isReady` gate
- `useWallet()` and `useMidenFiWallet()` read from DIFFERENT React contexts — only `useMidenFiWallet()` gets populated by `MidenFiSignerProvider`
- `WalletMultiButton` requires `WalletModalProvider` → `WalletProvider`, but `MidenFiSignerProvider` is separate — building a custom connect button with `useMidenFiWallet()` is simpler and less likely to make you question your career choices

### What still doesn't work

- Note discovery via React SDK (`useNotes`) — WebClient store and extension store are separate databases
- Auto-syncing public notes into the app — works through extension's `requestConsumableNotes()` but not React SDK hooks
- Wallet account switching — adapter doesn't detect account changes in the extension

---

## The Wallet Extension Wall

Session 4 was entirely dedicated to fixing two runtime bugs. We threw everything at them. Here's the archaeological record.

### Bug 1: Wallet stuck on "generating transaction..."

The wallet extension's WASM prover was choking because we were sending the note data twice: once inside the serialized `TransactionRequest` (via `withInputNotes`) and again as raw bytes via `createCustomTransaction`'s `importNotes` parameter. Removing the duplicate payload stopped the crash. The extension confirmed transactions without hanging.

Except — without `importNotes`, the extension had no note to actually consume. It would cheerfully confirm the transaction and do absolutely nothing. No assets transferred, no message decoded, no note script executed. Just vibes and a green checkmark.

Putting `importNotes` back made the extension brick itself again. Not a crash-and-recover — a full state corruption requiring reinstall. We reproduced this twice before deciding our sanity was worth more than a third data point.

### Bug 2: Capsule opens before deadline

We tried routing consumption through the React SDK's WebClient instead of the extension. This worked beautifully for script enforcement — `assert(current_timestamp >= unlock_timestamp)` fired and rejected locked capsules. Contract logic: proven correct.

But the WebClient path has a fatal problem: the consuming account lives in the extension, not in the WebClient's local store. `importAccountById` pulls account data from the network, but the private key stays in the extension. The `MidenFiSignerProvider` callback routes signing to the extension, but for a _different_ derived signer account, not the actual wallet account. Transaction execution fails with auth errors.

The extension path has the keys but doesn't execute scripts. The WebClient path executes scripts but doesn't have the keys. Pick your poison.

### What we verified (ruling out our code)

- **No unit mismatch.** Timestamps are seconds-to-seconds throughout the entire chain
- **No serialization mismatch.** `Note.serialize()` on create, `Note.deserialize()` on consume. Clean round-trip
- **No input layout mismatch.** Frontend layout matches contract expectations and integration test helpers exactly
- **`NEVER_SENTINEL` is correct.** `18446744069414584320n` = Goldilocks p-1. No truncation, no overflow
- **Correct APIs used.** `TransactionRequestBuilder.withInputNotes()` and `createCustomTransaction` confirmed via SDK source as canonical paths
- **Contract logic proven correct.** WebClient execution fired assertions correctly — locked capsules rejected, unlocked capsules accepted

### Root cause

The Miden browser wallet extension does not reliably execute custom MASM note scripts during `requestTransaction(CustomTransaction)`. Without `importNotes`, it acknowledges transactions without running the script. With `importNotes`, it bricks. This is exclusively an extension issue — the contract, the frontend, the serialization, and the API usage are all correct.

If the wallet extension fixes `importNotes` handling, everything falls into place without application code changes. The plumbing is there.

### Extension-specific feedback

- **The extension cannot recover from unexpected `CustomTransaction` payloads.** It corrupts its internal state and requires a full reinstall. During a hackathon, every failed experiment costs 5-10 minutes for reinstall, reconnect, and re-fund. That's fatal for iteration speed.
- **`requestTransaction(CustomTransaction)` with `importNotes` needs a working example.** We could not find a single public example of consuming a custom-script note through the browser extension. The adapter README covers `ConsumeTransaction` for P2P flows, but nothing for custom MASM scripts.
- **The two-world problem needs a documented bridge.** `MidenFiSignerProvider` creates a proxy signer account that doesn't match the extension's wallet account. Any note script checking `active_account::get_id()` — which is most real-world scripts — can't use the React SDK's local execution path. Either document how to import the extension's account into the WebClient with signing capability, or provide a hook that routes custom transaction execution through the extension with full script enforcement.
- **Assertion failure errors are not human-readable.** `"assertion failed at clock cycle 12598 with error code: 0"` doesn't tell you which assertion. Custom scripts with multiple checks become a guessing game. Even "assertion at MASM line X" would help.

---

## Suggestions for the Template

1. **Add a setup script** (`setup.sh` or `Makefile`) that installs `cargo-miden`, `miden-node`, and runs initial builds
2. **Document the "contracts work → frontend can start" gate** instead of requiring testnet deployment
3. **Add a cross-SDK type reference** — how types map between Rust and TypeScript
4. **Include an example of custom note scripts in the frontend** — a note with inputs, recipient verification, and conditional logic. That's where every real project ends up, and that's where the docs go cold
5. **Suppress known warnings** (`wide-arithmetic`, chunk size) in template config files

---

## Decisions & Tradeoffs

### Skipping Testnet Deploy Binary

We chose not to write a `deploy_chronovault.rs` testnet binary. Local node validation already proved contract correctness end-to-end. The Rust client SDK doesn't support wallet import from mnemonic, and the frontend SDK connects to testnet independently. The template's assumption that testnet deployment gates frontend work doesn't match reality — the real gate is contract correctness.

### Killing the Dead Man's Switch

After real effort: note inputs are immutable post-creation, note scripts can't read external account storage, and the recipient controls co-consumed notes. A heartbeat mechanism is architecturally impossible on Miden today. We removed it rather than ship a lie.

---

## Time Breakdown

**Session 1 (Mar 13 afternoon) — Contracts + local validation:**

- Phase 0 (Setup): ~20 min — toolchain verification, `cargo-miden` installation
- Phase 1 (Contracts): ~45 min — heartbeat component + time-capsule note script
- Phase 2 (MockChain tests): ~30 min — 4 tests, all passing
- Phase 3 (Local node validation): ~40 min — including `miden-node` installation, debugging path issues

**Session 2 (Mar 13 afternoon/evening) — Frontend:**

- Phase 4 (Artifacts): ~5 min — copied .masp files to frontend
- Phase 5 (Frontend): ~60 min — hooks, components, tests, build. Five wrong consume paths before finding the correct one

**Session 3 (Mar 13 evening) — Polish + architecture rework:**

- Timestamp unlock: ~20 min — added `tx::get_block_timestamp()`, updated tests, rebuilt artifacts
- Dead man's switch investigation + removal: ~30 min — five approaches, all dead ends
- Asset attachment: ~15 min — `FungibleAsset` + `NoteAssets`
- UX fixes: ~15 min — killed auto-refresh spam, added user guide, datetime picker
- Bug investigation: ~10 min — found two runtime bugs, couldn't fix without devtools
- Feedback + docs: ~15 min

**Session 4 (Mar 14) — Bug hunting:**

- Duplicate payload diagnosis + fix: ~20 min
- WebClient consume path attempt: ~40 min — import note → build request → execute → auth failure → account mismatch investigation
- Account identity investigation: ~20 min — signerAccountId vs wallet address
- Wallet extension `importNotes` final attempt + bricking: ~15 min
- Feedback writing: ~15 min

**Total: ~7 hours across four sessions.** The contracts were the easy part. The frontend SDK gap was the adventure. The wallet extension was the wall.
