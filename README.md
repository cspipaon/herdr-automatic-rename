# herdr-automatic-rename

[![tests](https://github.com/qu8n/herdr-automatic-rename/actions/workflows/ci.yml/badge.svg)](https://github.com/qu8n/herdr-automatic-rename/actions/workflows/ci.yml)

## Features

**1. Automatic tab rename with the foreground process.** Inspired by [tmux](https://github.com/tmux/tmux)'s `automatic-rename`, each tab shows its foreground process (e.g., `nvim`, `claude`) or the shell at a bare prompt (e.g., `zsh`). Custom renames are respected. An agent tab can show [what the agent is working on](#naming-agent-tabs-after-the-work) instead of the agent's name, so several `claude` tabs stay tellable apart.

**2. Automatic prefix spaces/tabs with the 1-9 keybind jump number**. Add an `[N]` prefix to each workspace and tab matching the `1-9` binding for that slot. Glance at the tabs or sidebar, see what runs where, and quickly jump by number. Agents get one too on herdr `< 0.7.5`, which is the last release whose agent names allow it.

Each feature can be toggled and work independently.

<img width="3216" height="2088" alt="readme-demo-screenshot" src="https://github.com/user-attachments/assets/43f620c0-d667-4fa9-b76c-dbafde41b7ec" />

## Before and after

herdr labels a new tab with a number, and leaves workspace and agent rows at their plain names. One four-tab workspace, before and after (stock config: `NAME_TABS=1`, `AUTO_INDEX=1`):

```
herdr alone      │ 1       │ 2        │ 3       │ notes     │
with the plugin  │ [1] zsh │ [2] nvim │ [3] zsh │ [4] notes │
```

| Tab is running | herdr alone | with the plugin |
| --- | --- | --- |
| a bare shell prompt | `1` | `[1] zsh` |
| `nvim README.md` | `2` | `[2] nvim` |
| `ls -la`, an `IGNORED_PROGRAMS` entry | `3` | `[3] zsh` |
| a tab you renamed `notes` yourself | `notes` | `[4] notes` |

Workspaces get numbered, never renamed, so only the prefix is new:

| Sidebar row | herdr alone | with the plugin |
| --- | --- | --- |
| workspace | `dotfiles` | `[1] dotfiles` |
| agent | `claude` | `claude` (see below) |

Agents are the exception. herdr `0.7.5` restricted agent names to `^[a-z][a-z0-9_-]{0,31}$`, which no `[N] ` prefix can satisfy, so on herdr `>= 0.7.5` agent rows are left at their detected names and any `[N]` a previous version of this plugin managed to set is stripped back off. On herdr `< 0.7.5` agents still get `[1] claude`.

Turn one feature off and you keep the other half: `AUTO_INDEX=0` names without the prefix (`zsh`, `nvim`), and `NAME_TABS=0` leaves every base name as herdr or you left it and adds only the `[N]`. `SHOW_PROGRAM_ARGS=1` swaps a program's name for its whole command line, so a `npm run dev` tab reads `[2] npm run dev` rather than `[2] npm`.

Numbering also splits by item kind. `AUTO_INDEX_WORKSPACES`, `AUTO_INDEX_TABS` and `AUTO_INDEX_AGENTS` each default to whatever `AUTO_INDEX` is and override it when you set them, so `AUTO_INDEX` remains the single switch for all of it and these are the exceptions. Numbered tabs above plain workspace names is one line:

```sh
AUTO_INDEX_WORKSPACES=0
```

Setting one of those to `0` also strips the `[N]` already on those rows, at the next herdr event, so you do not have to run the `clear` action to tidy up after the change.

That cleanup runs only for a kind you name. Nothing here records which `[N]` prefixes the plugin wrote, so it cannot tell one of ours from a name you typed that opens with a bracketed number: `[1] incident` becomes `incident`. Naming the kind is how you ask for that. A config carrying only `AUTO_INDEX=0`, from before these settings existed, leaves workspace and agent labels exactly as they are. Tabs are the exception, and only under `NAME_TABS=1`: that pass runs for the naming, and has always stripped the prefix on its way through. Only digits count either way, so `[wip] deploy` is never touched.

## Naming agent tabs after the work

Naming a tab after its foreground program has one blind spot: it cannot tell two agents apart. Four `claude` tabs all read `claude`. `TAB_LABEL=task` names them after what each agent is working on instead:

```
TAB_LABEL=name        │ [1] claude              │ [2] claude          │ [3] claude       │
TAB_LABEL=task        │ [1] screensaver-timeout │ [2] nightly-ETL-job │ [3] auth-rewrite │
```

Nothing here invents a name. Every agent herdr detects already publishes a summary of its current task as the pane's terminal title, and herdr already carries that on the pane list this plugin reads, so the title is only shortened:

| The agent reports | The tab reads |
| --- | --- |
| Adjust the screensaver timeout | `screensaver-timeout` |
| Investigate why the nightly ETL job drops rows | `nightly-ETL-job-drops-rows` |
| Fix an off-by-one error in pagination | `off-by-one-error-pagination` |
| Review RFC7 wording for clarity | `RFC7-wording-clarity` |

The rule is to drop a leading verb (`TITLE_LEAD_VERBS`), drop filler (`TITLE_FILLER_WORDS`), then take whole words until `MAX_TASK_LEN` (default 30; a task's own budget, separate from the `MAX_NAME_LEN` that truncates program labels) is spent — a first word longer than the whole budget is cut to fit rather than skipped — keeping the order the agent wrote them in and joining them with `TITLE_WORD_SEPARATOR` — `-` by default, fusing the label into one token like every other tab name; set `' '` to read like the phrase the agent wrote. Casing follows `TITLE_CASE`: `fold` (default) downcases every word except all-caps-and-digits identifiers (`nightly-ETL-job`, `reviewing-unpushed`), `lower` folds the identifiers too, `keep` leaves the casing as the agent wrote it (the folding is ASCII-only — an accented capital keeps its case). Where knowing which agent owns which task matters, `TAB_LABEL=(name task)` composes the agent's name (or its `PROGRAM_ALIASES` short form) with the task, in the order written: `claude:auth-flow`, `cc:auth-flow`, or `auth-flow:cc` under `(task name)`; `(icon name task)` puts the agent's glyph in front of both. The name part spends the same `MAX_TASK_LEN` budget the task does. In every composition an alias renames the agent's name wherever it appears and never suppresses the task. Because it only ever selects words already in the title, a summary whose distinguishing word falls past the budget gives a vague label rather than a wrong one: `Review the Herdr tab/workspace/agent numbering proposal` becomes `herdr-tab-workspace-agent`. Raising `MAX_TASK_LEN` is the answer where that reads too thin.

Agents only, and herdr decides which those are: a pane qualifies once herdr publishes a detected agent on it — the same per-pane answer that names a runtime-wrapped agent. There is deliberately no list of agent programs to maintain. One would miss `codex`, whose foreground process is `node`, and would need a new entry for every agent herdr learns to detect. It matters in the other direction too: a pane herdr sees no agent in carries the shell's title, which is a working directory (`user@host:~/code/api`), and that must never become a tab name. So `nvim` keeps its own name, and so does a bare prompt. Inside a detected agent's pane the trust runs the other way: the task also outranks the shell and quick-command fallbacks, and the whole label keys to the agent herdr detected — the name part, its alias, the glyph, and the no-title fallback all follow the detection, never the shell or quick command holding the foreground. A suspended claude reads `claude:auth-flow`, not `zsh:auth-flow`; with no usable title it reads `claude`, and `(icon task)` carries the agent's glyph.

Agents differ in what they write there, so three shapes get special treatment, all matched on the title rather than on which agent produced it:

| The agent writes | Because | The tab reads |
| --- | --- | --- |
| `Adjust screensaver timeout on the Ubuntu box` | a task | `screensaver-timeout` |
| `myrepo` (its working directory) | no task in it | `codex` (the agent's own name; `WRAPPER_PROGRAMS` is what makes that `codex` and not `node`) |
| `user@host:~/vaults/notes` (the shell's prompt title) | no task in it | `claude` (the detected agent's name) |
| `OC \| Reviewing unpushed commits` | a badge, then a task | `reviewing-unpushed-commits` |

A directory — bare, as a path, or `~`-abbreviated — is the repo name the workspace label already carries, so it counts as no title at all. A `user@host:` title is the shell's, not the agent's: herdr detects an agent the moment one runs anywhere in the pane, including a headless subprocess some other program spawned, while the title is still whatever the shell last wrote. A short all-caps badge before a pipe is the agent naming itself; a lower-case or longer leading word is content and is kept.

A title that is missing, or is all verb and filler, falls back to the agent's name, so no tab is left unnamed. Off by default, since it replaces the `claude` a tab reads today, and it costs no extra herdr call on herdr `>= 0.7.2`.

If a row of `zsh` tabs tells you nothing, `HIDE_SHELL=1` names only the tabs actually running something and leaves the rest to herdr, which falls back to its own tab number:

```
HIDE_SHELL=0, AUTO_INDEX=0  │ lazygit     │ nvim     │ fish │ pi     │
HIDE_SHELL=1, AUTO_INDEX=0  │ lazygit     │ nvim     │ 3    │ pi     │
HIDE_SHELL=1, AUTO_INDEX=1  │ [1] lazygit │ [2] nvim │ [3]  │ [4] pi │
```

That covers a bare prompt, an explicit shell, and anything in `IGNORED_PROGRAMS`. With numbering on, the label keeps the jump number and nothing else, so you can still jump to the tab.

## Requirements

herdr `>= 0.7.1`, `jq`, and bash. Linux or macOS.

herdr `>= 0.7.4` is recommended. There a plugin rename repaints the tab bar immediately, so live renames appear the instant they happen; on older herdr the new name still lands but the tab bar only catches up on the next redraw (a focus change or resize). herdr `>= 0.7.2` also lets a full reconcile read its whole state in one `api snapshot` call — without it the plugin falls back to per-list queries automatically.

Two newer versions add smaller wins, both detected at runtime: on herdr `>= 0.7.5` a restored session is reconciled the moment herdr comes up rather than at the first event, and on `>= 0.8.0` reordering a worktree group renumbers immediately. Everything else works down to `0.7.1`.

## Install

```sh
herdr plugin install qu8n/herdr-automatic-rename --yes
```

Events work immediately.

### Shell hook (highly recommended)

Renames the instant a command starts. Without it, naming waits for the next focus or tab event. Source your shell's hook so that it self-locates the engine wherever herdr installed it.

**zsh** (`~/.zshrc`):

```zsh
for _f in ${HOME}/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.zsh(N); do
  source $_f; break
done
```

**bash** (`~/.bashrc`, after any prompt/history tool like starship or atuin):

```bash
for _f in "$HOME"/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.bash; do
  [ -r "$_f" ] && { source "$_f"; break; }
done
```

**fish** (`~/.config/fish/config.fish`):

```fish
for _f in $HOME/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.fish
    test -r "$_f"; and source "$_f"; and break
end
```

No-op outside a herdr pane. On bash it cooperates with bash-preexec / atuin / ble.sh, else owns `DEBUG` without clobbering an existing trap.

A command word that is not an external program (a shell function, builtin, or typo) never renames the tab directly. The hook flags it, and the engine reads the pane's real foreground process a moment later: an instant function leaves the tab name alone, and a function that opens `nvim` names the tab `nvim`.

### Turn off herdr's new-tab name prompt

herdr asks each new tab for a name (`prompt_new_tab_name`, on by default). Under `NAME_TABS=1` that prompt has nothing left to do, and a name typed into it counts as a hand rename, which opts the tab out of naming until you `reset` it. Turn it off:

```toml
# ~/.config/herdr/config.toml
[ui]
prompt_new_tab_name = false
```

New tabs then arrive with herdr's generated number for the plugin to name. Accepting the prompt's prefilled number works as well, since a bare integer reads as a placeholder, but it costs a keystroke per tab. Keep `prompt_new_workspace_name` if you use it: the plugin only prefixes workspace names, it never generates them.

## Configuration

Works with no config. To change a knob, copy the sample:

```sh
mkdir -p ~/.config/herdr-automatic-rename
cp "$(dirname "$(herdr plugin list --json | jq -r '.result.plugins[]|select(.plugin_id=="herdr-automatic-rename").source.managed_path')")"/herdr-automatic-rename-*/config.example.sh \
  ~/.config/herdr-automatic-rename/config.sh
```

Override the path with `HERDR_AUTOMATIC_RENAME_CONFIG`.

| Knob | Default | What it does |
| --- | --- | --- |
| `NAME_TABS` | `1` | Rename each tab to its foreground program. `0` leaves tab names alone. |
| `AUTO_INDEX` | `1` | Add the `[N]` jump-key number (1-9) in front of each workspace and tab (and agent on herdr `< 0.7.5`). |
| `AUTO_INDEX_WORKSPACES` | `AUTO_INDEX` | Number workspaces. Set it alone to keep numbered tabs while workspace names stay plain. |
| `AUTO_INDEX_TABS` | `AUTO_INDEX` | Number tabs. |
| `AUTO_INDEX_AGENTS` | `AUTO_INDEX` | Number agents (herdr `< 0.7.5` only, and only under the grouped panel sort). |
| `TAB_LABEL` | `name` | What a tab shows, as an ordered list of parts — `icon` (a Nerd Font glyph for the program; joins with a space, never on a shell label), `name` (the tab's text as ever), `task` (what a detected agent is working on; text parts join with `:`). `(icon name)` is the old icons look; `(name task)` reads `claude:screensaver`. A label composing to nothing falls back to the name text. Which tabs count as agents is herdr's own detection, so there is no list to keep. |
| `TITLE_LEAD_VERBS` | `review`, `adjust`, `fix`, ... | Leading verbs dropped from a title. Every agent is fixing or adding something, so the verb never says which tab this is. |
| `TITLE_FILLER_WORDS` | `a`, `the`, `to`, `on`, ... | Words dropped from a title wherever they appear. A label is not a sentence. |
| `MAX_TASK_LEN` | `30` | The length budget for a task label; tasks run longer than program names, so they have their own. When the parts include `name`, its text and joint share it, so a short alias buys the task more room. |
| `TITLE_WORD_SEPARATOR` | `-` | What joins the words of a task label. The default fuses it into one token (`nightly-ETL-job`), the shape every other tab name has; `' '` reads like the phrase the agent wrote. Counts against `MAX_TASK_LEN`. |
| `TITLE_CASE` | `fold` | Casing of a task label. `fold` downcases every word except all-caps-and-digits identifiers (`nightly-ETL-job`, `reviewing-unpushed`); `lower` folds the identifiers too; `keep` leaves the agent's casing. |
| `SHOW_PROGRAM_ARGS` | `0` | `0` shows just the program name (`git`), `1` shows its full command line (`git log --oneline`). |
| `MAX_NAME_LEN` | `20` | Cut a program or command-line label off after this many characters. Task labels have their own budget, `MAX_TASK_LEN`. |
| `SHELL_NAME` | `$SHELL` basename | Label shown at an idle prompt when no program is running (e.g. `zsh`). |
| `HIDE_SHELL` | `0` | `1` gives a shell tab no name at all, so herdr's own tab number shows there instead of `zsh`. Covers the login shell (`SHELL_NAME`), not just the fixed `SHELLS` list. |
| `SHELLS` | `zsh bash sh fish dash ksh` | Programs counted as "a shell prompt" and shown by their own name. |
| `NAME_ONLY_PROGRAMS` | editors, git tools, agents | Programs always shown by bare name, never with args (`nvim`, `claude`). |
| `IGNORED_PROGRAMS` | `ls`, `cd`, `cat`, ... | Quick commands that should not rename the tab. It keeps showing the shell instead. |
| `WRAPPER_PROGRAMS` | `node`, `npx`, `bun`, `python`, ... | Language runtimes and package runners that front for the program you launched. In a pane herdr has detected an agent in, the tab is named after that agent instead of the runtime. |
| `PROGRAM_ALIASES` | none | Force a specific program to a custom label, e.g. `("lazygit=lg" "claude=cc")`. This plugin's rewrite (herdr itself has no aliasing) and needs no other knob: `claude=cc` renames every claude tab on its own. For an agent behind a runtime wrapper the key is the name herdr detects (`codex`, not `node`) — `herdr agent list` prints those names. Under `TAB_LABEL` the alias follows the name wherever the parts put it (the name part, or the no-title fallback) and never suppresses the task. |
| `SUBSTITUTE_SETS` | two rules | `sed -E` rewrites that tidy up the label, e.g. to shorten a path-heavy command line. |
| `ICON_FALLBACK` | `?` | Glyph for programs missing from the builtin map (~170 programs, from tmux-nerd-font-window-name's `defaults.yml`). `''` turns the fallback off. A label that would be nothing but the fallback (a bare `?` under `(icon)`) keeps the plain name instead. |
| `ICON_MAP` | none | Per-program icon overrides, `("prog=glyph")` pairs; wins over the builtin map. |

`config.example.sh` documents each with examples.

## Actions

- `reset`: re-adopt a hand-renamed tab.
- `clear`: strip every `[N]`, restore base names, revert agents to detection.

Run from the CLI, or bind a key:

```sh
herdr plugin action invoke herdr-automatic-rename.reset
```

```toml
# ~/.config/herdr/config.toml (example binding)
[[keys.command]]
key = "alt+shift+r"
type = "plugin_action"
command = "herdr-automatic-rename.reset"
```

## Uninstall

Strip labels first (else `clear`'s renames re-fire the hooks), then remove:

```sh
bash "$(herdr plugin list --json \
  | jq -r '.result.plugins[]|select(.plugin_id=="herdr-automatic-rename").source.managed_path')/automatic-rename.sh" --clear
herdr plugin uninstall herdr-automatic-rename
```

## Notes

- **Manual renames win.** Rename a tab yourself and naming leaves it alone. Numbering still applies. `clear` the label or `reset` to hand it back.
- **Agent numbering needs herdr `< 0.7.5`.** That release added a name rule (`^[a-z][a-z0-9_-]{0,31}$`) that rejects a bracketed number outright, so newer herdr leaves agent rows alone and strips any prefix an older setup left behind. Where it does apply, it also needs grouped (`spaces`) sort, the mode whose CLI order matches the panel `focus_agent` follows. In `priority` sort that order is API-invisible, so numbers are stripped there too.
- **Tab names go quiet on Linux runtimes with no foreground process group.** Naming reads the pane's foreground process, and some container and sandbox setups leave herdr unable to see one, which makes tab naming do nothing at all (numbering is unaffected). herdr `>= 0.8.0` has an opt-in fallback: set `HERDR_PROCESS_DETECTION=child-groups` in its environment. It is best-effort by herdr's own account, since in that mode a background job can look like the foreground one, so a tab may occasionally follow the wrong process.
- **Collapsing a space renumbers.** `alt+N` counts the sidebar's visible rows, so a collapsed space hides its worktree workspaces from numbering and every row below it moves up. The hidden ones go bare until you expand. Focusing one of those worktrees while the space stays collapsed renders that row again, which shifts the rows below it back down. herdr publishes collapse only in `session.json`, on a 5-second debounce and with no event to hook, so the first jump right after a collapse can still use the old numbers.
- **Stops at 9.** No binding reaches a 10th item, so `10+` stay bare.

## Development

Engine: `automatic-rename.sh` (bash 3.2, needs only `jq` and the herdr CLI). Pure naming: `naming.sh` (icons: `icons.sh`). Tests need only bash and jq:

```sh
./tests/run.sh            # all
./tests/run.sh reconcile  # one file
```

They cover the naming rules, the `[N]` prefix helpers, the state machine, the shell hooks, and a full reconcile against a fake `herdr`.

## License

MIT. See [LICENSE](LICENSE).
