# naming.sh - pure, herdr-free name computation for herdr-automatic-rename.
#
# Sourced by automatic-rename.sh. Every function is string-in / string-out (no herdr
# or filesystem calls) so the logic is unit-testable on its own (see
# tests/test_naming.sh). Targets bash 3.2 (macOS /bin/bash): no associative
# arrays, no namerefs. Functions share the ar_ prefix with the engine, which
# calls ar_format across the module seam.
#
# Naming rule: a tab is named after its foreground program (nvim, claude, git,
# ...). At a bare prompt, or while a quick throwaway command runs, it shows the
# shell name (e.g. zsh) instead -- or nothing at all with HIDE_SHELL=1. Loosely
# modeled on tmux-window-name, minus the directory-based naming.
#
# Every list below is guarded with `declare -p` rather than `${VAR+x}`, so
# clearing one in config.sh (e.g. IGNORED_PROGRAMS=()) actually takes effect:
# `${VAR+x}` reports a zero-element array as unset and would overwrite it.

# Icon knobs, the glyph map, and ar_icon live in icons.sh (same directory) so
# this file stays free of the 100+ entry glyph table. Sourcing it here keeps
# every caller of naming.sh (automatic-rename.sh and the test suite) working
# unchanged. icons.sh loads after config.sh has run, so its defaults only fill
# unset vars.
_ar_icons_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$_ar_icons_dir/icons.sh"
unset _ar_icons_dir

# ---- configurable knobs (override in config.sh / $HERDR_AUTOMATIC_RENAME_CONFIG) ----
: "${MAX_NAME_LEN:=20}"     # truncate a program or cmdline label to this many chars (task labels: MAX_TASK_LEN)
: "${SHOW_PROGRAM_ARGS:=0}" # 1 = regular programs show their full command line; 0 = name only

# Name shown at a bare prompt (no foreground program), and while an
# IGNORED_PROGRAMS command runs, so the tab holds steady instead of flickering.
: "${SHELL_NAME:=${SHELL##*/}}"
: "${SHELL_NAME:=zsh}"

# 1 = give the tab no name at all in every case that would otherwise show the
# shell: a bare prompt, an explicit SHELLS entry, an IGNORED_PROGRAMS command.
# The empty label hands the tab back to herdr, which then renders its own tab
# number, so a shell tab reads "3" instead of "zsh" (issue #5). With AUTO_INDEX=1
# the label keeps the jump number and nothing else ("[3]"), so the tab can still
# be jumped to.
: "${HIDE_SHELL:=0}"

# Foreground processes that mean "a shell prompt" -> shown by their own name.
declare -p SHELLS >/dev/null 2>&1 || SHELLS=(zsh bash sh fish dash ksh)

# Programs shown by bare name, without command-line args (i.e. with
# SHOW_PROGRAM_ARGS=1, which is what makes this list visible). Coding agents are
# included so an agent tab reads as "claude" rather than its full invocation.
#
# The agent entries are the executable names herdr itself detects as interactive
# agents (src/detect/mod.rs, herdr 0.8.0). Two differ from herdr's --kind id and
# both spellings are listed: cursor-agent (kind "cursor") and kiro-cli (kind
# "kiro"). aider is not a herdr agent kind but is a real agent, so it stays.
declare -p NAME_ONLY_PROGRAMS >/dev/null 2>&1 || NAME_ONLY_PROGRAMS=(nvim vim vi view gvim git lazygit gitui lazydocker
  claude codex aider pi gemini cursor cursor-agent devin agy antigravity cline omp mastracode opencode
  copilot kimi kiro kiro-cli droid amp grok hermes kilo qodercli)

# Quick tools that should not take over the tab name: while one runs the tab
# keeps showing the shell (SHELL_NAME) so it does not flicker.
declare -p IGNORED_PROGRAMS >/dev/null 2>&1 || IGNORED_PROGRAMS=(ls eza ll la cd z zoxide cat bat less more echo pwd clear which man head tail wc cp mv rm mkdir touch fzf sudo doas)

