---
name: addon-fleet-checks
description: Deterministic checks for the captain's WoW addons (retail and WoW: Forever). Use when changing addon code that calls client APIs, reads or writes another addon's settings or globals (Zygor, EllesmereUI, Baganator, FetchAPI), edits a luajit test mock, or ships seeded settings; or when asked to refresh the API snapshot.
---

# Addon fleet checks

Scripts do the work; you read only their output. All three print nothing but problems.
`PF=/Users/jeffmlr/Projects/firstmate/projects/Preflight` (every command below runs from any folder).

## When to run what

| You are about to / just did | Run |
|---|---|
| Touch a client API (a `C_*`, a global function, a frame method), or add one to a test mock | strict mocks (below), then `python3 -I $PF/tools/fleet.py --addon <Name>` |
| Add or change code that reads or writes another addon's SavedVariables or global (`ZGV`, `EllesmereUIDB`, `FetchAPI`, `BAGANATOR_CONFIG`) | `python3 -I $PF/tools/fleet.py --addon <Name>` |
| Change seeded or default settings that another addon reads (Doorstep seeds, Fetch gear rules) | `bash $PF/tests/contracts.sh` |
| Add a setup window or wizard with draft state (picks made before Finish) | a draft-vs-saved test in your own repo: change each control without saving, assert everything downstream follows the draft |
| Finish any change in an addon repo | the repo's own tests, plus the line above that fits |

Each addon repo's own `tests/` stay the first gate; these catch what one repo's mocks cannot.

## The fleet scanner

```
python3 -I $PF/tools/fleet.py                  # problems only, one line each; "fleet: ok" when clean
python3 -I $PF/tools/fleet.py --addon Doorstep # only what involves it
python3 -I $PF/tools/fleet.py --ids            # add each problem's id
python3 -I $PF/tools/fleet.py --summary        # who provides/consumes what (read only when you need the map)
```

Problem kinds: `toc-file` (listed file missing), `sv-clash`, `global-clash`, `undeclared-dep` (uses another
addon's global, not in its Dependencies/OptionalDeps), `foreign-state` (two or more of ours touch another
addon's settings, one writes, no contract covers it), `api` (a client API one client's snapshot lacks).
- `foreign-state` for an owner goes away when a contract in `$PF/tests/contracts/` declares
  `covers = { "<Owner>" }`: write the contract, don't suppress it.
- A problem that is intended gets its id and a reason in `$PF/tools/fleet-known.json` under `accepted`.
- `--unknown` lists names no snapshot has (third-party globals too, noisy): use only when hunting a dead probe.

## Strict mocks (luajit tests)

A mock must not provide an API the live client lacks (a `ChatFrame_*` global that exists only with
`loadDeprecationFallbacks` on once made a test pass and the live fix fail). In the repo's test setup,
after the mock defines its globals and before loading the addon:

```lua
local Strict = dofile("/Users/jeffmlr/Projects/firstmate/projects/Preflight/tools/strict_api.lua")
Strict.install("retail", { allow = { "Syndicator", "^MyAddon" } })   -- or "forever"; run the test once per client
```

It fails the test naming each mock-provided name the client lacks, and fails reads of unknown globals and
`C_*`/Enum/Constants members. Probe an optional API with `rawget(_G, "Name")`; `allow` other addons' and the
test's own globals. `Strict.methods("retail", "Frame")` is the set of real frame methods, for a mock that
rejects unknown ones instead of auto-stubbing them. With no snapshot yet it prints one line and does nothing.
The snapshots were taken with `loadDeprecationFallbacks=1` (names that exist only through it pass). To check as if a player
has it off: `opts.fallbacks = false` or `STRICT_FALLBACKS=0`; add fallback-only names to `opts.deprecated`.
`luajit $PF/tools/strict_api.lua` shows which snapshots exist.

## Contract tests

`bash $PF/tests/contracts.sh [name]` runs `tests/contracts/*.lua`: two addons' real code in one process
(harness `tests/contracts/lib.lua`: `H.fetch(client)`, `H.doorstep(client)`, `H.apply_changes`, `H.contract`).
Output is failures plus one summary line. A contract is skipped, not failed, if a repo is missing.
To add one: copy `tests/contracts/doorstep_fetch_gear.lua`, list the other addons' settings in `covers`,
assert the invariant, and make sure it fails when the invariant is broken (a positive control).

## Refreshing the API snapshot

Preflight records the client's API by itself, once per game build, ~40s after login (needs this Preflight
loaded: `bash $PF/deploy.sh`, restart the client). After a patch, or when `$PF/api/<client>.json` is missing
or its build is old (`luajit $PF/tools/strict_api.lua`):
1. log in on retail and on WoW: Forever (wait a minute), then log out or `/reload`;
2. `python3 -I $PF/tools/report.py --export-api` (writes `$PF/api/retail.json` and `forever.json`; never replaces a newer file);
3. commit `api/` in Preflight. Never read those files: they are for the scripts.

## Don't

- Don't read `api/*.json` or the whole `--summary` into context; run the commands and read the lines.
- Don't edit another addon's repo to quiet a problem line: fix the cause or ask.
- Don't add LLM-based scanning: the point is that these are cheap and exact.
