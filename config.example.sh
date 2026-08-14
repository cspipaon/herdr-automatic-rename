# herdr-automatic-rename configuration.
#
# Copy to ~/.config/herdr-automatic-rename/config.sh and uncomment what you want to
# change (or point $HERDR_AUTOMATIC_RENAME_CONFIG somewhere else). This file is sourced
# by automatic-rename.sh BEFORE naming.sh, so anything set here wins over the defaults.
# Every setting has a working default, so an empty config is fine.

# ---- feature toggles (both default on) ----

# Auto-name each tab after its foreground program (the shell name at a bare
# prompt). Set to 0 to leave tab names alone.
# NAME_TABS=1

# Prefix workspaces and tabs with their 1-9 jump-key number, e.g. "[2] api". Set
# to 0 to name without numbering. Agents are included only on herdr < 0.7.5:
# newer herdr rejects a bracketed agent name, so those rows keep their detected
# names (and lose any prefix an older setup left on them).
# AUTO_INDEX=1

# Numbering, per item kind. Each defaults to AUTO_INDEX and overrides it when
# set, so AUTO_INDEX stays the one knob for "number everything" or "number
# nothing" and these carve out the exceptions. Numbered tabs with plain
# workspace names, for instance, is the first line on its own:
# AUTO_INDEX_WORKSPACES=0
# AUTO_INDEX_TABS=1
# AUTO_INDEX_AGENTS=1
#
# Setting one of these to 0 also removes the prefixes already on those rows, on
# the next herdr event -- no need to run the "clear" action.
#
# That cleanup cannot tell one "[N] " apart from another. Nothing records which
# prefixes this plugin wrote, so a name you typed yourself that starts with a
# bracketed number, say "[1] incident", loses the bracket too. Naming the kind
# here is how you ask for the cleanup and accept that. A config with only
# AUTO_INDEX=0 in it never triggers it, so workspace and agent labels stay as
# they are. Tabs are the exception, and only under NAME_TABS=1: that pass runs
# for the naming, and has always taken the prefix off on its way through.
# Anything else in brackets ("[wip] foo") is left alone, digits are the only
# trigger.

# ---- naming knobs (only used when NAME_TABS=1) ----

# 1 = a regular program shows its full command line ("psql -h db"); 0 = just its
# name ("psql"). Default 0.
# SHOW_PROGRAM_ARGS=0

# Truncate a program or command-line label to this many characters (counted by
# codepoint). A task label has its own budget, MAX_TASK_LEN below.
# MAX_NAME_LEN=20

# Name shown at a bare prompt. Defaults to your $SHELL's basename.
# SHELL_NAME=zsh

# 1 = don't name a shell tab at all: a bare prompt, an explicit shell, an
# IGNORED_PROGRAMS command, and the login shell itself (SHELL_NAME, which may be
# outside the SHELLS list) all leave the label empty, and herdr shows its own
# tab number there instead of "zsh". With AUTO_INDEX=1 the label keeps the jump
# number alone ("[3]"). Programs are named as usual either way.
# HIDE_SHELL=0

