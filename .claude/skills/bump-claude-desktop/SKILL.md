---
name: bump-claude-desktop
description: Bump app-misc/claude-desktop-bin in this Gentoo overlay to the newest upstream Claude Desktop release — creates the new ebuild, regenerates the thick Manifest, verifies the .deb still matches what src_install expects, test-builds it, and commits and pushes when nothing risky changed. Use this whenever the user mentions Claude Desktop and versions, releases, updates, or bumps in any form: "bump claude desktop", "is there a new claude desktop", "update claude-desktop-bin", "check the claude desktop ebuild", "any new desktop release?" — and also when they ask to bump or check "the desktop app" while working in this overlay, even if they never say the package name.
---

# Bumping app-misc/claude-desktop-bin

Upstream publishes only a `.deb`, with no changelog and no release notes. So the
real question in a bump is never "what version is out" — it's "does the existing
ebuild still describe this package correctly?" Everything that answers that
question is already implemented in `scripts/bump.sh`. Run it, read the verdict,
and act on it. Don't reimplement its checks by hand: it downloads ~340 MB and
unpacks a 200 MB Electron binary, and reproducing that inline burns a large
amount of context for facts the script already summarised in 30 lines.

## Run it

```bash
bash .claude/skills/bump-claude-desktop/scripts/bump.sh
```

If the user only wants to know *whether* something is out, add `--check-only` —
it reads the apt index and stops, downloading nothing. The full run starts with
the same check and exits for free when there's nothing to do, so there's no
reason to run both.

Useful when a bump needs follow-up work: `--version VER` targets a specific
release, `--keep-build` leaves the build tree in `/var/tmp/portage` for
inspection.

The script creates the new ebuild as a copy of the previous version, regenerates
the Manifest, then diffs the new `.deb` against the previous one along every axis
the ebuild depends on: upstream's own `Depends`/`Recommends` on both arches, the
`NEEDED` sonames of the bundled Electron binary, the executable set, the icon
set, the `.desktop` entry, the app tree, the bundled Electron version, and the
paths `src_install` reaches for (read out of the ebuild's own `fperms`/`domenu`/
`dodoc` lines, so the checks follow the ebuild if it's ever reworked). Finally it
runs `ebuild clean install` and inspects the resulting image.

It ends with one of four verdicts.

## Acting on the verdict

**UP-TO-DATE** — say so in a sentence and stop. Nothing was written.

**SMOOTH** — the new ebuild is a straight copy and everything it relies on is
unchanged. Commit and push without asking; that's the whole point of the verdict.

**REVIEW** — something moved. Do *not* commit. Explain in plain terms what
changed and why it matters for the ebuild (the script prints the diff under
"what changed" and its concern under "needs your judgement"), then ask whether to
proceed. Some examples of what turns up here and what it implies:

- *deb Depends/Recommends changed* — `RDEPEND` was derived from these, so it
  probably needs a corresponding change.
- *NEEDED sonames changed* — the bundled Chromium links something new; find the
  Gentoo package owning that soname and add it to `RDEPEND`.
- *executable set changed* — a new bundled helper may need its own `fperms`, and
  possibly `pax-mark`. Harmless additions inside `app.asar.unpacked` usually just
  need mentioning in the commit message.
- *Electron major bump* — re-check `RDEPEND` and the comment that names the
  Electron version.
- *.desktop entry changed* — check `Exec` and the WM_CLASS/app_id against the
  `dosym` and the `domenu` filename, since compositors group windows by it.

If you end up editing the new ebuild, re-run the script afterwards. It keeps the
existing ebuild, refreshes the Manifest (the EBUILD digest changes with any
edit), shows your edit as a diff against the previous version, and re-tests the
build.

**FAIL** — the bump doesn't work as-is. Report what blocked it and leave the
tree alone for the user to decide on. The new ebuild and Manifest may already
be written; say so rather than silently reverting them.

## Committing

Keep every older ebuild — this overlay deliberately retains them.

Match the established message style: a subject of
`app-misc/claude-desktop-bin: add <version>`, then a body that says what was
verified rather than just what was added, since "the ebuild is a straight copy"
is only meaningful alongside the evidence. Take the facts from the script's
report.

```
app-misc/claude-desktop-bin: add 1.32352.1

Upstream's apt repo has 1.32352.1 for both amd64 and arm64. The .deb
Depends/Recommends, the NEEDED soname list of the bundled Electron
binary, the executable file set, and the icon sizes are all unchanged
from 1.30096.1, so the ebuild is a straight copy.

The bundled Electron goes 42.7.0 -> 42.9.2, still the same major, so
the RDEPEND comment about Electron 42 stays accurate.

Keeping 1.24012.11 and 1.30096.1 alongside it.
```

Push to `main`; that's where this overlay's version bumps have always landed.

Afterwards, remind the user the new version only becomes visible to `emerge`
once they sync, since Portage reads the separate root-owned clone:

```
sudo emaint sync -r cono && emerge -av claude-desktop-bin
```

## Guardrails

Everything happens in this checkout, which is itself a valid overlay
(`metadata/layout.conf` sets `repo-name = cono`), so `ebuild` runs as your normal
user with no `sudo`. Never write to `/var/db/repos/cono` — it's root-owned and
Portage syncs it from GitHub.

Never hand-edit the `Manifest`. This overlay uses thick manifests, so it needs
`EBUILD` and `MISC` digest lines alongside the `DIST` ones; `ebuild ... manifest`
produces all of them correctly and the script already calls it.
