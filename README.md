# `guixy rusty toy`

**guix import crate: Cargo.lock v4 truncation issue**

Minimal end-to-end reproducer for a silent-truncation bug in
`guix import crate --lockfile=...` when the lockfile contains
source-disambiguated dependency entries (Cargo.lock v3+).

## The bug

`guix/import/crate/cargo-lock.scm`'s PEG `dependency-specification`
rule matches `<name>` or `<name> <version>` only.  It does not handle
the trailing source annotation cargo emits when a dep matches
multiple `[[package]]` blocks, e.g.

```toml
dependencies = [
 "log 0.4.29 (registry+https://github.com/rust-lang/crates.io-index)",
 "regex",
]
```

PEG's `+` operator silently stops on the first match failure.
The PEG `dependencies = …` section is optional, so the first
offending `[[package]]` block parses successfully as "no deps",
leaving `dependencies = …` unconsumed in the input; the outer
parser then fails to find the next `[[package]]` block and
stops.  The importer exits `0` having emitted packages
alphabetically up to and including the first offender — every
later entry is silently dropped.

## Repro layout

This repo is a Cargo workspace with two members:

```console
app/      hello-world binary, depends on env_logger (which
          transitively wants `log = "0.4"` from crates.io) and
          on the local shadow `log` crate via path
log/      local crate named `log` at the same version cargo picks
          for the registry version (0.4.29), with one extra dep
          (`cfg-if`) so its declared dependencies diverge from
          the published `log 0.4.29` on crates.io
```

The divergence is the trigger: cargo can't treat the two `log 0.4.29`
crates as interchangeable, so it keeps both as separate `[[package]]`
blocks in `Cargo.lock`.  Any dep entry that references `log` now
needs source disambiguation, which appears as
`"log 0.4.29 (registry+...)"` in env_logger's dependency list.

## Reproducing

```bash
cd guixy-rusty-toy

# 1. Enter the dev shell (rust + cargo + git + openssl + nss-certs)
guix shell --pure -m manifest.scm

# 2. Generate the lockfile via cargo
cargo generate-lockfile

# 3. Confirm the disambiguation pattern is present
grep '(registry+' Cargo.lock | head    # several "log 0.4.29 (registry+...)" lines

# 4. Run the (unpatched) system guix importer
> /tmp/out.scm
guix import -i /tmp/out.scm crate --lockfile=Cargo.lock app
echo "Cargo.lock [[package]] count: $(grep -c '^\[\[package\]\]' Cargo.lock)"
echo "imported defines:             $(grep -c '^(define rust-' /tmp/out.scm)"
```

Observed on guix master `7309f55` with a 32-entry lockfile: **9 defines emitted**,
23 silently dropped (~72% loss).  Expected: ~30 (all entries with a `source`
field; the two workspace-only members are correctly skipped).

## The fix

Extend `dependency-specification` in
`guix/import/crate/cargo-lock.scm` to optionally consume the
` (<source>)` suffix:

```scheme
;; dependency specification
(define-peg-pattern dependency-specification all
  (and crate-name
       (? (and (ignore " ") crate-version))
       (? (ignore (and " (" crate-source ")")))))
```

The source itself is discarded since the importer only enumerates
`[[package]]` blocks for crate-source emission and does not consult
per-dep disambiguation.

Running the patched importer against this repo's lockfile:

```bash
> /tmp/out-patched.scm
( cd /path/to/patched/guix && guix shell -D guix --pure -- \
    ./pre-inst-env guix import -i /tmp/out-patched.scm crate \
    --lockfile=$REPRODUCER/Cargo.lock app )
grep -c '^(define rust-' /tmp/out-patched.scm    # 30 defines (was 9)
```
