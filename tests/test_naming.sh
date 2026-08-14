#!/usr/bin/env bash
# Unit tests for naming.sh -- the pure, herdr-free name computation.
# String in / string out, so every rule is testable without a live herdr.

here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

# Pin the shell name so bare-prompt cases are deterministic regardless of $SHELL.
SHELL_NAME=zsh
. "$here/../naming.sh"

# ---- bare prompt / shells ----
check "bare prompt -> shell name" "zsh" "$(ar_format '' '')"
check "explicit shell shows own name" "bash" "$(ar_format 'bash' 'bash')"
check "fish shell name" "fish" "$(ar_format 'fish' '')"

# ---- name-only programs (editors, agents, git) ----
check "nvim is name-only" "nvim" "$(ar_format 'nvim' 'nvim README.md')"
check "claude is name-only" "claude" "$(ar_format 'claude' 'claude --dangerously-skip-permissions')"
check "git is name-only" "git" "$(ar_format 'git' 'git status')"

# NAME_ONLY_PROGRAMS only bites with SHOW_PROGRAM_ARGS=1 (0 is the default and
# already renders bare names), so assert these there. Covers the agents herdr
# 0.8.0 detects, including the two whose executable differs from its --kind id.
check "grok is name-only" "grok" "$(SHOW_PROGRAM_ARGS=1 ar_format 'grok' 'grok --model x')"
check "agy is name-only" "agy" "$(SHOW_PROGRAM_ARGS=1 ar_format 'agy' 'agy --conversation 12')"
check "opencode is name-only" "opencode" "$(SHOW_PROGRAM_ARGS=1 ar_format 'opencode' 'opencode run x')"
check "cursor-agent name-only" "cursor-agent" "$(SHOW_PROGRAM_ARGS=1 ar_format 'cursor-agent' 'cursor-agent -p x')"
check "kiro-cli is name-only" "kiro-cli" "$(SHOW_PROGRAM_ARGS=1 ar_format 'kiro-cli' 'kiro-cli chat')"
check "gemini is name-only" "gemini" "$(SHOW_PROGRAM_ARGS=1 ar_format 'gemini' 'gemini -p hi')"

# ---- ignored programs keep showing the shell ----
check "ls is ignored -> shell" "zsh" "$(ar_format 'ls' 'ls -la')"
check "cd is ignored -> shell" "zsh" "$(ar_format 'cd' 'cd ..')"

# ---- regular programs show their command line (SHOW_PROGRAM_ARGS default on) ----
SHOW_PROGRAM_ARGS=1
check "regular program shows cmdline" "htop -d 5" "$(ar_format 'htop' 'htop -d 5')"
check "regular program, args off -> name only" "psql" "$(SHOW_PROGRAM_ARGS=0 ar_format 'psql' 'psql -h db')"

# ---- program aliases win over category ----
PROGRAM_ALIASES=("clx=hn" "lazygit=lg")
check "alias clx->hn" "hn" "$(ar_format 'clx' 'clx --nerdfonts')"
check "alias lazygit->lg" "lg" "$(ar_format 'lazygit' 'lazygit')"
PROGRAM_ALIASES=()

# ---- substitutions ----
check "poetry shell -> poetry" "poetry" "$(ar_format 'poetry' 'poetry shell')"
check "ipython3 collapse" "ipython3" "$(ar_format 'ipython3' '/usr/bin/ipython3')"

# ---- truncation (MAX_NAME_LEN), counted by codepoint ----
check "truncates to MAX_NAME_LEN" "12345678901234567890" \
  "$(MAX_NAME_LEN=20 ar_format 'x' '123456789012345678901234567890')"
# A multibyte string must be cut on a codepoint boundary, never mid-byte.
check "multibyte truncation is clean" "ünïcödé" \
  "$(MAX_NAME_LEN=7 ar_format 'x' 'ünïcödéxxxxxxx')"

