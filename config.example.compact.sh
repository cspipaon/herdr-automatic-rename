# herdr-automatic-rename configuration.
#
# Copy to ~/.config/herdr-automatic-rename/config.sh (or point
# $HERDR_AUTOMATIC_RENAME_CONFIG somewhere else) and uncomment what you want to
# change. Sourced before the plugin's defaults, so anything set here wins.
# Every knob has a working default; an empty config is fine. The README covers
# the behavior behind each knob in more depth.

# ---- features ----

# Name each tab after its foreground program (the shell's name at a bare prompt).
# NAME_TABS=1

# Prefix workspaces and tabs with their 1-9 jump-key number: "[2] api".
# Agents are included only on herdr < 0.7.5; newer herdr rejects bracketed
# agent names.
# AUTO_INDEX=1

# Numbering per item kind. Each defaults to AUTO_INDEX and overrides it when
# set; numbered tabs with plain workspace names is the first line on its own.
# Setting a kind to 0 also strips the "[N] " already on those rows at the next
# event. Only all-digit brackets are touched ("[wip] foo" is safe), but a
# hand-typed "[1] incident" loses its bracket like any other.
# AUTO_INDEX_WORKSPACES=0
# AUTO_INDEX_TABS=1
# AUTO_INDEX_AGENTS=1

# ---- program labels (used when NAME_TABS=1) ----

# 1 = show a program's full command line ("psql -h db"); 0 = just its name.
# SHOW_PROGRAM_ARGS=0

# Truncate a program or command-line label to this many characters (counted by
# codepoint). Task labels have their own budget, MAX_TASK_LEN below.
# MAX_NAME_LEN=20

# Label shown at a bare prompt. Defaults to your $SHELL's basename.
# SHELL_NAME=zsh

# 1 = leave shell tabs unnamed (bare prompt, SHELLS, IGNORED_PROGRAMS commands,
# and the login shell); herdr shows its own tab number there instead of "zsh".
# HIDE_SHELL=0

# Programs that count as "a shell prompt", shown by their own name. Assigning
# the array replaces the default; SHELLS=() disables the category.
# SHELLS=(zsh bash sh fish dash ksh)

# Programs always shown by bare name, never with command-line arguments.
# NAME_ONLY_PROGRAMS=(nvim vim vi view gvim git lazygit gitui lazydocker claude codex aider)

# Quick commands that do not take over the tab name; it keeps showing the shell.
# IGNORED_PROGRAMS=(ls eza ll la cd z zoxide cat bat less more echo pwd clear which man head tail wc cp mv rm mkdir touch fzf sudo doas)

# Language runtimes and package runners that front for the program you actually
# launched: an npm-installed agent runs as "node", a pip console script as
# "python". When one of these is the foreground of a pane herdr has detected an
# agent in, the tab is named after the agent ("codex", not "node"); a plain
# `node server.js` tab keeps its name. Add your interpreter if it resolves to a
# versioned name (python3.12).
# WRAPPER_PROGRAMS=(node bun deno npx bunx npm pnpm yarn python python3 uv uvx pipx ruby)

# Fixed labels for specific programs, "<program>=<label>" pairs; works on its
# own, no other knob needed. For an agent behind a wrapper the key is the name
# herdr detects (`herdr agent list` prints them). Under AGENT_TAB_NAMES the
# alias renames the agent's name wherever the mode shows it, and never hides
# the task.
# PROGRAM_ALIASES=(
#   "lazygit=lg"
#   "claude=cc"
# )

# Ordered `sed -E` rewrites applied to program and command-line labels.
# SUBSTITUTE_SETS=(
#   's|.*ipython([32])|ipython\1|'
#   's|.*poetry shell.*|poetry|'
# )

# ---- agent task labels ----

# What a tab shows when herdr detects an agent in its pane, as an ordered list
# of parts joined by ":". herdr's detection decides which tabs those are;
# there is no agent list to maintain here.
#
#   name   the agent's own name: "claude". (name) is the default.
#   task   what the agent is working on: "screensaver-timeout", condensed from
#          the task summary agents publish as their terminal title. Nothing is
#          invented, and a missing or unusable title falls back to the name.
#
# (name task) reads "claude:screensaver", in the order written. A single part
# may be given without parens. While an agent is detected in a pane, its task
# also outranks the shell and quick-command fallbacks there, so a suspended
# agent's prompt keeps its task label. Icons stay keyed to the agent.
# AGENT_TAB_NAMES=(name)

# How a title becomes a task label: drop a leading verb, drop filler words,
# then take whole words in the agent's order until MAX_TASK_LEN is spent.
#
#   "Investigate why the nightly ETL job drops rows" -> "nightly-ETL-job-drops-rows"
#
# A title that is just the working directory carries no task and counts as
# absent; a short all-caps badge before a pipe ("OC | ...") is dropped. Both
# are matched on the title's shape, not on which agent wrote it.

# Leading verbs dropped from a title.
# TITLE_LEAD_VERBS=(review adjust add fix update create make check investigate debug ...)

# Words dropped from a title wherever they appear.
# TITLE_FILLER_WORDS=(a an the to for of on in at and or with from into via ...)

# Length budget for a task label (counted by codepoint). Under name_and_task
# the name, colon and task all share it.
# MAX_TASK_LEN=30

# What joins the words of a task label: "-" fuses it into one token, ' ' reads
# like the phrase the agent wrote. Counts against MAX_TASK_LEN.
# TITLE_WORD_SEPARATOR='-'

# Casing of a task label: "fold" downcases every word except all-caps-and-digits
# identifiers ("nightly-ETL-job"); "lower" folds the identifiers too; "keep"
# leaves the casing as the agent wrote it.
# TITLE_CASE=fold

# ---- icons ----

# Prepend a Nerd Font glyph for the program (needs a Nerd Font installed).
# ICONS_ENABLED=0

# name_and_icon | name | icon
# ICON_STYLE=name_and_icon

# Glyph for programs missing from the builtin map (~170 programs, from
# tmux-nerd-font-window-name). '' turns the fallback off. Shell labels never
# get an icon.
# ICON_FALLBACK='?'

# Per-program icon overrides, "<program>=<glyph>" pairs; wins over the builtin
# map and the fallback.
# ICON_MAP=(
#   "claude=󰚩"
#   "lazygit=󰊢"
# )
