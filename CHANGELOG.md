# Changelog

All notable changes to herdr-automatic-rename are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/), and the project uses
[semantic versioning](https://semver.org/).

## [Unreleased]

### Added

- `TAB_LABEL` picks what a tab shows, as an ordered list of parts --
  `icon` (a Nerd Font glyph for the program), `name` (the tab's text as
  ever) and `task` (what a detected agent is working on). `(name)` is the
  default and the old behavior; `(icon name)` is the old icons look; text
  parts join with `:`, so `(name task)` reads `claude:auth-flow`, in the
  order written. Under `(task)`, several `claude` tabs stop reading
  `claude`; naming by foreground program has no other way to separate them.

  Nothing is generated. Every agent herdr detects already publishes a summary of
  its current task as the pane's terminal title, and that title already arrives
  on the pane list this plugin reads for naming, so the work is only to shorten
  it: drop a leading verb, drop filler, then take whole words until
  `MAX_TASK_LEN` (default 30, a task's own budget; program and command-line
  labels keep `MAX_NAME_LEN`) is spent, keeping the order the agent wrote them
  in. "Adjust the screensaver timeout" becomes `screensaver-timeout`.

  Because it only selects words already in the title, a summary whose
  distinguishing word falls past the budget gives a vague label rather than a
  wrong one: "Review the Herdr tab/workspace/agent numbering proposal" becomes
  `herdr-tab-workspace-agent`. Raising `MAX_TASK_LEN` is the answer where that
  reads too thin.

  The default stays `name`, since `task` replaces the `claude` a tab reads
  today. Which tabs count as agents is herdr's own detection, read from the agent herdr publishes
  on the pane object (the same field the runtime-wrapper fix trusts), rather
  than a list of agent program names: a name list misses `codex`, whose
  foreground process is `node`, and would need an entry for every agent herdr
  learns to detect. It matters in the other direction too, because a pane herdr sees no
  agent in carries the shell's title, which is a working directory, and that must
  never become a tab name.

  A title that is missing or is all verb and filler falls back to the agent
  name, through its `PROGRAM_ALIASES` alias when one is set, so no tab is left
  unnamed. In every mode an alias renames the agent's NAME wherever the mode
  puts it (the whole label, the prefix, or that fallback) and never turns the
  task display off. While herdr detects an agent in the pane, the whole label
  keys to that agent: the task outranks the shell and quick-command fallbacks,
  and the name part, its alias, the glyph and the no-title fallback follow the
  detection rather than the foreground, so a suspended claude reads
  `claude:auth-flow`, never `zsh:auth-flow`. Costs no extra herdr call, and
  the title lookup is skipped entirely in `name` mode. Length budgeting is
  done in codepoints inside jq, so a non-ASCII alias or a glyph is never
  overcharged by bash's byte counting, and a glyph is priced out of the task
  budget up front rather than truncating a chosen word afterward.

  Agents differ in what they put in that title, so three shapes are handled,
  all matched on the title itself rather than on which agent wrote it. A title
  that is just the working directory (bare, as a path, or "~"-abbreviated)
  carries no task, so it counts as absent and the tab keeps the agent's own
  name, which the 0.6.1 wrapper fix already resolves to `codex` rather than
  the `node` wrapper. A `user@host:...` title is the shell prompt's, not the
  agent's -- herdr detects an agent the moment one runs anywhere in the pane,
  a headless subprocess some other program spawned included, while the title
  is still whatever the shell last wrote -- and counts as absent too. A short
  all-caps badge before a pipe is the agent naming itself and is dropped, so
  opencode's `OC | Reviewing unpushed commits` becomes
  `reviewing-unpushed-commits`; a lower-case or longer leading word is content
  and is kept.

- `TITLE_LEAD_VERBS` and `TITLE_FILLER_WORDS` are the word lists behind the
  above, overridable like every other naming list. `TITLE_WORD_SEPARATOR` is
  what joins the words that survive: `-` by default, fusing the label into one
  token (`nightly-ETL-job`), the shape every other tab name has; `' '` reads
  like the phrase the agent wrote. Its length counts against `MAX_TASK_LEN`
  like any other character.

- `TITLE_CASE` sets the casing of the label. `fold` (default) downcases every
  word except an all-caps-and-digits identifier (`nightly-ETL-job`,
  `reviewing-unpushed`): a sentence-case capital is how the agent writes, not
  signal, while an identifier's shape carries meaning and case costs no
  budget. `lower` folds the identifiers too; `keep` leaves the title as the
  agent cased it.

- `TAB_LABEL=(name task)` opens the label with the agent that owns
  it: `claude:auth-flow`, or through `PROGRAM_ALIASES`, `cc:auth-flow`. (The
  alias knob itself needs no parts: `claude=cc` renames every claude tab on
  its own, keyed by the name herdr detects for a wrapped agent.)
  The task alone cannot say WHO is on it when several agents share a workspace.
  The parts fit the one `MAX_TASK_LEN` budget -- the task gives up the
  characters the name part takes, so a short alias buys it more room -- and a
  title that yields nothing leaves the tab named after the agent alone, never
  a dangling joint.

### Changed

- BREAKING: `ICONS_ENABLED` and `ICON_STYLE` are gone. Icons are now the
  `icon` part of `TAB_LABEL`, the one composition model for every tab, and
  the old looks translate directly:

      ICONS_ENABLED=1                    ->  TAB_LABEL=(icon name)
      ICONS_ENABLED=1 ICON_STYLE=icon    ->  TAB_LABEL=(icon)
      ICON_STYLE=name, or icons off      ->  TAB_LABEL=(name)

  One model instead of two knobs that could fight: `ICON_STYLE=icon`
  silently discarded whatever the text was, including a task label the user
  had just opted into. As a part, the icon composes instead of overriding,
  and future parts have a home without another mode knob. Where there is no
  task, the task part yields its place to the name text (unless a name part
  is listed on its own), so `(icon task)` reads glyph+task on agent tabs and
  glyph+name on other program tabs (shells stay text-only, as ever). `ICON_FALLBACK`
  and `ICON_MAP` are untouched: they pick WHICH glyph, `TAB_LABEL` says
  whether and where. A config that sets none of the removed knobs is
  unaffected: the default `(name)` renders exactly what it always did.

## [0.6.1] - 2026-08-14

### Fixed

- An agent whose entrypoint is an interpreted script named its tab after the
  interpreter. An npm bin shim is a JS file behind a node shebang, so the kernel
  execs the runtime and the pane's foreground process is `node` on every
  platform: a codex pane read `node`. Before 0.2.3 the same pane read
  `MainThread` -- the resolution chain then had no argv[0] step, so a Linux
  pane (no argv0) fell through to the process's `name`, which for node is its
  thread name; the #6 fix moved these tabs from `MainThread` to `node`. A pip
  or pipx installed agent hits the same thing through `python`, its console
  script being a shebang file too. (An agent whose package ships or execs a
  native binary -- claude, opencode -- reports its own name and was never
  affected.)

  Where the foreground program is a language runtime or package runner (the new
  `WRAPPER_PROGRAMS` list) and herdr has detected an agent in that pane, herdr's
  answer is used instead and the tab reads `codex`. The agent is read off the
  pane objects the reconcile already holds -- herdr publishes its detection
  result on the pane itself -- so the lookup costs no extra herdr call on any
  version.

  Both conditions are required, so a plain `node server.js` tab keeps its name,
  and an agent that reports its own name never consults the pane's agent field.
  Identification stays herdr's job on purpose: its detector already unwraps
  runtime-fronted agents, so a pane it cannot identify is an upstream detection
  gap, not something this plugin second-guesses from `argv`.

## [0.6.0] - 2026-08-13

Splits the `[N]` jump-key numbering by item kind. `AUTO_INDEX_WORKSPACES`,
`AUTO_INDEX_TABS` and `AUTO_INDEX_AGENTS` each override `AUTO_INDEX` for one
kind of row, so numbered tabs above plain workspace names is one line of
config.

Nothing changes for a config that names none of the new knobs. `AUTO_INDEX`
still switches all three kinds together.

### Added

- `AUTO_INDEX_WORKSPACES`, `AUTO_INDEX_TABS` and `AUTO_INDEX_AGENTS` split the
  `[N]` numbering by item kind ([#8](https://github.com/qu8n/herdr-automatic-rename/issues/8)).
  Each defaults to `AUTO_INDEX` and overrides it when set, so numbered tabs above
  plain workspace names is `AUTO_INDEX_WORKSPACES=0` on its own. Existing
  configs are unaffected: `AUTO_INDEX` still switches all three together.

### Changed

- Setting one of the new per-kind knobs to `0` strips the `[N]` already on those
  rows at the next event, instead of leaving them until the `clear` action.

  Only a knob you set does this. The strip cannot tell a prefix this plugin
  wrote from one you typed, so a hand-picked `[1] incident` would lose its
  bracket, and naming the kind is how you ask for that. A config carrying only
  `AUTO_INDEX=0` never triggers it: workspace and agent labels there are left
  alone, exactly as before. Tabs are the one kind already stripped this way
  whenever `NAME_TABS=1`, and that is unchanged. Only all-digit brackets are
  ever touched; `[wip] deploy` is safe throughout.

## [0.5.0] - 2026-08-07

Grows the icon map from 9 entries to ~170 and makes it configurable, with
`ICON_FALLBACK` for programs it does not know and `ICON_MAP` for per-program
overrides.

Upgrade note for anyone already running `ICONS_ENABLED=1`: programs outside the
map now show a `?` where they previously showed no glyph at all. Set
`ICON_FALLBACK=''` to keep them text-only.

### Added

- The icon map moved out of `naming.sh` into `icons.sh` and grew from 9
  entries to the full `tmux-nerd-font-window-name` map (its
  [`defaults.yml`](https://raw.githubusercontent.com/joshmedeski/tmux-nerd-font-window-name/main/bin/defaults.yml),
  ~170 programs), keeping the aliases this plugin always shipped (gvim/view,
  bun/npx/pnpm, ipython/ipython3) and a robot glyph for every agent herdr
  detects.
- `ICON_FALLBACK` (default `?`): glyph shown when a program is missing from
  the map, like upstream's `fallback-icon`. `''` turns the fallback off and
  keeps unknown programs text-only. Under `ICON_STYLE=icon` the fallback is
  treated as "no glyph", so an unknown program keeps its plain name (`rg`, not
  `?`).
- `ICON_MAP`: per-program icon overrides as `("prog=glyph")` pairs, checked
  before the builtin map (e.g. `ICON_MAP=("claude=󰚩")`).
- Shell labels get no icon even when the map has them: `precmd` names an idle
  prompt without a program, so a glyph would flip the label between `zsh` and
  `<glyph> zsh` on every reconcile. This covers the fixed `SHELLS` six,
  `IGNORED_PROGRAMS` commands showing the shell label, and the user's real
  login shell (`SHELL_NAME`), which can sit outside `SHELLS` (nu, tcsh,
  elvish, ...).

### Fixed

- `HIDE_SHELL` now blanks the login shell itself. With 0.4.0's fixed `SHELLS`
  six, a login shell outside the list (nu, tcsh, elvish, ...) kept naming
  itself on reconcile while the idle label stayed blank.
- The login shell is recognized by program rather than by computed label:
  `prog == SHELL_NAME` is its own shell arm, so a reconcile agrees with the
  bare prompt even with `SHOW_PROGRAM_ARGS=1`, where the command-line path used
  to hijack it.

## [0.4.0] - 2026-08-05

Adds `HIDE_SHELL`, for leaving shell tabs to herdr's own tab number instead of a
row of `zsh`.

### Added

- `HIDE_SHELL=1` leaves a shell tab unnamed instead of labeling it `zsh`, so
  herdr renders its own tab number there and only the tabs running something
  carry a name (issue #5). It covers all three ways a tab gets the shell label: a
  bare prompt, an explicit `SHELLS` entry, and an `IGNORED_PROGRAMS` command. A
  `PROGRAM_ALIASES` entry for a shell still wins, being a name asked for by hand.
  `IGNORED_PROGRAMS` could never do this, despite reading like it should: its job
  is to hold a tab at the shell name, and a bare prompt short-circuits before any
  program list is consulted.
- With `AUTO_INDEX=1` a hidden tab keeps the jump number alone (`[3]`), and the
  `[N] ` prefix helpers now read that bare form back as the empty base it came
  from. Without that a hidden tab would see its own `[3]` as a hand-typed name
  and opt itself out of naming for good.

## [0.3.0] - 2026-08-04

Catches up with herdr 0.7.5 and 0.8.0. `min_herdr_version` stays at `0.7.1`: a
requirement above the running herdr is a hard load failure, so every new
capability is gated at runtime instead.

### Fixed

- Agent numbering has been silently failing since herdr `0.7.5`, in two ways at
  once, both swallowed by the `|| true` on every rename. That release stopped
  resolving `terminal_id` as an agent target (`resolve_agent_target` takes a
  current pane id or a unique agent name), and the plugin passed exactly that,
  since `terminal_id` is always present in `agent list`. It also added
  `valid_agent_name` (`^[a-z][a-z0-9_-]{0,31}$`), which rejects `[1] claude`
  outright. Renames now target `.pane_id`, the one form every supported herdr
  accepts, and agents are numbered only below `0.7.5`. At or above it the
  prefixes are stripped instead, which is also the only way to unstick an
  `[N] claude` an older herdr and older plugin left behind: that name fails
  every rename a newer herdr accepts, the documented uninstall `--clear`
  included. An unreadable herdr version counts as restricted.
- Reordering a worktree group no longer leaves stale `[N]` numbers. herdr
  `0.8.0` added `workspace.move_block` and routes any drag of a worktree-space
  member through it, which emits the new `workspace.reordered` event instead of
  `workspace.moved`. The plugin now subscribes to both, so a group drag
  renumbers immediately rather than waiting for an unrelated event.

### Added

- A `[[startup]]` hook (herdr `>= 0.7.5`) reconciles once as soon as herdr
  restores a session and after a live handoff. Restored sessions previously kept
  herdr's own labels and stale numbers until the first event happened to arrive.
- The agents herdr `0.8.0` detects are all recognized by name now, in
  `NAME_ONLY_PROGRAMS` and in the Nerd Font robot glyph: `pi`, `gemini`,
  `cursor`/`cursor-agent`, `devin`, `agy`/`antigravity`, `cline`, `omp`,
  `mastracode`, `opencode`, `copilot`, `kimi`, `kiro`/`kiro-cli`, `droid`,
  `amp`, `grok`, `hermes`, `kilo`, and `qodercli`. Two spellings differ from
  herdr's `--kind` id (`cursor-agent`, `kiro-cli`) and both forms are listed.
  Previously only `claude`, `codex`, and `aider` were, so every other agent went
  without an icon, and showed its whole command line under
  `SHOW_PROGRAM_ARGS=1`.

### Documentation

- The README records that tab naming does nothing on a Linux runtime where herdr
  cannot see a foreground process group, and points at herdr `0.8.0`'s opt-in
  `HERDR_PROCESS_DETECTION=child-groups`.
- `docs/ARCHITECTURE.md` covers the agent-name restriction and why herdr
  `0.7.5`'s `agent.view.set` would have made static agent numbers unreliable
  regardless: an active view redefines the order `focus_agent` follows, and no
  event or request exposes one.

## [0.2.3] - 2026-08-02

### Fixed

- A wrapped program on NixOS takes its tab name from the command that was typed rather than the wrapper underneath it, so `nh os switch` reads `nh` instead of `.nh-wrapped` ([#6](https://github.com/qu8n/herdr-automatic-rename/issues/6)). `ar_pane_program` read the foreground program from `argv0` and fell back to `name`, but herdr only sends `argv0` on some platforms; its Linux builds send `argv`, `cmdline`, and `name` alone. Those panes therefore named themselves after `name`, which is the on-disk executable rather than the invocation, and on NixOS the executable behind a wrapped program is `.<prog>-wrapped`. `argv[0]` holds what was typed and is present either way, so it now sits between `argv0` and `name`. `name` was a poor last resort regardless: a `claude` pane reports its version string there.

## [0.2.2] - 2026-07-29

### Fixed

- `ICONS_ENABLED=1` now actually prepends a Nerd Font glyph. Every arm of
  `ar_icon` shipped as `printf ''`, so the lookup always returned the empty
  string, the `[ -n "$ic" ]` guard in `ar_format` never passed, and all three
  `ICON_STYLE` modes did nothing. The glyphs were absent from `naming.sh` from
  its first commit, which means icons never worked in any release up to 0.2.1
  ([#3](https://github.com/qu8n/herdr-automatic-rename/issues/3)). Each arm now
  carries its codepoint in a comment so a stripped glyph can be restored, and
  the tests assert the exact bytes rather than only checking that `ICON_STYLE=name`
  suppresses the glyph, which passed happily against an empty string.

## [0.2.1] - 2026-07-26

### Fixed

- Collapsing a worktree space no longer leaves stale workspace numbers behind.
  `alt+N` counts the sidebar's visible rows, so the members a collapsed space hides
  now give up their `[N]` and every row below them moves up. Collapse state is read
  from `collapsed_space_keys` in herdr's `session.json`, the only place herdr
  publishes it (no API field, no event), on herdr's 5-second save debounce.
- A space now takes its number from its main checkout instead of whichever member
  happens to come first in `workspace list`, matching the row herdr renders at the
  head of the group.
- Two linked worktrees of a repo with no main workspace open no longer group
  together. herdr nests a space only with 2+ members and a non-linked checkout
  among them, so these number as the separate top-level rows they render as.

## [0.2.0] - 2026-07-17

### Added

- Subscribe to herdr's `pane.created` event so a split that adds a pane renames
  the tab promptly, even when the split does not move focus.

### Changed

- A full reconcile now reads its whole picture (workspaces, tabs, panes, agents)
  from a single `herdr api snapshot` call instead of one query per list plus a
  `tab list` per workspace. Needs herdr `>= 0.7.2`; older herdr falls back to the
  per-list queries automatically, so the minimum supported version stays `0.7.1`.

## [0.1.1] - 2026-07-12

### Fixed

- Calling a shell function (or builtin, reserved word, or mistyped command) no
  longer flashes that word onto the tab before the prompt reverts it. The hooks
  now classify the command word; anything that is not an external command makes
  the engine name the tab by the pane's real foreground process, sampled after
  a short settle. A function that wraps a long-running program now names the
  tab after that program instead of the function.

## [0.1.0] - 2026-07-11

First public release.

### Added

- Tab naming (`NAME_TABS`): each tab is named after its foreground program, or
  the shell name at a bare prompt. A hand rename opts the tab out.
- Jump-key numbering (`AUTO_INDEX`): workspaces, tabs, and agents are prefixed
  with the `1-9` number of the keybind that jumps to them.
- Live per-command naming through zsh, bash, and fish shell hooks that resolve
  the engine relative to their own location.
- `reset` and `clear` plugin actions.
- Configuration via `~/.config/herdr-automatic-rename/config.sh` (or
  `$HERDR_AUTOMATIC_RENAME_CONFIG`), with a documented `config.example.sh`.
- A self-contained test suite (bash + jq only) covering naming, prefix helpers,
  the state machine, the shell hooks, and a full reconcile against a fake herdr.

[Unreleased]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.6.1...HEAD
[0.6.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/qu8n/herdr-automatic-rename/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/qu8n/herdr-automatic-rename/releases/tag/v0.1.0