# ---- icons ----
# Expected glyphs are built from explicit UTF-8 byte escapes rather than pasted
# literals: bash 3.2 has no $'\uXXXX', and the Private Use Area codepoints these
# tests assert on are precisely what an editor or a copy-paste silently ate once
# before (the old ar_icon shipped with every arm returning "", so enabling icons
# was a no-op through v0.2.1). Byte escapes cannot be eaten that way, so these
# tests still fail loudly if the glyphs ever vanish from icons.sh again.
g_nvim=$(printf '\xee\x9a\xae')      # U+E6AE nf-custom-neovim
g_vim=$(printf '\xee\x98\xab')       # U+E62B nf-custom-vim
g_git=$(printf '\xee\x9c\x82')       # U+E702 nf-dev-git
g_node=$(printf '\xee\x9c\x98')      # U+E718 nf-dev-nodejs_small
g_python=$(printf '\xee\x9c\xbc')    # U+E73C nf-dev-python
g_docker=$(printf '\xef\x8c\x88')    # U+F308 nf-linux-docker
g_cargo=$(printf '\xee\x9e\xa8')     # U+E7A8 nf-dev-rust
g_go=$(printf '\xee\x98\xa7')        # U+E627 nf-seti-go
g_agent=$(printf '\xf3\xb0\x9a\xa9') # U+F06A9 nf-md-robot
g_htop=$(printf '\xee\xae\xa2')      # U+EBA2

# ar_icon must return a real glyph per program group, not the empty string.
check "ar_icon nvim" "$g_nvim" "$(ar_icon nvim)"
check "ar_icon vim" "$g_vim" "$(ar_icon vim)"
check "ar_icon gvim" "$g_vim" "$(ar_icon gvim)"
check "ar_icon git" "$g_git" "$(ar_icon git)"
check "ar_icon lazygit" "$g_git" "$(ar_icon lazygit)"
check "ar_icon node" "$g_node" "$(ar_icon node)"
check "ar_icon pnpm" "$g_node" "$(ar_icon pnpm)"
check "ar_icon python3" "$g_python" "$(ar_icon python3)"
check "ar_icon docker" "$g_docker" "$(ar_icon docker)"
check "ar_icon cargo" "$g_cargo" "$(ar_icon cargo)"
check "ar_icon go" "$g_go" "$(ar_icon go)"
check "ar_icon claude" "$g_agent" "$(ar_icon claude)"
check "ar_icon codex" "$g_agent" "$(ar_icon codex)"
# htop used to be the "unknown program" sentinel; the upstream map knows it.
check "ar_icon htop" "$g_htop" "$(ar_icon htop)"

# Every agent herdr detects gets the robot glyph, not just the original three.
# The arms are split across several case patterns, so walk the whole set: a
# dropped or mistyped entry then fails here instead of silently losing its icon.
for _agent in aider pi gemini cursor cursor-agent devin cline agy antigravity \
  omp mastracode opencode copilot kimi droid amp kiro kiro-cli \
  grok hermes kilo qodercli; do
  check "ar_icon $_agent" "$g_agent" "$(ar_icon "$_agent")"
done

# A program missing from the map gets the fallback glyph by default; an empty
# ICON_FALLBACK turns that off and restores the old empty-returning contract.
check "ar_icon unknown -> fallback" "?" "$(ar_icon nosuchprog)"
check "ar_icon unknown, fallback off -> empty" "" "$(ICON_FALLBACK='' ar_icon nosuchprog)"
# The fallback must never apply to the empty argument (ar_format only asks for
# a real program; ar_icon '' is a guard, not a lookup).
check "ar_icon empty arg -> empty" "" "$(ar_icon '')"
check "ar_icon empty arg -> empty" "" "$(ar_icon '')"

# ICON_MAP overrides win over both the builtin map and the fallback. (Arrays
# cannot be passed as a command prefix -- bash exports them as a flat string --
# so the assignment is a separate statement before the call, as elsewhere.)
check "ICON_MAP overrides builtin glyph" "$g_vim" "$(
  ICON_MAP=("nvim=${g_vim}")
  ar_icon nvim
)"
check "ICON_MAP covers unknown program" "$g_agent" "$(
  ICON_MAP=("nosuchprog=${g_agent}")
  ar_icon nosuchprog
)"

# The icon part, end to end through ar_format.
check "(icon name) is glyph + name" "$g_nvim nvim" \
  "$(TAB_LABEL='icon name' ar_format 'nvim' 'nvim')"