# What a tab shows: an ordered list of parts, one model for every tab.
#
#   icon   a Nerd Font glyph for the program (needs a Nerd Font; ICON_FALLBACK
#          and ICON_MAP below pick which glyph). Joined to its neighbors by a
#          space. Never on a shell label.
#   name   the tab's text as ever: the program (through PROGRAM_ALIASES), its
#          command line under SHOW_PROGRAM_ARGS, or the shell's name.
#   task   what a detected agent is working on: "screensaver-timeout". Every
#          supported agent already publishes a short summary of the current
#          task as its terminal title, so nothing is invented here: that title
#          is only shortened to a label. Renders nothing on other tabs. Five
#          claude tabs under (task) then read "screensaver-timeout",
#          "nightly-ETL-job", ... instead of "claude" five times.
#
# (name) is the default and the old behavior; (icon name) is the old icons
# look. Text parts join with ":", in the order written: (name task) reads
# "claude:screensaver" and (task name) flips it. When name and task share a
# label they fit the one MAX_TASK_LEN budget: the task gives up what the name
# part takes, so a short alias buys it more room. May be written as an array
# or as one space-separated string (TAB_LABEL="icon name"); unknown parts are
# ignored.
#
# A label that composes to nothing falls back to the name text, so no tab is
# left unnamed, PROGRAM_ALIASES renames the NAME wherever it appears
# (including that fallback), and an alias never turns the task display off.
# herdr's own detection decides which tabs count as agents (see below). While
# herdr detects an agent in a pane, the whole label keys to that agent: the
# task outranks the shell and quick-command fallbacks, and the name part, its
# alias, the glyph and the no-title fallback follow the detection rather than
# whatever holds the foreground. A suspended claude reads "claude:auth-flow",
# not "zsh:auth-flow"; with no usable title it reads "claude", and (icon task)
# carries the agent's glyph.
# TAB_LABEL=name
#
# The shortening drops a leading verb, drops filler words, then takes whole words
# until MAX_TASK_LEN (default 30, its own knob below) is spent, keeping the
# order the agent wrote them in:
#
#   "Adjust the screensaver timeout"                 -> "screensaver-timeout"
#   "Investigate why the nightly ETL job drops rows" -> "nightly-ETL-job-drops-rows"
#   "Fix an off-by-one error in pagination"          -> "off-by-one-error-pagination"
#
# It only ever selects words from the title, so a summary whose distinguishing
# word falls past MAX_TASK_LEN gives a vague label rather than a wrong one
# ("Review the Herdr tab/workspace/agent numbering proposal" ->
# "herdr-tab-workspace-agent"). Raising MAX_TASK_LEN is the fix when that reads
# too thin.
#
# Agents differ in what they put there, so three shapes are handled:
#
#   - A title that is just the working directory -- bare, as a path, or
#     "~"-abbreviated -- carries no task (codex titles a pane "myrepo"). It is
#     treated as absent, and the tab keeps the agent's own name.
#     WRAPPER_PROGRAMS is what makes that read "codex" rather than the "node"
#     wrapper codex runs as.
#   - A "user@host:..." title is the shell prompt's, not the agent's: herdr
#     detects an agent the moment one runs anywhere in the pane (a headless
#     subprocess some other program spawned counts) while the title is still
#     whatever the shell last wrote. Treated as absent too.
#   - A short all-caps badge before a pipe is the agent naming itself, not the
#     task ("OC | Reviewing unpushed commits"), and is dropped. Lower-case or
#     longer leading words are content and are kept.
#
# All are matched on the shape of the title rather than on which agent wrote
# it, so there is no list of agents here to fall out of date.
#
# A title that is missing, or is all verb and filler, leaves the tab named after
# the agent as before, so a tab is never left unnamed by this.
#
# Which tabs this applies to is herdr's call, not a list here: a pane counts as
# an agent once herdr publishes a detected agent on it. That is why there is no
# knob naming the agents. A program list would miss codex, which runs as `node`,
# and would need extending for every agent herdr learns to detect. It also keeps
# the rule safe in the other direction: a pane herdr sees no agent in carries a
# shell's title, which is a working directory ("user@host:~/code/api"), and that
# is never condensed into a tab name.

# Leading verbs dropped from a title: they say nothing about which tab this is.
# TITLE_LEAD_VERBS=(review adjust add fix update create make check investigate debug ...)

# Words dropped from a title wherever they appear. A label is not a sentence.
# TITLE_FILLER_WORDS=(a an the to for of on in at and or with from into via ...)

# The length budget for a task label (counted by codepoint). Tasks run longer
# than program names by nature, so they have their own budget; MAX_NAME_LEN
# keeps governing program and command-line labels. When the parts include the
# name, the whole label -- name, joint and task -- fits this one number.
# MAX_TASK_LEN=30