# Language runtimes and package runners that front for the program you actually
# launched. An agent installed from npm is usually a bin shim pointing at a JS
# entrypoint: the kernel execs the interpreter, so the foreground process is
# node and the tab would be named after it. A pip or pipx console script is the
# same story for python. (An agent whose package ships or execs a native binary
# -- claude, opencode -- reports its own name and never needs this.)
#
# Where herdr has detected an agent in that pane, its answer is used instead (see
# ar_tab_name). Everywhere else these are named as any other program, so a plain
# `node server.js` tab is untouched.
declare -p WRAPPER_PROGRAMS >/dev/null 2>&1 || WRAPPER_PROGRAMS=(node bun deno npx bunx npm pnpm yarn
  python python3 uv uvx pipx ruby)

# What a tab shows: an ordered list of parts, one model for every tab.
#
#   icon   a Nerd Font glyph for the program (icons.sh picks which; needs a
#          Nerd Font). Joined to its neighbors by a space. Never on a shell
#          label.
#   name   the tab's text as ever: the program (through its PROGRAM_ALIASES
#          alias when one is set), its command line under SHOW_PROGRAM_ARGS,
#          or the shell's name.
#   task   what a detected agent is working on ("screensaver-timeout"). Every
#          supported agent already publishes a short summary of the current
#          task as its terminal title, so nothing here invents a name: the
#          title is only condensed to a label by ar_condense_title. Where
#          there is no task -- another kind of tab, or a missing or unusable
#          title -- it yields its place to the name text (unless a name part
#          is listed on its own), so (icon task) reads glyph+task on agent
#          tabs and glyph+name everywhere else.
#
# (name) is the default and the old behavior; (icon name) is the old icons
# look. Text parts join with ":", in the order written: (name task) reads
# "claude:auth-flow" and (task name) flips it. A label that composes to
# nothing falls back to the name text, so no tab is left unnamed and an alias
# never turns the task display off. May be written as an array or as one
# space-separated string (TAB_LABEL="icon name"); unknown parts are ignored.
declare -p TAB_LABEL >/dev/null 2>&1 || TAB_LABEL=(name)

# Leading imperative verbs dropped from a title. An agent summary is written as
# "<verb> <subject>", and the verb is the one word that says nothing about which
# tab this is: every one of them is reviewing, fixing or adding something.
declare -p TITLE_LEAD_VERBS >/dev/null 2>&1 || TITLE_LEAD_VERBS=(review adjust add fix update
  create make check investigate debug refactor implement write set setup configure explore
  improve build test run clean remove delete migrate port rename draft plan research diagnose audit)

# Words dropped from a title wherever they appear. A tab label is not a sentence,
# so articles, prepositions and phrasal-verb particles only burn the budget.
declare -p TITLE_FILLER_WORDS >/dev/null 2>&1 || TITLE_FILLER_WORDS=(a an the to for of on in at
  and or with from into via why how what that if whether is are be it its this up out off down over back)

# The length budget for a task label, in characters. A task runs longer than a
# program name by nature, so it gets its own budget rather than MAX_NAME_LEN's,
# which keeps governing program and command-line labels exactly as before.
# Everything task-shaped fits this one number: the condensed words with their
# separators, and when the parts include the name, its text and joint too.
: "${MAX_TASK_LEN:=30}"

# The string joining the words of a task label. The default "-" fuses the label
# into one token ("nightly-ETL-job"), the shape every other tab name has; set
# ' ' to read like the phrase the agent wrote. Whatever it is, its length
# counts against MAX_TASK_LEN like any other character.
: "${TITLE_WORD_SEPARATOR:=-}"

# The casing of a task label (ASCII: jq has no full Unicode downcase, so an
# accented capital keeps its case). "fold" (default) downcases every word
# except an all-caps-and-digits identifier: "nightly-ETL-job",
# "reviewing-unpushed". A sentence-case capital is how the agent writes, not
# signal; an identifier's shape carries meaning, and case costs no budget.
# "lower" folds the identifiers too ("nightly-etl-job"); "keep" leaves the
# casing as the agent wrote it. Unknown values behave as "fold".
: "${TITLE_CASE:=fold}"