check "(icon name) joins with a space" "$g_git git" \
  "$(TAB_LABEL='icon name' ar_format 'git' 'git status')"
check "(icon) is glyph only" "$g_nvim" \
  "$(TAB_LABEL=icon ar_format 'nvim' 'nvim')"
check "a list without icon shows no glyph" "nvim" \
  "$(TAB_LABEL=name ar_format 'nvim' 'nvim')"

# The default (name) never prepends a glyph, even for a known program.
check "default -> no glyph" "nvim" "$(ar_format 'nvim' 'nvim')"
# Unknown program with the icon part and the fallback off: plain name, no glyph.
check "icon part, fallback off, unknown -> plain name" "nosuchprog" \
  "$(TAB_LABEL='icon name' ICON_FALLBACK='' SHOW_PROGRAM_ARGS=0 ar_format 'nosuchprog' 'nosuchprog -d 5')"
# Unknown program with the icon part: fallback glyph + name.
check "icon part, unknown -> fallback glyph + name" "? nosuchprog" \
  "$(TAB_LABEL='icon name' SHOW_PROGRAM_ARGS=0 ar_format 'nosuchprog' 'nosuchprog -d 5')"
# An ignored program keeps showing the shell, so it gets no icon either --
# even though sudo has a real glyph in the map and ls would hit the fallback.
check "icon part, ignored program -> shell name, no icon" "zsh" \
  "$(TAB_LABEL='icon name' ar_format 'sudo' 'sudo apt update')"
# Shells get no icon even when the map knows them (zsh is in icons.sh, dash is
# not): precmd names an idle prompt via ar_format "" "", which `[ -n "$prog" ]`
# denies an icon, so a shell glyph here would flip the label between "zsh" and
# "<glyph> zsh" on every reconcile. The last check pins both paths to the same
# string.
check "icon part, shell program -> shell name, no icon" "zsh" \
  "$(TAB_LABEL='icon name' ar_format 'zsh' '-zsh')"
check "icon part, shell missing from map -> no fallback glyph" "dash" \
  "$(TAB_LABEL='icon name' ar_format 'dash' '')"
check "idle prompt and shell reconcile agree with the icon part" \
  "$(TAB_LABEL='icon name' ar_format '' '')" \
  "$(TAB_LABEL='icon name' ar_format "$SHELL_NAME" '')"
# SHELL_NAME follows the user's real login shell, which can sit outside the
# fixed SHELLS six (nu, tcsh, elvish, ...). prog == SHELL_NAME is its own
# shell arm, so a reconcile reads the bare name (never the cmdline, even with
# SHOW_PROGRAM_ARGS=1 -- "-elvish" would dodge a name-based comparison) and
# gets no glyph or fallback, keeping it equal to the idle prompt.
check "odd login shell (elvish) gets no icon" "elvish" \
  "$(SHELL_NAME=elvish TAB_LABEL='icon name' ar_format 'elvish' '')"
check "odd login shell outside map (nu) -> no fallback glyph" "nu" \
  "$(SHELL_NAME=nu TAB_LABEL='icon name' ar_format 'nu' '')"
check "odd login shell with args on -> shell name, no icon" "elvish" \
  "$(SHELL_NAME=elvish TAB_LABEL='icon name' SHOW_PROGRAM_ARGS=1 ar_format 'elvish' '-elvish')"
check "idle and odd-shell reconcile agree with args on" \
  "$(SHELL_NAME=elvish TAB_LABEL='icon name' SHOW_PROGRAM_ARGS=1 ar_format '' '')" \
  "$(SHELL_NAME=elvish TAB_LABEL='icon name' SHOW_PROGRAM_ARGS=1 ar_format 'elvish' '-elvish')"
# Under (icon) a lone fallback glyph would be the whole label, so it falls
# back to the plain name; (icon name) still shows "? name" (pinned above).
check "(icon) with unknown program -> plain name" "nosuchprog" \
  "$(TAB_LABEL=icon SHOW_PROGRAM_ARGS=0 ar_format 'nosuchprog' 'nosuchprog -d 5')"
