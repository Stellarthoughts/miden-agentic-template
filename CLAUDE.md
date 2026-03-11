# Miden Agentic Template

This monorepo contains two Miden development templates as git submodules:

- `project-template/` -- Miden smart contracts (Rust SDK). Account components, note scripts, transaction scripts, and integration tests.
- `frontend-template/` -- Miden web frontend (React + TypeScript + @miden-sdk/react). Browser-based UI that interacts with Miden contracts.

Each sub-template has its own CLAUDE.md with detailed instructions, skills for domain-specific patterns, and hooks for automated verification. These load automatically when you start working in either directory.

## Development Workflow

**Contracts first, then frontend.** The frontend consumes compiled contract artifacts.

1. Build smart contracts in `project-template/`
   - Write account components, note scripts, and tx scripts in `project-template/contracts/`
   - Test with MockChain in `project-template/integration/tests/`
   - Contracts compile to `.masp` package files

2. Copy contract artifacts to the frontend
   - Copy `.masp` files from `project-template/masm-output/` (or the contract's `target/` directory) into `frontend-template/public/packages/`
   - The frontend loads these at runtime via the Miden SDK

3. Build the frontend in `frontend-template/`
   - React components use `@miden-sdk/react` hooks to interact with contracts
   - TDD workflow: write tests first, then implement
   - Automated hooks verify type safety and test coverage on every edit

## Which Directory to Work In

| Task | Directory |
|------|-----------|
| Write or edit smart contracts | `project-template/contracts/` |
| Write or edit integration tests | `project-template/integration/tests/` |
| Write or edit frontend components | `frontend-template/src/` |
| Write or edit frontend tests | `frontend-template/src/__tests__/` |
| Deploy contracts to testnet | `project-template/integration/src/bin/` |

## Automated Verification

Hooks run automatically on every file edit:
- Editing files in `project-template/contracts/` triggers `cargo miden build` on the modified contract
- Editing files in `frontend-template/src/` triggers TypeScript type checking and affected test runs

On task completion, a full verification runs: contract integration tests + frontend tests + typecheck + build.

## Quick Reference

**Build a contract:**
```
cargo miden build --manifest-path project-template/contracts/<name>/Cargo.toml --release
```

**Run contract integration tests:**
```
cd project-template && cargo test -p integration --release
```

**Start frontend dev server:**
```
cd frontend-template && yarn dev
```

**Run frontend tests:**
```
cd frontend-template && npx vitest --run
```
