# Merge gating for agent fleets

When an agent can open, review, and merge its own pull requests, "the tests
pass" stops being a safe reason to merge. The gate has to answer a narrower
question than a human reviewer would: not "is this good code," but "is there
independent, verifiable evidence that this exact change is safe to land,
evaluated against the exact state it will land onto." That framing is what
the rest of this guide, and the merge-gate this harness installs (see
[installation](installation.md#merge-gate)), is built around.

These principles are not specific to DeepWind's stack, CI provider, or
process. They apply to any team letting agents merge their own work.

## The principles

**Pin the judge.** A check that runs from a stale copy of the base branch, a
locally modified working tree, or a cached checkout answers a different
question than "would this merge cleanly and safely right now." Always
evaluate against a freshly fetched base ref, never a checkout that might be
hours old or hand-edited.

**Bind evidence to the exact commit, base, and check version.** A green
result is only evidence for the exact triple it was produced from: the PR's
head SHA, the base SHA it was evaluated against, and the version of the
checking logic itself. If any of the three changes — the branch gets a new
commit, the base branch advances, or the gate script itself is edited — the
old result is not evidence for the new state. Re-derive it, or prove the
change can't have affected it (see "fail closed" below).

**One source of truth per decision.** Pick one place that records whether a
given check passed for a given commit, and have every consumer read from
that place. Two systems independently deciding "did this pass review" (a
label someone can also apply by hand, and a bot that also applies the same
label) will eventually disagree, and the disagreement is invisible until an
unreviewed change merges through the weaker one.

**Preflight before expensive runs.** If your checking pipeline takes minutes
(spins up a sandbox, runs a full test suite, calls out to other services),
run a cheap, read-only preflight first: is the base fresh, does the forge's
own merge preview agree with what the PR claims its base is, did the last
attempt at this exact commit already fail, does this change delete files a
reviewer might not have noticed. None of that requires running the expensive
pipeline, and catching a doomed run before it starts is the difference
between a 30-second no and a 30-minute no. `gate-doctor.sh`, installed by
this harness, is one implementation of this idea — see below.

**The author never approves their own change.** Whatever "reviewed" means in
your process — a human approval, a separate agent's verdict, a security
sign-off — the party that produced the change cannot also be the party that
attests it. This has to be true even under a single automation account: the
identity that authored the diff and the identity that approved it must be
different, and the record of approval needs to show whose verdict it was,
not just that a label got applied.

**Fail closed, but re-run only what a change can affect.** When a check can't
be evaluated — the base can't be fetched, the checking tool errored, the
evidence is missing or stale — treat that as "not proven safe," not as "no
news is good news." At the same time, fail closed does not mean "re-run
everything on every change everywhere." If a change on the base branch is
provably disjoint from a PR's changed files (touches none of the same paths,
and none of the gate's own infrastructure), the PR's still-valid evidence
doesn't need to be re-derived just because the base moved. Blanket
re-verification on every base advance is what turns a gate into a queue that
never drains; scope the re-check to what could plausibly be affected.

**A hold pauses merges, not work.** When something is wrong (a security
review is pending, a shared resource is degraded, a bad merge needs to be
investigated), stopping new merges is often the only response that needs to
be immediate. It should not require also stopping people from writing code,
running local checks, or preparing the next change — those can and should
continue. Make "no merges right now" a fact one place can assert and every
merge path checks, rather than a status people have to remember to
communicate by hand.

**Coordinate through records, not conversation.** In a fleet of agents (or a
mix of agents and humans) operating concurrently, "I told the other agent"
is not a coordination mechanism — sessions end, messages get missed, and
nothing durable is left for the next session to pick up. Put ownership,
review status, and hold state in a place every participant reads from:
labels, a status file, a small database, whatever your tooling already has.
If it isn't recorded somewhere durable, it didn't happen as far as the next
session is concerned.

## How DeepWind does it

Internally, every merge goes through a wrapper that refuses to merge a PR
touching a sensitive path without an independent review signal recorded on
the PR itself — never a bare label a merger could apply by hand. Expensive
checks run in an isolated environment, evaluated against a freshly fetched
base branch, and produce a signed receipt keyed to the exact head SHA, base
SHA, and version of the checking logic that produced it; a stale receipt (any
one of those three has since changed) is refused rather than trusted. A
central "hold" flag pauses new merges without touching anyone's ability to
keep working. None of that is specific to our stack — it's the eight
principles above, applied to the tools we happen to use.

## What this harness installs

This harness ships two layers of this model, generic enough to apply to any
repository (see [installation](installation.md#merge-gate) for exact paths):

- **`guarded-merge.sh` / `check-sensitive-review.sh` / `agent-approve.sh`** —
  the author-never-approves and one-source-of-truth principles, applied to a
  single repo-declared policy of "which paths are sensitive" and "what counts
  as an independent review." A `PreToolUse` hook backs the same decision for
  a raw `gh pr merge`, so a coordinator can't route around the wrapper by
  using the forge CLI directly.
- **`gate-doctor.sh`** — the preflight-before-expensive-runs principle,
  applied as a fast, read-only, advisory check before you dispatch a real
  gate run (usage and configuration are documented in the script's own
  header comment). Run it directly:

  ```sh
  ~/.deepwind/bin/gate-doctor.sh <PR#>
  ```

  It checks, in a few seconds and without running your real gate:

  1. **Stale base** — has the PR's branch caught up with the base branch it
     will actually be merged onto?
  2. **Merge-ref sync** — does the forge's own merge preview agree with the
     base commit the PR claims, and with the base branch's live tip?
  3. **Prior red at this exact head** — if your team records gate outcomes
     (an opt-in, team-defined receipts directory — see the script's header),
     did the last attempt at this unchanged commit already fail? If so, the
     fix is to change the code, not to re-dispatch.
  4. **Deletions** — does this PR delete files? Not wrong by itself, but
     worth a second look before an expensive run, since a bulk delete is easy
     to miss in a large diff.

  It never changes a verdict and nothing in a real gate depends on it: it is
  purely advisory, and safe to skip, ignore, or delete. Every check degrades
  to a "could not determine" warning rather than crashing or reporting a
  false pass. Pass `--strict` to make it exit non-zero when a check comes
  back with an unresolved warning, if you want to wire it into a script.

We deliberately did **not** port our internal gate wholesale into this
harness: the internal implementation is thousands of lines wired to our own
sandbox provider, hosting-specific paths, and rule numbers that mean nothing
outside this codebase. The principles above, `gate-doctor.sh`'s four checks,
and the sensitive-path review wrapper are the parts that generalize.