# ICON_MAP works end to end through ar_format.
check "ICON_MAP override end to end" "$g_agent nosuchprog" \
  "$(
    ICON_MAP=("nosuchprog=${g_agent}")
    TAB_LABEL='icon name' SHOW_PROGRAM_ARGS=0 ar_format 'nosuchprog' 'nosuchprog -x'
  )"

# A glyph is one codepoint, so "<glyph> <name>" must be truncated by codepoint,
# never mid-byte. node is not name-only, so its cmdline is long enough to cut:
# MAX_NAME_LEN=6 keeps the glyph, the space, and 4 chars of the name.
check "icon+name truncates on codepoint boundary" "$g_node node" \
  "$(TAB_LABEL='icon name' MAX_NAME_LEN=6 SHOW_PROGRAM_ARGS=1 ar_format 'node' 'nodeandmore')"

# ---- HIDE_SHELL: every shell-ish case names the tab nothing (issue #5) ----
# The empty label is what makes herdr fall back to rendering its own tab number,
# so these must be EMPTY strings, not $SHELL_NAME and not a space.
check "hide_shell bare prompt" "" "$(HIDE_SHELL=1 ar_format '' '')"
check "hide_shell explicit fish" "" "$(HIDE_SHELL=1 ar_format 'fish' '-fish')"
check "hide_shell explicit bash" "" "$(HIDE_SHELL=1 ar_format 'bash' 'bash')"
check "hide_shell ignored ls" "" "$(HIDE_SHELL=1 ar_format 'ls' 'ls -la')"
# The login shell is hidden too, even outside SHELLS and with args on: without
# the prog == SHELL_NAME arm, "nu" would name itself on reconcile while the
# idle prompt stays blank (the HIDE_SHELL gap from the 0.4.0 release).
check "hide_shell login shell outside SHELLS (nu)" "" \
  "$(SHELL_NAME=nu HIDE_SHELL=1 SHOW_PROGRAM_ARGS=1 ar_format 'nu' '-nu')"
# Only shells are hidden: a real program is named exactly as before.
check "hide_shell keeps nvim" "nvim" "$(HIDE_SHELL=1 ar_format 'nvim' 'nvim README.md')"
check "hide_shell keeps program" "htop" "$(HIDE_SHELL=1 SHOW_PROGRAM_ARGS=0 ar_format 'htop' 'htop -d 5')"
# An alias is a label the user asked for by hand, so it outlives the knob.
check "hide_shell keeps alias on a shell" "sh" \
  "$(
    PROGRAM_ALIASES=("fish=sh")
    HIDE_SHELL=1 ar_format 'fish' '-fish'
  )"
# Off (the default) is the old behavior, unchanged.
check "hide_shell off -> shell name" "zsh" "$(HIDE_SHELL=0 ar_format '' '')"
got=$(bash -c 'SHELL_NAME=zsh; . "$1"; ar_format "" ""' _ "$here/../naming.sh")
check "HIDE_SHELL defaults to off" "zsh" "$got"

# ---- default: SHOW_PROGRAM_ARGS defaults to 0 (regular program -> name only) ----
got=$(bash -c 'SHELL_NAME=zsh; . "$1"; ar_format htop "htop -d 5"' _ "$here/../naming.sh")
check "SHOW_PROGRAM_ARGS defaults to name-only" "htop" "$got"

# ---- config arrays: an intentionally-empty override must survive the guard ----
# naming.sh uses `declare -p`, not `${arr+x}` (which reports a zero-element array
# as unset and would silently restore the default list). Source it fresh in a
# subshell with IGNORED_PROGRAMS=() and confirm `ls` is no longer suppressed.
got=$(bash -c 'SHELL_NAME=zsh; SHOW_PROGRAM_ARGS=1; IGNORED_PROGRAMS=(); . "$1"; ar_format ls "ls -la"' _ "$here/../naming.sh")
check "empty IGNORED_PROGRAMS override survives" "ls -la" "$got"

# ---- ar_condense_title: shortening an agent's own task summary ----
# Selection only: every word in the output appears in the input. The rule is drop
# the leading verb, drop filler, then take whole words until the budget is spent.
# The budget is pinned to 20 here so each check exercises one rule against a
# known horizon; the default (30) is asserted separately at the end.
MAX_TASK_LEN=20
check "drops the leading verb" "screensaver-timeout" \
  "$(ar_condense_title 'Adjust screensaver timeout on the Ubuntu box')"