# Ordered, complete `sed -E` programs applied to the final display string.
declare -p SUBSTITUTE_SETS >/dev/null 2>&1 || SUBSTITUTE_SETS=(
  's|.*ipython([32])|ipython\1|'
  's|.*poetry shell.*|poetry|'
)

# Exact program-name renames: "<program>=<label>" pairs. A matching foreground
# program is shown as <label> regardless of its category (e.g. "clx=hn" makes a
# clx tab read "hn"). Takes priority over every rule except the bare-prompt shell
# name. Set this in config.sh, e.g. PROGRAM_ALIASES=("clx=hn" "lazygit=lg").
declare -p PROGRAM_ALIASES >/dev/null 2>&1 || PROGRAM_ALIASES=()

# ---- helpers ----

# ar_in_list <needle> <list items...>
ar_in_list() {
  local n=$1 e
  shift
  for e in "$@"; do [ "$e" = "$n" ] && return 0; done
  return 1
}

# ar_alias <program> -> its PROGRAM_ALIASES label, or empty when unaliased.
ar_alias() {
  local n=$1 pair
  [ -n "$n" ] || return 0
  for pair in "${PROGRAM_ALIASES[@]}"; do
    case "$pair" in
    "$n="*)
      printf '%s' "${pair#*=}"
      return 0
      ;;
    esac
  done
}

# ar_subst <string> -> string with SUBSTITUTE_SETS applied in order
ar_subst() {
  local s=$1 expr
  for expr in "${SUBSTITUTE_SETS[@]}"; do
    s=$(printf '%s' "$s" | sed -E "$expr")
  done
  printf '%s' "$s"
}

# ar_condense_title <title> [<reserved>] -> a task label, or "".
#
# The label fits MAX_TASK_LEN minus <reserved>'s length: the caller passes the
# literal text that will share the label (a name part and its joint, a glyph
# and its space), and jq measures it in codepoints, because bash's ${#} counts
# bytes under a C locale and would overcharge anything non-ASCII.
#
# Selects; never generates. The agent already wrote the summary, so the work here
# is only to shorten it: drop a leading verb (TITLE_LEAD_VERBS), drop filler
# (TITLE_FILLER_WORDS), then take whole words from the front until the budget is
# spent, stopping at the first word that does not fit rather than skipping ahead
# (a later short word would read as a non sequitur next to the ones before it).
#
# Words are taken in the order the agent wrote them. Selecting by "distinctness"
# instead -- proper nouns, gerunds, rare words -- measurably reads worse: it
# prefers where the work happens over what it is ("screensaver Ubuntu" for
# "Adjust screensaver timeout on the Ubuntu box"), and an -ing word in these
# summaries is usually a modifier ("streaming pipeline"), so promoting it evicts
# the noun carrying the meaning. The input is already ordered by an agent that
# put the salient words first; this trusts that rather than re-ranking it.
#
# One jq program rather than a bash loop: jq is already a hard dependency, reads
# UTF-8 regardless of the ambient locale (see the truncation note in ar_format),
# and keeps this a single subprocess per tab.
ar_condense_title() {
  local title=$1 reserved=${2:-} max=${MAX_TASK_LEN:-30}
  [ -n "$title" ] || return 0
  printf '%s' "$title" | jq -Rrs \
    --argjson max "$max" \
    --arg reserved "$reserved" \
    --arg sep "${TITLE_WORD_SEPARATOR:--}" \
    --arg case "${TITLE_CASE:-fold}" \
    --arg verbs "${TITLE_LEAD_VERBS[*]}" \
    --arg filler "${TITLE_FILLER_WORDS[*]}" '
      ([$max - ($reserved | length), 0] | max) as $m
    | ($verbs  | ascii_downcase | split(" ")) as $verb
    | ($filler | ascii_downcase | split(" ")) as $fill
    # Leading state glyphs: herdr strips some agent title decorations but not
    # all, and a label must not open with a stray bullet. Separators inside the
    # title are word breaks, not characters ("tab/workspace" is two words).
    | sub("^[^\\p{L}\\p{N}]+"; "")
    # An agent that badges its title ("OC | Reviewing unpushed commits") spends
    # the budget on its own name before saying anything. Drop a short all-caps
    # token followed by a pipe: that shape is branding, and the cap plus the
    # upper-case requirement keeps it off real content ("auth | login flow"
    # keeps its first word).
    | sub("^[A-Z0-9]{1,4} *\\| *"; "")
    | gsub("[/,;:|]+"; " ")
    | [splits("[[:space:]]+")]
    | map(select(length > 0))
    | . as $words
    | (if ($words | length) > 0 and ($verb | index($words[0] | ascii_downcase))
       then $words[1:] else $words end)
    | map(. as $w | select($fill | index($w | ascii_downcase) | not))
    # Casing: a sentence-case capital is the agent writing a sentence, not
    # signal; an all-caps-and-digits token is an identifier whose shape means
    # something. "fold" spares only the identifiers, "lower" folds those too,
    # "keep" touches nothing. Anything else behaves as the "fold" default.
    | map(if $case == "keep" then .
          elif $case == "lower" then ascii_downcase
          elif test("^[A-Z0-9]{2,}$") then .
          else ascii_downcase end)
    | reduce .[] as $w ({out: "", done: false};
        if .done then .
        elif .out == "" then {out: ($w[:$m]), done: false}
        elif ((.out | length) + ($sep | length) + ($w | length)) <= $m then {out: (.out + $sep + $w), done: false}
        else {out: .out, done: true} end)
    | .out
  ' 2>/dev/null
}