# What joins the words of a task label. The default "-" fuses the label into
# one token ("nightly-ETL-job"), the shape every other tab name has; set ' '
# to read like the phrase the agent wrote. Its length counts against
# MAX_TASK_LEN like any other character.
# TITLE_WORD_SEPARATOR='-'

# The casing of a task label (ASCII-only: an accented capital keeps its case).
# "fold" (default) downcases every word
# except all-caps-and-digits identifiers: "nightly-ETL-job",
# "reviewing-unpushed". A sentence-case capital is just how the agent writes;
# an identifier's shape carries meaning. "lower" folds the identifiers too
# ("nightly-etl-job"); "keep" leaves the casing as the agent wrote it.
# TITLE_CASE=fold

# Programs that count as "a shell prompt" and are shown by their own name.
# Assigning the array replaces the default; SHELLS=() disables the category.
# SHELLS=(zsh bash sh fish dash ksh)

# Programs shown by name only, without command-line args. Coding agents live
# here so an agent tab reads "claude" instead of its full invocation.
# NAME_ONLY_PROGRAMS=(nvim vim vi view gvim git lazygit gitui lazydocker claude codex aider)

# Quick commands that should not take over the tab name: while one runs, the tab
# keeps showing the shell so it does not flicker.
# IGNORED_PROGRAMS=(ls eza ll la cd z zoxide cat bat less more echo pwd clear which man head tail wc cp mv rm mkdir touch fzf sudo doas)

# Language runtimes and package runners that front for the program you actually
# launched. An agent installed from npm is usually a bin shim pointing at a JS
# entrypoint, so the foreground process is `node` and the tab would be named
# after the runtime; pip and pipx console scripts do the same through `python`.
# When one of these is the foreground program in a pane herdr has detected an
# agent in, the tab is named after that agent instead ("codex", not "node").
# Both conditions are needed, so a plain `node server.js` tab keeps its name.
# Add your interpreter here if it resolves to a versioned name (python3.12).
# WRAPPER_PROGRAMS=(node bun deno npx bunx npm pnpm yarn python python3 uv uvx pipx ruby)

# Rename specific programs on the tab. "<program>=<label>" pairs. This is this
# plugin's rewrite -- herdr itself has no aliasing -- and it needs no other
# knob: "claude=cc" makes every claude tab read "cc" on its own. The key is the
# program name the tab would otherwise show, which for an agent behind a
# runtime wrapper is the name herdr detects ("codex", not "node"); `herdr agent
# list` prints the names herdr uses. Under TAB_LABEL the alias follows
# the agent's name wherever the parts put it -- the name part in (name task)
# ("cc:auth-flow"), the no-title fallback under (task) -- and never suppresses
# the task itself.
# PROGRAM_ALIASES=(
#   "lazygit=lg"
#   "claude=cc"
# )

# Ordered `sed -E` rewrites applied to the final label.
# SUBSTITUTE_SETS=(
#   's|.*ipython([32])|ipython\1|'
#   's|.*poetry shell.*|poetry|'
# )

# Whether and where a glyph appears is TAB_LABEL's call (its "icon" part, at
# the top of this file); the two knobs below pick WHICH glyph.

# Glyph shown when a program is missing from the builtin map (which comes from
# tmux-nerd-font-window-name's defaults.yml, ~170 programs). An empty string
# turns the fallback off, so unknown programs get no icon. A label that would
# be nothing but the fallback (a bare "?" under (icon)) says nothing about the
# program, so the plain name is kept instead. Shell labels never get an icon
# either way (SHELLS, the login shell, and IGNORED_PROGRAMS commands): the tab
# is showing the shell, not the program.
# ICON_FALLBACK='?'

# Per-program icon overrides, "<program>=<glyph>" pairs; wins over the builtin
# map and the fallback. Glyphs are literal Nerd Font characters.
# ICON_MAP=(
#   "claude=󰚩"
#   "lazygit=󰊢"
# )