check "drops filler mid-title" "flaky-auth-test" \
  "$(ar_condense_title 'Debug flaky auth test in payments service')"
check "drops leading filler after the verb" "nightly-ETL-job" \
  "$(ar_condense_title 'Investigate why the nightly ETL job silently drops rows')"
check "drops a phrasal-verb particle" "tailscale-proxmox" \
  "$(ar_condense_title 'Set up Tailscale on the Proxmox box')"
check "keeps an identifier token" "RFC7-wording-clarity" \
  "$(ar_condense_title 'Review RFC7 wording clarity and suggest changes')"
check "a hyphenated word stays whole" "off-by-one-error" \
  "$(ar_condense_title 'Fix off-by-one error in the rolling window')"
# A title herdr's own stripping left a state glyph on must not open with it, and
# a slash separates words rather than joining them.
check "strips a leading state glyph" "herdr-tab-workspace" \
  "$(ar_condense_title '◐ Review Herdr tab/workspace/agent numbering proposal')"
# Truncation stops at the first word that does not fit. Taking a later, shorter
# word instead would read as a non sequitur beside the words before it.
check "stops at the first word that does not fit" "memory-leak" \
  "$(ar_condense_title 'Investigate memory leak in the streaming pipeline')"
check "single over-long word is cut to the budget" "abcdefghijklmnopqrst" \
  "$(ar_condense_title 'abcdefghijklmnopqrstuvwxyz')"
check "respects a MAX_TASK_LEN override" "screensaver" \
  "$(MAX_TASK_LEN=12 ar_condense_title 'Adjust screensaver timeout on the Ubuntu box')"
# The separator only changes the joint, never which words are chosen...
check "TITLE_WORD_SEPARATOR=' ' reads like the phrase" "screensaver timeout" \
  "$(TITLE_WORD_SEPARATOR=' ' ar_condense_title 'Adjust screensaver timeout on the Ubuntu box')"
# ...and a wider one pays for itself out of the same budget: " - " costs three
# characters per joint, so "test" (12+3+4) no longer fits in 15.
check "separator length counts against the budget" "flaky - auth" \
  "$(MAX_TASK_LEN=15 TITLE_WORD_SEPARATOR=' - ' ar_condense_title 'Debug flaky auth test')"
check "a title of only filler condenses to nothing" "" \
  "$(ar_condense_title 'to the and of')"
check "a verb alone condenses to nothing" "" "$(ar_condense_title 'Refactor')"
check "an empty title condenses to nothing" "" "$(ar_condense_title '')"
# A one-word title (herdr falls back to the directory) is already a label.
check "a bare one-word title is kept" "myrepo" "$(ar_condense_title 'myrepo')"

# ---- TITLE_CASE: what happens to the title's capitals ----
# fold (the default) downcases sentence case but spares all-caps-and-digits
# identifiers; lower folds those too; keep leaves the agent's casing alone.
_ct='Review the ETL Sync for RFC7 compliance'
check "TITLE_CASE defaults to fold"        "ETL-sync-RFC7" "$(ar_condense_title "$_ct")"
check "TITLE_CASE=lower folds identifiers" "etl-sync-rfc7" "$(TITLE_CASE=lower ar_condense_title "$_ct")"
check "TITLE_CASE=keep keeps the casing"   "ETL-Sync-RFC7" "$(TITLE_CASE=keep ar_condense_title "$_ct")"

# An agent that badges its title spends the budget on its own name first.
# opencode writes "OC | <task>", so the badge goes and the task stays.
check "drops a short all-caps badge" "reviewing-unpushed" \
  "$(ar_condense_title 'OC | Reviewing unpushed local git commits')"
check "badge with no spaces around the pipe" "reviewing-unpushed" \
  "$(ar_condense_title 'OC|Reviewing unpushed local git commits')"
# The cap and the upper-case requirement are what keep it off real content: a
# lower-case or longer leading word is a word, not a badge. The pipe still
# separates, so nothing is glued together.
check "lower-case leading word is content" "auth-login-flow" \
  "$(ar_condense_title 'auth | login flow rewrite')"