# ---- helpers ----

# ar_format <program|""> <cmdline> [<terminal title>] [<agent>] -> final tab label
#   program == "" means a bare prompt (name by the shell). <agent> is the agent
#   herdr detected in the pane, when the engine looked one up.
ar_format() {
  local prog=$1 cmdline=$2 title=${3:-} agent=${4:-} name="" ic="" icfb=0 aliased is_shell=0 prefix="" rsv="" ctask="" part ptext out="" prev=""
  local -a plist=() praw
  # The parts may arrive as an array or as one space-separated string; read -a
  # normalizes both without glob expansion. Order is kept, duplicates collapse
  # (a doubled part would render twice while the budget charged it once), and
  # unknown parts drop here.
  IFS=' ' read -r -a praw <<<"${TAB_LABEL[*]}"
  for part in "${praw[@]}"; do
    case "$part" in
    icon | name | task) ar_in_list "$part" "${plist[@]}" || plist+=("$part") ;;
    esac
  done
  aliased=$(ar_alias "$prog")
  # The task part. A title arrives only for a pane herdr has detected an agent
  # in: deciding that is a herdr fact, so the engine does it
  # (ar_pane_agent_title) and this stays a string function. An empty title is
  # every other tab, and costs nothing here.
  if [ -n "$prog" ] && ar_in_list task "${plist[@]}" &&
    { [ -n "$title" ] || [ -n "$agent" ]; }; then
    # The name part, its alias, the glyph and the fallback key to the DETECTED
    # agent when the engine supplies one: a suspended agent's pane is still
    # that agent's pane, and the shell or quick command holding its foreground
    # must not lend the label its identity.
    if [ -n "$agent" ]; then
      prefix=$(ar_alias "$agent")
      prefix=${prefix:-$agent}
    else
      prefix=${aliased:-$prog}
    fi
    if [ -n "$title" ]; then
      # Everything that will share the label is priced out of MAX_TASK_LEN
      # before the task is condensed into the rest: the name part and its ":"
      # joint, and the glyph and its space when the icon part is listed. The
      # pricing happens inside ar_condense_title, in codepoints, so a
      # non-ASCII alias or a multibyte glyph is not overcharged by bash's byte
      # counting. A budget the parts exhaust, like a title that condenses to
      # nothing, leaves $ctask empty and the tab falls back below -- never a
      # dangling joint, never a mid-word cut.
      rsv=""
      if ar_in_list icon "${plist[@]}"; then
        # Provenance, not value comparison: ask the map alone first, so a real
        # glyph that happens to equal ICON_FALLBACK is never mistaken for the
        # fallback later. The fallback fills in only when ICON_MAP genuinely
        # has no say -- an explicit empty override ("nvim=") suppresses the
        # icon and must stay suppressed.
        ic=$(ICON_FALLBACK='' ar_icon "${agent:-$prog}")
        if [ -z "$ic" ] && ! ar_icon_mapped "${agent:-$prog}"; then
          ic=$ICON_FALLBACK
          icfb=1
        fi
        [ -z "$ic" ] || rsv="$ic "
      fi
      if ar_in_list name "${plist[@]}"; then
        rsv="$rsv$prefix:"
      fi
      ctask=$(ar_condense_title "$title" "$rsv")
    fi

  fi
  # The name part: the tab's text exactly as it has always been computed.
  if [ -z "$prog" ]; then
    name=$SHELL_NAME
    is_shell=1
  elif [ -n "$aliased" ]; then
    name=$aliased # user rename (PROGRAM_ALIASES) wins
  elif ar_in_list "$prog" "${SHELLS[@]}"; then
    name=$prog
    is_shell=1 # a shell shows its own name (zsh)
  elif [ "$prog" = "$SHELL_NAME" ]; then
    name=$prog
    is_shell=1 # the login shell, even outside SHELLS (nu, tcsh, ...)
  elif ar_in_list "$prog" "${IGNORED_PROGRAMS[@]}"; then
    name=$SHELL_NAME
    is_shell=1 # quick tools: keep showing the shell
  elif ar_in_list "$prog" "${NAME_ONLY_PROGRAMS[@]}"; then
    name="$(ar_subst "$prog")" # nvim, claude, ...: just the name
  elif [ "${SHOW_PROGRAM_ARGS:-1}" = "1" ] && [ -n "$cmdline" ]; then
    name="$(ar_subst "$cmdline")"
  else
    name="$(ar_subst "$prog")"
  fi

  # Key the whole label to the DETECTED agent when the engine supplied one and
  # a task part is in play: the name text, the alias and the fallback are the
  # agent's, not the foreground's, and the label stops counting as a shell.
  if [ -n "$agent" ] && ar_in_list task "${plist[@]}"; then
    name=$prefix
    is_shell=0
  fi

  # HIDE_SHELL: drop the shell label entirely and let herdr number the tab. An
  # explicit PROGRAM_ALIASES entry for a shell (e.g. "fish=sh") is a name the
  # user asked for by hand, so it survives; nothing else about a shell tab does
  # -- bare prompt, an explicit SHELLS entry, an IGNORED_PROGRAMS command, or
  # the login shell itself. A rendered task keeps the tab labeled, though: the
  # pane holds a detected agent, and its work is not a shell label.
  if [ "${HIDE_SHELL:-0}" = "1" ] && [ "$is_shell" = "1" ] && [ -z "$ctask" ]; then
    printf ''
    return 0
  fi

  # The icon part annotates the program the tab is named after -- or the
  # DETECTED agent, whatever holds the pane's foreground. Skip it whenever the
  # label is a shell name: precmd names an idle prompt via ar_format "" "",
  # which `[ -n "$prog" ]` denies a glyph, so one here would flip the label
  # between "zsh" and "<glyph> zsh" on every reconcile. is_shell covers the
  # bare prompt, the fixed SHELLS six, IGNORED_PROGRAMS, and the login shell
  # itself (SHELL_NAME may sit outside SHELLS -- nu, tcsh, elvish -- yet still
  # hit the map, or the fallback, at reconcile); comparing against SHELL_NAME
  # additionally keeps a cmdline- or alias-derived label of the same text plain.
  # (The task block above may have fetched the glyph already, for the budget.)
  if [ -z "$ic" ] && ar_in_list icon "${plist[@]}" && [ -n "$prog" ] && [ "$is_shell" = "0" ] &&
    [ "$name" != "$SHELL_NAME" ]; then
    # Provenance, not value comparison: ask the map alone first, so a real
    # glyph that happens to equal ICON_FALLBACK is never mistaken for the
    # fallback below. The fallback fills in only when ICON_MAP genuinely has
    # no say -- an explicit empty override ("nvim=") suppresses the icon and
    # must stay suppressed.
    ic=$(ICON_FALLBACK='' ar_icon "${agent:-$prog}")
    if [ -z "$ic" ] && ! ar_icon_mapped "${agent:-$prog}"; then
      ic=$ICON_FALLBACK
      icfb=1
    fi
  fi
  # A fallback glyph that would stand alone says nothing about the program
  # (rg -> "rg", not "?"; alongside text it still shows, "? rg"). Text renders
  # whenever a name or task part is listed -- the task yields its place to the
  # name below when it has nothing to show -- so a lone glyph is only possible
  # under a pure (icon) list, and that is the condition. $icfb is the
  # provenance recorded at lookup time, so a mapped glyph that happens to
  # equal ICON_FALLBACK is never suppressed, and a task that equals it is
  # never replaced.
  if [ "$icfb" = "1" ] && [ -n "$ic" ] &&
    ! ar_in_list name "${plist[@]}" && ! ar_in_list task "${plist[@]}"; then
    ic=""
  fi

  # Assemble the parts in the order the config wrote them; unknown parts add
  # nothing. The icon joins its neighbors with a space, text parts join with
  # ":".
  for part in "${plist[@]}"; do
    case "$part" in
    icon) ptext=$ic ;;
    name) ptext=$name ;;
    task)
      ptext=$ctask
      # A task with nothing to show yields its place to the name text (unless
      # a name part is listed on its own), so (icon task) reads glyph+task on
      # a tab with a task and glyph+name on every other tab, rather than
      # leaving plain tabs a bare glyph. On an agent pane $name is already the
      # detected agent, so a suspended agent with an unusable title reads
      # "<glyph> claude", never a glyph alone.
      if [ -z "$ptext" ] && ! ar_in_list name "${plist[@]}"; then
        ptext=$name
      fi
      ;;
    *) continue ;;
    esac
    [ -n "$ptext" ] || continue
    if [ -z "$out" ]; then
      out=$ptext
    elif [ "$part" = "icon" ] || [ "$prev" = "icon" ]; then
      out="$out $ptext"
    else
      out="$out:$ptext"
    fi
    prev=$part
  done
  # A label that composed to nothing (say, (task) on a tab with no task) must
  # not leave the tab blank: fall back to the name text.
  if [ -z "$out" ]; then
    out=$name
  fi
  name=$out
  # Truncate by Unicode codepoint, not byte. bash's ${#name} / ${name:0:$max}
  # count bytes under a C/POSIX locale (herdr may launch plugins with no LC_*),
  # which would slice a multibyte char in half and emit mojibake. jq (already a
  # hard dependency of this plugin) always reads input as UTF-8, so it slices on
  # codepoint boundaries regardless of the ambient locale; fall back to the byte
  # cut only if jq is somehow unavailable.
  # A label carrying a task was built to the MAX_TASK_LEN budget, so it is
  # measured against that budget here too; every other label keeps MAX_NAME_LEN.
  # ($ctask is only ever non-empty when the parts rendered it.)
  local max=${MAX_NAME_LEN:-20}
  [ -z "$ctask" ] || max=${MAX_TASK_LEN:-30}
  if [ "${#name}" -gt "$max" ]; then
    local truncated
    truncated=$(printf '%s' "$name" | jq -Rrs --argjson n "$max" '.[:$n]' 2>/dev/null || printf '')
    if [ -n "$truncated" ]; then
      name=$truncated
    else
      name=${name:0:$max}
    fi
  fi
  printf '%s' "$name"
}