check "a long leading word is content" "LONGER-parser-fix" \
  "$(ar_condense_title 'LONGER | parser fix that matters')"
# A pipe anywhere else is only a separator.
check "a mid-title pipe separates" "parser-fix" \
  "$(ar_condense_title 'parser | fix')"
# A title that is nothing but a badge leaves the tab to fall back.
check "a badge alone condenses to nothing" "" "$(ar_condense_title 'OC |')"

# ---- TAB_LABEL: wiring the condensed title into ar_format ----
_title='Adjust screensaver timeout on the Ubuntu box'
# "name" is the default, and is the old behavior: an agent tab reads its name.
check "name is the default -> agent name" "claude" "$(ar_format 'claude' 'claude' "$_title")"
got=$(bash -c 'SHELL_NAME=zsh; . "$1"; ar_format claude claude "Adjust screensaver timeout on the Ubuntu box"' _ "$here/../naming.sh")
check "TAB_LABEL defaults to name" "claude" "$got"
check "task -> agent tab named after the task" "screensaver-timeout" \
  "$(TAB_LABEL=task ar_format 'claude' 'claude' "$_title")"
# Which panes get a title is herdr's call, made in the engine by
# ar_pane_agent_title, so this function does not test the program: whatever it
# is named, a tab handed a title is named from it. codex reports its program as
# `node`, which is exactly why the program name cannot be the gate (scenario 19
# in test_reconcile.sh covers the engine side).
check "the program name is not the gate" "screensaver-timeout" \
  "$(TAB_LABEL=task ar_format 'node' 'node' "$_title")"
check "bare prompt ignores the title" "zsh" \
  "$(TAB_LABEL=task ar_format '' '' "$_title")"
# Falling back keeps a tab named rather than blank whenever the title yields
# nothing: absent, or entirely verb and filler.
check "no title -> falls back to agent name" "claude" \
  "$(TAB_LABEL=task ar_format 'claude' 'claude' '')"
check "unusable title -> falls back to agent name" "claude" \
  "$(TAB_LABEL=task ar_format 'claude' 'claude' 'to the and of')"
# An alias renames the agent's NAME wherever the mode puts it, and never turns
# the task display off. Under "task" the name appears only in the fallback.
check "task outranks an alias" "screensaver-timeout" \
  "$(
    PROGRAM_ALIASES=("claude=cc")
    TAB_LABEL=task ar_format 'claude' 'claude' "$_title"
  )"
check "the alias names the no-title fallback" "cc" \
  "$(
    PROGRAM_ALIASES=("claude=cc")
    TAB_LABEL=task ar_format 'claude' 'claude' 'to the and of'
  )"
# While herdr detects an agent in the pane, the task also outranks the shell
# and quick-command fallbacks for that pane: the label stays on the task while
# an `ls` or a bare prompt (say, a suspended agent) holds the foreground.
check "a quick command keeps the agent's task" "screensaver-timeout" \
  "$(TAB_LABEL=task ar_format 'ls' 'ls' "$_title")"
check "a shell prompt in the pane keeps the task" "screensaver-timeout" \
  "$(TAB_LABEL=task ar_format 'zsh' 'zsh' "$_title")"
# The engine hands ar_format the DETECTED agent (4th argument) alongside the
# title; the name part, its alias, the glyph and the no-title fallback then key
# to the agent, not to whatever holds the pane's foreground -- a suspended
# agent's shell prompt stays that agent's tab.
check "the agent, not the foreground, owns the task" "claude:screensaver" \
  "$(TAB_LABEL='name task' ar_format 'zsh' 'zsh' "$_title" 'claude')"
check "the agent fallback outranks the foreground" "claude" \
  "$(TAB_LABEL=task ar_format 'zsh' 'zsh' 'to the and of' 'claude')"
check "the agent fallback goes through the alias" "cc" \
  "$(
    PROGRAM_ALIASES=("claude=cc")
    TAB_LABEL=task ar_format 'zsh' 'zsh' 'to the and of' 'claude'
  )"
check "the agent's glyph rides a suspended pane" "$g_agent screensaver" \
  "$(TAB_LABEL='icon task' ar_format 'zsh' 'zsh' "$_title" 'claude')"
# The glyph and its space are priced out of the task budget before the task is
# condensed, so the final truncation never cuts a chosen word in half...
check "the glyph is priced out of the task budget" "$g_agent auth-flow" \
  "$(TAB_LABEL='icon task' MAX_TASK_LEN=14 ar_format 'claude' 'claude' 'Fix the auth flow sync')"
# ...and the pricing happens in jq, by codepoint: under a C locale bash counts
# bytes and would charge this three-letter alias as six.
got=$(LC_ALL=C bash -c 'SHELL_NAME=zsh; PROGRAM_ALIASES=("claude=ééé"); TAB_LABEL="name task"; MAX_TASK_LEN=7; . "$1"; ar_format claude claude "Fix auth flow"' _ "$here/../naming.sh")
check "a non-ASCII alias is priced in codepoints" "ééé:aut" "$got"
# Garbage-in: duplicate parts collapse to one during normalization, so the
# budget and the rendering cannot disagree.
check "duplicate parts collapse" "auth-flow" \
  "$(
    TAB_LABEL=(task task)
    MAX_TASK_LEN=12
    ar_format 'claude' 'claude' 'Fix auth flow'
  )"
check "duplicate icons collapse beside a task" "? auth-flow" \
  "$(TAB_LABEL='icon icon task' ar_format 'zsh' 'zsh' 'Fix the auth flow' 'unknown-agent')"
# HIDE_SHELL blanks shell labels, not a rendered task in a shell-fronted pane.
check "HIDE_SHELL spares a rendered task" "screensaver-timeout" \
  "$(HIDE_SHELL=1 TAB_LABEL=task ar_format 'zsh' 'zsh' "$_title")"
# The icon stays keyed to the agent, not the label text: (icon task) carries
# the agent's glyph before the task, and (icon) alone shows the glyph as for
# any program, title or not. A task with nothing to show yields its place to
# the name, so on a plain tab (icon task) reads like (icon name), and a
# suspended agent with an unusable title reads the agent's name, never a bare
# glyph.
check "(icon task) carries the agent's glyph" "$g_agent auth-flow" \
  "$(TAB_LABEL='icon task' ar_format 'claude' 'claude' 'Fix the auth flow')"
check "(icon) shows the glyph alone, title or not" "$g_agent" \
  "$(TAB_LABEL=icon ar_format 'claude' 'claude' 'Fix the auth flow')"
check "(icon task) on a plain tab keeps glyph and name" "$g_nvim nvim" \
  "$(TAB_LABEL='icon task' ar_format 'nvim' 'nvim')"
check "(icon task) on an unknown plain tab reads like (icon name)" "? rg" \
  "$(TAB_LABEL='icon task' ar_format 'rg' 'rg')"
check "the name stands in for an unusable title" "$g_agent claude" \
  "$(TAB_LABEL='icon task' ar_format 'zsh' 'zsh' 'to the and of' 'claude')"
check "no stand-in when a name part is listed" "$g_agent claude" \
  "$(TAB_LABEL='icon name task' ar_format 'zsh' 'zsh' 'to the and of' 'claude')"
# The lone-fallback rule keys on PROVENANCE recorded at lookup time, not on
# glyph or label values: a task equal to ICON_FALLBACK survives, a MAPPED
# glyph equal to ICON_FALLBACK survives, and fallback icons cannot slip a
# "? ?" through.
check "a task equal to ICON_FALLBACK survives" "auth-flow" \
  "$(ICON_FALLBACK='auth-flow' TAB_LABEL=task ar_format 'claude' 'claude' 'Fix the auth flow')"
check "a mapped glyph equal to ICON_FALLBACK survives" "X" \
  "$(
    ICON_MAP=("mapped=X")
    ICON_FALLBACK=X TAB_LABEL=icon ar_format 'mapped' 'mapped'
  )"
# ...and provenance also distinguishes "unmapped" from an EXPLICIT empty
# override: "<program>=" is the user suppressing that icon, which must not be
# refilled with the fallback -- next to a name, or budgeted beside a task.
check "an explicit empty override suppresses the icon" "nvim" \
  "$(
    ICON_MAP=("nvim=")
    TAB_LABEL='icon name' ar_format 'nvim' 'nvim'
  )"
check "an empty override suppresses the glyph beside a task" "auth-flow" \
  "$(
    ICON_MAP=("claude=")
    TAB_LABEL='icon task' ar_format 'claude' 'claude' 'Fix the auth flow'
  )"
check "duplicate fallback icons fall back to the name" "rg" \
  "$(
    TAB_LABEL=(icon icon)
    ar_format 'rg' 'rg'
  )"
check "an empty TAB_LABEL falls back to the name" "claude" \
  "$(TAB_LABEL="" ar_format 'claude' 'claude')"
check "a task label obeys MAX_TASK_LEN" "screensaver" \
  "$(MAX_TASK_LEN=12 TAB_LABEL=task ar_format 'claude' 'claude' "$_title")"

# ---- TAB_LABEL=(name task): composing the agent's name with its task ----
check "(name task) opens with the agent" "claude:screensaver" \
  "$(
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' "$_title"
  )"
# The parts render in the order the config wrote them.
check "parts are honored in order" "auth-flow:claude" \
  "$(
    TAB_LABEL=(task name)
    ar_format 'claude' 'claude' 'Fix the auth flow'
  )"
# The alias is the user's short form for the agent, so it is the prefix too.
check "the prefix maps through PROGRAM_ALIASES" "cc:screensaver" \
  "$(
    PROGRAM_ALIASES=("claude=cc")
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' "$_title"
  )"
# Prefix, colon and task share the one budget: 12 leaves "claude:" five
# characters of task, and the whole label lands exactly on MAX_TASK_LEN.
check "prefix and task fit MAX_TASK_LEN together" "claude:scree" \
  "$(
    MAX_TASK_LEN=12
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' "$_title"
  )"
# A budget the prefix exhausts drops the title, not the name -- and a title
# that yields nothing never leaves a dangling joint.
check "prefix that exhausts the budget -> name alone" "claude" \
  "$(
    MAX_TASK_LEN=7
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' "$_title"
  )"
check "unusable title under the prefix -> name alone" "claude" \
  "$(
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' 'to the and of'
  )"
check "unusable title under the prefix keeps the bare alias" "cc" \
  "$(
    PROGRAM_ALIASES=("claude=cc")
    TAB_LABEL=(name task)
    ar_format 'claude' 'claude' 'to the and of'
  )"
# An explicit "name", and anything unrecognized, is the default behavior.
check "part name alone ignores the title" "claude" \
  "$(TAB_LABEL=name ar_format 'claude' 'claude' "$_title")"
check "an unknown part is ignored" "claude" \
  "$(TAB_LABEL=bogus ar_format 'claude' 'claude' "$_title")"
# An intentionally-empty word list must survive the declare -p guard, the same as
# every other list: the title is then shortened without dropping anything.
got=$(bash -c 'SHELL_NAME=zsh; TAB_LABEL=task; MAX_TASK_LEN=20; TITLE_LEAD_VERBS=(); TITLE_FILLER_WORDS=(); . "$1"; ar_format claude claude "Adjust screensaver timeout on the Ubuntu box"' _ "$here/../naming.sh")
check "empty title word lists survive" "adjust-screensaver" "$got"

# The default budgets, exercised in a fresh shell: a task label gets
# MAX_TASK_LEN's 30 (this title lands on exactly 30), and ar_format's final
# truncation must measure it against that same budget rather than
# MAX_NAME_LEN's 20, or the label built here would be chopped right back.
got=$(bash -c 'SHELL_NAME=zsh; . "$1"; ar_condense_title "Adjust screensaver timeout on the Ubuntu box"' _ "$here/../naming.sh")
check "a task label defaults to a 30 budget" "screensaver-timeout-ubuntu-box" "$got"
got=$(bash -c 'SHELL_NAME=zsh; TAB_LABEL=task; . "$1"; ar_format claude claude "Adjust screensaver timeout on the Ubuntu box"' _ "$here/../naming.sh")
check "the final truncation honors the task budget" "screensaver-timeout-ubuntu-box" "$got"

t_summary
