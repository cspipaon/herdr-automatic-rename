#!/usr/bin/env bash
# Integration test: drive the real engine (automatic-rename.sh) against a fake herdr
# and assert the exact rename commands it issues. This exercises the full
# reconcile -- workspace grouping/numbering, tab naming + numbering, the
# placeholder-defer rule, agent numbering, and the --clear strip -- with no live
# herdr and no live shell.

set -o pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"

ENGINE="$here/../automatic-rename.sh"
MOCK="$here/mocks/herdr"
chmod +x "$MOCK" 2>/dev/null || true

# A fresh sandbox per scenario: isolated fixtures, rename log, state, and config.
setup() {
  SB=$(mktemp -d "${TMPDIR:-/tmp}/hal-test.XXXXXX")
  export HERDR_MOCK_DIR="$SB/fixtures"; mkdir -p "$HERDR_MOCK_DIR"
  export HERDR_MOCK_LOG="$SB/renames.log"; : >"$HERDR_MOCK_LOG"
  export HERDR_BIN_PATH="$MOCK"
  export XDG_STATE_HOME="$SB/state"
  export HERDR_AUTOMATIC_RENAME_CONFIG="$SB/none.sh"   # absent -> env toggles win
  export HERDR_CONFIG_FILE="$SB/herdr.toml"
  printf 'agent_panel_sort = "spaces"\n' >"$HERDR_CONFIG_FILE"
  export HERDR_SOCKET_PATH="$SB/herdr.sock"   # keeps herdr state reads (session.json) in the sandbox
  export SHELL_NAME=zsh
  unset HERDR_MOCK_VERSION HERDR_MOCK_NO_VERSION   # per-scenario opt-in; mock default is current herdr
  unset HIDE_SHELL                                 # per-scenario opt-in; default is off
  unset AGENT_TAB_NAMES                            # per-scenario opt-in; default is "name"
  unset AUTO_INDEX_WORKSPACES AUTO_INDEX_TABS AUTO_INDEX_AGENTS   # per-kind opt-in; inherit AUTO_INDEX
}
fixture() { cat >"$HERDR_MOCK_DIR/$1"; }   # fixture <name>  (JSON on stdin)
run_event() { /usr/bin/env bash "$ENGINE" "$1"; }
log() { cat "$HERDR_MOCK_LOG"; }
teardown() { rm -rf "$SB" 2>/dev/null || true; }

# ======================================================================
# Scenario 1: both features on. Grouped agent sort.
#   - two singleton workspaces -> [1]/[2]
#   - tab t1 at a zsh prompt, t2 running nvim -> named + numbered in one rename
#   - a background multi-pane tab (no resolvable pane) with a placeholder label
#     -> DEFERRED (no throwaway "[N] 3" flash)
#   - one agent -> [1], on the last herdr that accepts a bracketed agent name
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
export HERDR_MOCK_VERSION=0.7.4   # < 0.7.5: agent numbering is still possible
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w1","label":"api"},
  {"workspace_id":"w2","label":"web"}
]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false}
]}}
JSON
fixture tabs_w2.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w2:t1","label":"3","pane_count":2,"focused":false}
]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false},
  {"pane_id":"p3","tab_id":"w2:t1","focused":false},
  {"pane_id":"p4","tab_id":"w2:t1","focused":false}
]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":200,
  "foreground_processes":[{"pid":200,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[
  {"terminal_id":"term_a","pane_id":"w1:pA","name":"claude","agent_session":{"agent":"claude"}}
]}}
JSON
run_event tab.focused
out=$(log)
check_contains "ws1 numbered"          "$out" "workspace rename w1 [1] api"
check_contains "ws2 numbered"          "$out" "workspace rename w2 [2] web"
check_contains "tab1 named+numbered"   "$out" "tab rename w1:t1 [1] zsh"
check_contains "tab2 named+numbered"   "$out" "tab rename w1:t2 [2] nvim"
check_absent   "placeholder deferred"  "$out" "tab rename w2:t1"
check_contains "agent numbered by pane id" "$out" "agent rename w1:pA [1] claude"
check_absent   "agent never targeted by terminal id" "$out" "agent rename term_a"
teardown

# ======================================================================
# Scenario 2: NAME_TABS on, AUTO_INDEX off.
#   Tabs are named with NO prefix; workspaces and agents are left untouched.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=0
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"claude","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
out=$(log)
check_contains "tab named without prefix" "$out" "tab rename w1:t1 zsh"
check_absent   "no workspace numbering"   "$out" "workspace rename"
check_absent   "no agent numbering"       "$out" "agent rename"
teardown

# ======================================================================
# Scenario 3: --clear strips every prefix and reverts the agent to detection.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"[1] api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] zsh","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"[1] claude","agent_session":{"agent":"claude"}}]}}
JSON
run_event --clear
out=$(log)
check_contains "ws prefix stripped"    "$out" "workspace rename w1 api"
check_contains "tab prefix stripped"   "$out" "tab rename w1:t1 zsh"
check_contains "agent reverted"        "$out" "agent rename w1:pA --clear"
teardown

# ======================================================================
# Scenario 4: a process-info blip must NOT clobber a named tab.
#   We already own w1:t1 as "nvim" (seeded state). process-info fails (no
#   fixture -> empty foreground process), so the base must stay "nvim" and the
#   already-correct "[1] nvim" label must not be rewritten to "[1] zsh".
#   Guards engine finding #1 (ar_tab_name must return "" on failure, not $SHELL).
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t1":{"auto":"nvim","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"code"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] nvim","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
# NOTE: no procinfo_p1.json -> the mock serves "{}" -> no resolvable foreground process.
run_event tab.focused
out=$(log)
check_absent "no clobber to shell name on blip" "$out" "zsh"
check_absent "owned tab left untouched on blip" "$out" "tab rename w1:t1"
teardown

# ======================================================================
# Scenario 5: the api-snapshot path. Same inputs and expected renames as
#   Scenario 1, but the engine's whole picture comes from ONE snapshot.json
#   (no workspaces.json / tabs_*.json / panes.json / agents.json). If the
#   snapshot path were skipped, the fallback would hit the mock's empty list
#   defaults and rename NOTHING -- so these renames appearing proves the
#   snapshot slices are parsed, ordered, and grouped-by-workspace correctly.
#   procinfo fixtures are still required: naming samples the foreground process
#   per tab, which the snapshot does not carry.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
export HERDR_MOCK_VERSION=0.7.4   # < 0.7.5: agent numbering is still possible
fixture snapshot.json <<'JSON'
{"result":{"snapshot":{
  "workspaces":[
    {"workspace_id":"w1","label":"api"},
    {"workspace_id":"w2","label":"web"}
  ],
  "tabs":[
    {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true,"workspace_id":"w1"},
    {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false,"workspace_id":"w1"},
    {"tab_id":"w2:t1","label":"3","pane_count":2,"focused":false,"workspace_id":"w2"}
  ],
  "panes":[
    {"pane_id":"p1","tab_id":"w1:t1","focused":true},
    {"pane_id":"p2","tab_id":"w1:t2","focused":false},
    {"pane_id":"p3","tab_id":"w2:t1","focused":false},
    {"pane_id":"p4","tab_id":"w2:t1","focused":false}
  ],
  "agents":[
    {"terminal_id":"term_a","pane_id":"w1:pA","name":"claude","agent_session":{"agent":"claude"}}
  ]
}}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":200,
  "foreground_processes":[{"pid":200,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "snapshot: ws1 numbered"        "$out" "workspace rename w1 [1] api"
check_contains "snapshot: ws2 numbered"        "$out" "workspace rename w2 [2] web"
check_contains "snapshot: tab1 named+numbered" "$out" "tab rename w1:t1 [1] zsh"
check_contains "snapshot: tab2 named+numbered" "$out" "tab rename w1:t2 [2] nvim"
check_absent   "snapshot: placeholder deferred" "$out" "tab rename w2:t1"
check_contains "snapshot: agent numbered"      "$out" "agent rename w1:pA [1] claude"
teardown

# ======================================================================
# Scenario 6: process-info without an argv0 field (issue #6).
#   herdr's Linux builds report no argv0 at all -- only argv/cmdline/name. On
#   NixOS `name` is the on-disk executable, which for a wrapped program is the
#   internal `.<prog>-wrapped` binary, while argv[0] still carries what the user
#   typed. Naming must follow argv[0], not the wrapper.
#   p1: the reporter's payload -- `nh os switch` must read "nh", not ".nh-wrapped".
#   p2: a login shell, where argv[0] keeps the leading "-" that argv0 lacks.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=0
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false}
]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false}
]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":75757,
  "foreground_processes":[
    {"pid":75757,"argv":["nh","os","switch"],"cmdline":"nh os switch","name":".nh-wrapped"},
    {"pid":75998,"argv":["nix","build","x"],"cmdline":"nix build x","name":"nix"}]}}}
JSON
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv":["-zsh"],"cmdline":"-zsh","name":".zsh-wrapped"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "argv[0] names the tab, not the wrapper" "$out" "tab rename w1:t1 nh"
check_absent   "wrapper name never shown"               "$out" "wrapped"
check_contains "login shell argv[0] strips the dash"    "$out" "tab rename w1:t2 zsh"
teardown

# ======================================================================
# Scenario 7: herdr >= 0.7.5 restricts agent names to ^[a-z][a-z0-9_-]{0,31}$,
#   so "[N] claude" can never be set. Numbering must be skipped even though the
#   panel is grouped-sorted, and an "[1] claude" left behind by an older
#   herdr + older plugin must be reverted to detection (the upgrade path: that
#   name is otherwise stuck, including through the uninstall --clear).
#   Workspaces and tabs are unaffected -- their labels stay free-form.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
export HERDR_MOCK_VERSION=0.8.0
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[
  {"terminal_id":"term_a","pane_id":"w1:pA","name":"[1] claude","agent_session":{"agent":"claude"}},
  {"terminal_id":"term_b","pane_id":"w1:pB","name":"my-session","agent_session":{"agent":"codex"}}
]}}
JSON
run_event tab.focused
out=$(log)
check_absent   "no bracketed agent name attempted" "$out" "[1] claude"
check_contains "legacy agent prefix reverted"      "$out" "agent rename w1:pA --clear"
check_absent   "user-named agent left alone"       "$out" "agent rename w1:pB"
check_contains "workspaces still numbered"         "$out" "workspace rename w1 [1] api"
check_contains "tabs still named and numbered"     "$out" "tab rename w1:t1 [1] zsh"
teardown

# ======================================================================
# Scenario 8: an unreadable herdr version must NOT unlock agent numbering.
#   The mock serves no version at all, so ar_herdr_version fails and the engine
#   has to assume the restrictive herdr rather than issuing a rename that a real
#   herdr would reject.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=1
export HERDR_MOCK_NO_VERSION=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"claude","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
out=$(log)
check_absent   "unknown version does not number agents" "$out" "agent rename w1:pA [1]"
check_contains "workspaces unaffected"                  "$out" "workspace rename w1 [1] api"
teardown

# ======================================================================
# Scenario 9: HIDE_SHELL=1 with AUTO_INDEX=0 (issue #5).
#   A shell tab is renamed to the EMPTY label so herdr renders its own number;
#   an nvim tab is named as usual. The state file must record the empty name as
#   ours, or the next pass would read herdr's number back as a hand rename.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=0 HIDE_SHELL=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"fish","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false}
]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false}
]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-fish","cmdline":"-fish"}]}}}
JSON
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":200,
  "foreground_processes":[{"pid":200,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
# t1 is ours, named "fish" by an earlier pass, so the knob has a label to undo.
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t1":{"auto":"fish","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
run_event tab.focused
out=$(log)
check "shell tab renamed to nothing" "tab rename w1:t1 " "$(printf '%s\n' "$out" | grep 'w1:t1')"
check_contains "nvim tab still named"  "$out" "tab rename w1:t2 nvim"
check "empty name recorded as ours" "true" \
  "$(jq -r '."w1:t1" | (.auto == "") and .enabled' "$XDG_STATE_HOME/herdr-automatic-rename/state.json")"
teardown

# ======================================================================
# Scenario 10: HIDE_SHELL=1 with AUTO_INDEX=1.
#   The jump number is the one thing numbering exists for, so a hidden shell tab
#   keeps "[N]" alone. The next pass must read that back as OUR label (empty base,
#   still owned) and leave it alone rather than opting the tab out.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 HIDE_SHELL=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] zsh","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t1":{"auto":"zsh","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
run_event tab.focused
check_contains "numbered shell tab keeps the number only" "$(log)" "tab rename w1:t1 [1]"
# Second pass over the settled "[1]" label: no further rename, still ours.
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1]","pane_count":1,"focused":true}]}}
JSON
: >"$HERDR_MOCK_LOG"
run_event tab.focused
check "settled [N] label is stable" "" "$(printf '%s\n' "$(log)" | grep 'tab rename')"
check "still owned after settling" "true" \
  "$(jq -r '."w1:t1".enabled' "$XDG_STATE_HOME/herdr-automatic-rename/state.json")"
teardown

# ======================================================================
# Scenario 11: HIDE_SHELL and the two ways an empty label must NOT be touched.
#   a) --clear strips a leftover "[1]" off a hidden tab (the uninstall path).
#   b) A process-info blip on a hidden tab leaves the label alone: the old
#      "empty base -> skip" guard now runs on HIDE_SHELL, so nothing may make it
#      guess "[1]" for a tab whose program it could not read.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 HIDE_SHELL=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"[1] api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1]","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
run_event --clear
check "clear strips a number-only label" "tab rename w1:t1 " "$(printf '%s\n' "$(log)" | grep 'w1:t1')"
teardown

setup
export NAME_TABS=1 AUTO_INDEX=1 HIDE_SHELL=1
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t1":{"auto":"nvim","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"code"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] nvim","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
# NOTE: no procinfo_p1.json -> process-info resolves nothing.
run_event tab.focused
check_absent "blip does not hide a named tab" "$(log)" "tab rename w1:t1"
teardown

# ======================================================================
# Scenario 12: a hidden tab whose program can't be sampled must still be
#   renumbered. A background multi-pane tab exposes no active pane at all, so its
#   name is never computable -- but its jump number still has to follow the tab
#   order, which is exactly what the "[i]"-only label has to keep working for.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 HIDE_SHELL=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"[1] api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t9","label":"[2]","pane_count":2,"focused":false}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t9","focused":false},
  {"pane_id":"p2","tab_id":"w1:t9","focused":false}
]}}
JSON
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t9":{"auto":"","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
run_event tab.moved
check_contains "hidden tab follows its number" "$(log)" "tab rename w1:t9 [1]"
teardown

# ======================================================================
# Scenario 13: with HIDE_SHELL off, a name the config erased is not a name.
#   MAX_NAME_LEN=0 stands in for any rule that computes a name and then leaves
#   nothing of it (a catch-all SUBSTITUTE_SETS does the same). Only HIDE_SHELL
#   licenses blanking a tab, so this must leave the label alone.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 MAX_NAME_LEN=0
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"[1] api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] nvim","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
mkdir -p "$XDG_STATE_HOME/herdr-automatic-rename"
printf '{"w1:t1":{"auto":"nvim","enabled":true}}\n' >"$XDG_STATE_HOME/herdr-automatic-rename/state.json"
run_event tab.focused
check_absent "erased name does not blank a tab" "$(log)" "tab rename w1:t1"
unset MAX_NAME_LEN
teardown

# ======================================================================
# Scenario 14: issue #8 -- numbered tabs, plain workspaces, from one knob.
#   AUTO_INDEX_WORKSPACES=0 alone. Tabs and agents keep numbering (they inherit
#   AUTO_INDEX), and the workspace prefix already on the row is STRIPPED rather
#   than left for the next `clear`: the pass runs whether the scope is on or off.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 AUTO_INDEX_WORKSPACES=0
export HERDR_MOCK_VERSION=0.7.4   # < 0.7.5: agent numbering is still possible
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w1","label":"[1] api"},
  {"workspace_id":"w2","label":"web"}
]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true}]}}
JSON
fixture tabs_w2.json <<'JSON'
{"result":{"tabs":[]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"claude","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
out=$(log)
check_contains "stale ws prefix stripped"  "$out" "workspace rename w1 api"
check_absent   "ws never renumbered"       "$out" "workspace rename w1 [1]"
check_absent   "unprefixed ws left alone"  "$out" "workspace rename w2"
check_contains "tabs still numbered"       "$out" "tab rename w1:t1 [1] nvim"
check_contains "agents still numbered"     "$out" "agent rename w1:pA [1] claude"
teardown

# ======================================================================
# Scenario 15: the mirror image -- AUTO_INDEX_TABS=0 with the rest on. The tab
#   keeps its NAME but loses its number, while the workspace keeps both.
#   Guards against a scope leaking into its neighbours through ar_index_on.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 AUTO_INDEX_TABS=0
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[1] nvim","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[{"pane_id":"p1","tab_id":"w1:t1","focused":true}]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "tab keeps name, loses number" "$out" "tab rename w1:t1 nvim"
check_contains "workspace still numbered"     "$out" "workspace rename w1 [1] api"
teardown

# ======================================================================
# Scenario 16: AUTO_INDEX_AGENTS=0 strips an agent prefix on a herdr that would
#   otherwise accept one, and does it without consulting the version or the
#   panel sort -- the toggle is tested before both probes. Workspaces and tabs,
#   inheriting AUTO_INDEX=1, are unaffected.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 AUTO_INDEX_AGENTS=0
export HERDR_MOCK_VERSION=0.7.4   # < 0.7.5: numbering would be allowed
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[]}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"[1] claude","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
out=$(log)
check_contains "agent prefix stripped"    "$out" "agent rename w1:pA --clear"
check_contains "workspace still numbered" "$out" "workspace rename w1 [1] api"
teardown

# ======================================================================
# Scenario 17: a config that predates these settings must not be touched.
#   Only AUTO_INDEX=0 is set, so every kind INHERITS off and nothing was named.
#   The passes are skipped exactly as they were before per-kind settings existed,
#   which is what keeps a hand-typed "[1] incident" that has sat there for
#   months from being stripped by an upgrade the user did not ask for.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=0
export HERDR_MOCK_VERSION=0.7.4   # < 0.7.5: agents would be eligible
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"[1] incident"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"[2] notes","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[]}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"[3] triage","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
check "legacy AUTO_INDEX=0 renames nothing" "" "$(log)"
teardown

# ======================================================================
# Scenario 18: name the kind and the strip arms, including the cost of it.
#   Scenario 17's config plus an explicit AUTO_INDEX_WORKSPACES=0, so the pair
#   isolates naming as the thing that arms it. The stale prefix goes, and so
#   does a hand-typed one -- nothing tells them apart, which is what the docs
#   warn about. "[wip] ..." is spared by the all-digits rule, and agents, still
#   only inheriting, stay untouched.
# ======================================================================
setup
export NAME_TABS=0 AUTO_INDEX=0 AUTO_INDEX_WORKSPACES=0
export HERDR_MOCK_VERSION=0.7.4
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[
  {"workspace_id":"w1","label":"[1] incident"},
  {"workspace_id":"w2","label":"[wip] deploy"}
]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[]}}
JSON
fixture tabs_w2.json <<'JSON'
{"result":{"tabs":[]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[]}}
JSON
fixture agents.json <<'JSON'
{"result":{"agents":[{"terminal_id":"term_a","pane_id":"w1:pA","name":"[3] triage","agent_session":{"agent":"claude"}}]}}
JSON
run_event tab.focused
out=$(log)
check_contains "named kind strips its prefix"  "$out" "workspace rename w1 incident"
check_absent   "non-digit bracket survives"    "$out" "workspace rename w2"
check_absent   "unnamed kind still untouched"  "$out" "agent rename"
teardown

# ======================================================================
# Scenario 19: an agent behind a language runtime.
#
# An agent installed through npm or npx runs as its runtime (its bin shim is a
# JS file behind a node shebang), so a codex pane was named "node". herdr
# detects the agent regardless and publishes it on the pane object, and where
# the foreground program is a runtime that answer wins. No agents.json fixture:
# the name must come from the pane fields alone, with no `agent list` call.
#
# Both halves are required, and the scenario pins each: t2 is an ordinary node
# program with no agent in the pane and keeps its name, t3 is an agent that
# reports itself and is unaffected. t4 pins the gate itself: its pane carries
# only an agent_session (a resume ref -- herdr#803's half-wired state, where
# detection reports nothing and agent list excludes the pane), which must NOT
# name the tab.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false},
  {"tab_id":"w1:t3","label":"3","pane_count":1,"focused":false},
  {"tab_id":"w1:t4","label":"4","pane_count":1,"focused":false}
]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true,"agent":"codex","agent_status":"idle",
   "agent_session":{"source":"herdr:codex","agent":"codex","kind":"id","value":"019f"}},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false,"agent_status":"unknown"},
  {"pane_id":"p3","tab_id":"w1:t3","focused":false,"agent":"claude","agent_status":"idle",
   "agent_session":{"source":"herdr:claude","agent":"claude","kind":"id","value":"ce04"}},
  {"pane_id":"p4","tab_id":"w1:t4","focused":false,"agent_status":"unknown",
   "agent_session":{"source":"herdr:claude","agent":"claude","kind":"id","value":"dead"}}
]}}
JSON
# p1: codex through npx -- argv0 absent, argv[0] is the runtime, name is a thread.
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv":["node","/home/u/.npm/_npx/x/node_modules/.bin/codex"],
  "name":"MainThread","cmdline":"node /home/u/.npm/_npx/x/node_modules/.bin/codex"}]}}}
JSON
# p2: an ordinary node program, no agent in the pane.
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":200,
  "foreground_processes":[{"pid":200,"argv0":"node","cmdline":"node server.js"}]}}}
JSON
# p3: an agent that reports its own name.
fixture procinfo_p3.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":300,
  "foreground_processes":[{"pid":300,"argv0":"claude","cmdline":"claude"}]}}}
JSON
# p4: node again, but the pane holds only a session ref -- no detected agent.
fixture procinfo_p4.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":400,
  "foreground_processes":[{"pid":400,"argv0":"node","cmdline":"node worker.js"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "runtime + detected agent -> the agent" "$out" "tab rename w1:t1 [1] codex"
check_absent   "the runtime never names that tab"      "$out" "[1] node"
check_contains "an ordinary node program is untouched" "$out" "tab rename w1:t2 [2] node"
check_contains "a self-reporting agent is unchanged"   "$out" "tab rename w1:t3 [3] claude"
check_contains "a session ref alone never names"       "$out" "tab rename w1:t4 [4] node"
check_absent   "no rename from the stale session ref"  "$out" "[4] claude"
teardown

# ======================================================================
# Scenario 20: AGENT_TAB_NAMES=task -- an agent tab is named after the task
# the agent reports, and only an agent tab is.
#
# herdr's own detection decides which pane that is, read from the .agent field
# on the pane list the reconcile already fetched (so no extra herdr call) --
# the same gate ar_pane_agent_kind uses. The program name cannot decide it: p4
# here is codex, which runs as `node`, and a shell pane carries a working
# directory as its title that must never become a tab name. p6 pins the gate:
# agent_status and a session ref without .agent (herdr#803's half-wired state)
# must not admit a title either.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 AGENT_TAB_NAMES=task
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false},
  {"tab_id":"w1:t3","label":"3","pane_count":1,"focused":false},
  {"tab_id":"w1:t4","label":"4","pane_count":1,"focused":false},
  {"tab_id":"w1:t5","label":"5","pane_count":1,"focused":false},
  {"tab_id":"w1:t6","label":"6","pane_count":1,"focused":false},
  {"tab_id":"w1:t7","label":"7","pane_count":1,"focused":false},
  {"tab_id":"w1:t8","label":"8","pane_count":1,"focused":false},
  {"tab_id":"w1:t9","label":"9","pane_count":1,"focused":false},
  {"tab_id":"w1:t10","label":"10","pane_count":1,"focused":false},
  {"tab_id":"w1:t11","label":"11","pane_count":1,"focused":false}
]}}
JSON
# p1 an agent with a task title; p2 an agent herdr set no title for; p3 nvim,
# whose title is a path; p4 codex, running as `node`; p5 a shell, whose title is
# a working directory and no agent; p6 a pane whose fields disagree -- a status
# and a session ref but no detected agent.
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true,"agent":"claude","agent_status":"working",
   "terminal_title":"* Adjust screensaver timeout on the Ubuntu box",
   "terminal_title_stripped":"Adjust screensaver timeout on the Ubuntu box"},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false,"agent":"claude","agent_status":"idle"},
  {"pane_id":"p3","tab_id":"w1:t3","focused":false,"agent_status":"unknown",
   "terminal_title_stripped":"~/code/api/README.md"},
  {"pane_id":"p4","tab_id":"w1:t4","focused":false,"agent":"codex","agent_status":"blocked",
   "terminal_title_stripped":"Port the pricing model to the streaming backend"},
  {"pane_id":"p5","tab_id":"w1:t5","focused":false,"agent_status":"unknown",
   "terminal_title_stripped":"user@host:~/code/api"},
  {"pane_id":"p6","tab_id":"w1:t6","focused":false,"agent_status":"working",
   "agent_session":{"source":"herdr:claude","agent":"claude","kind":"id","value":"dead"},
   "terminal_title_stripped":"Summarize the quarterly revenue numbers"},
  {"pane_id":"p7","tab_id":"w1:t7","focused":false,"agent":"claude","agent_status":"idle",
   "terminal_title_stripped":"to the and of"},
  {"pane_id":"p8","tab_id":"w1:t8","focused":false,"agent":"claude","agent_status":"working",
   "cwd":"/home/u/vaults/notes","terminal_title_stripped":"user@host:~/vaults/notes"},
  {"pane_id":"p9","tab_id":"w1:t9","focused":false,"agent":"claude","agent_status":"working",
   "cwd":"HOMEDIR/code/api","terminal_title_stripped":"~/code/api"},
  {"pane_id":"p10","tab_id":"w1:t10","focused":false,"agent":"claude","agent_status":"working",
   "cwd":"HOMEDIR/code/api","terminal_title_stripped":"~/code/api/"},
  {"pane_id":"p11","tab_id":"w1:t11","focused":false,"agent":"claude","agent_status":"working",
   "terminal_title_stripped":"bob@corp: rotate keys"}
]}}
JSON
# Rewrite the HOMEDIR sentinel with the runner's real home so the
# "~"-abbreviation check has something true to abbreviate.
sed -i.bak "s|HOMEDIR|$HOME|" "$HERDR_MOCK_DIR/panes.json" && rm -f "$HERDR_MOCK_DIR/panes.json.bak"
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"claude","cmdline":"claude"}]}}}
JSON
fixture procinfo_p2.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":200,
  "foreground_processes":[{"pid":200,"argv0":"claude","cmdline":"claude"}]}}}
JSON
fixture procinfo_p3.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":300,
  "foreground_processes":[{"pid":300,"argv0":"nvim","cmdline":"nvim README.md"}]}}}
JSON
fixture procinfo_p4.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":400,
  "foreground_processes":[{"pid":400,"argv0":"node","cmdline":"node /usr/lib/codex"}]}}}
JSON
fixture procinfo_p5.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":500,
  "foreground_processes":[{"pid":500,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
fixture procinfo_p6.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":600,
  "foreground_processes":[{"pid":600,"argv0":"claude","cmdline":"claude"}]}}}
JSON
# p7: a suspended agent -- herdr detects claude, the foreground is its shell,
# and the title condenses to nothing.
fixture procinfo_p7.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":700,
  "foreground_processes":[{"pid":700,"argv0":"-zsh","cmdline":"-zsh"}]}}}
JSON
# p8: a headless agent subprocess (say, a CLI tool shelling out to `claude -p`).
# herdr detects the agent, but the pane title is still the shell prompt's
# "user@host:path" -- no task in it. p9 is the same story for a prompt that
# titles with the bare "~"-abbreviated path.
fixture procinfo_p8.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":800,
  "foreground_processes":[{"pid":800,"argv0":"flashtool","cmdline":"flashtool tag propose"}]}}}
JSON
fixture procinfo_p9.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":900,
  "foreground_processes":[{"pid":900,"argv0":"flashtool","cmdline":"flashtool tag propose"}]}}}
JSON
# p10: the same bare-path title with a trailing slash. p11: a real task that
# merely OPENS with an email-like token -- the prompt shape requires a path
# after the colon, so this one stays a task.
fixture procinfo_p10.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":1000,
  "foreground_processes":[{"pid":1000,"argv0":"flashtool","cmdline":"flashtool tag propose"}]}}}
JSON
fixture procinfo_p11.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":1100,
  "foreground_processes":[{"pid":1100,"argv0":"claude","cmdline":"claude"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "agent tab named after its task"  "$out" "tab rename w1:t1 [1] screensaver-timeout-ubuntu-box"
check_contains "titleless agent keeps its name"  "$out" "tab rename w1:t2 [2] claude"
check_contains "editor ignores its title"        "$out" "tab rename w1:t3 [3] nvim"
# The one the program name would miss: herdr detects codex, the process is node.
check_contains "agent running as node is named"  "$out" "tab rename w1:t4 [4] pricing-model-streaming"
# And the one a program-name fallback would wrongly claim: a shell's cwd title.
check_contains "shell keeps its shell name"      "$out" "tab rename w1:t5 [5] zsh"
check_absent   "no cwd condensed into a label"   "$out" "user@host"
# The disagreeing pane: status and session ref, no detected agent. Program name.
check_contains "status without .agent -> no title" "$out" "tab rename w1:t6 [6] claude"
check_absent   "no title through the half-wired state" "$out" "quarterly"
# The suspended agent: the fallback keys to the DETECTED agent, not to the
# shell holding its foreground.
check_contains "a suspended agent falls back to the agent" "$out" "tab rename w1:t7 [7] claude"
check_absent   "the foreground shell never owns an agent pane" "$out" "[7] zsh"
# The headless-subprocess panes: a shell-prompt or bare-path title carries no
# task, so the tab keys to the detected agent instead of condensing the prompt.
check_contains "a shell-prompt title is not a task"  "$out" "tab rename w1:t8 [8] claude"
check_contains "a bare-path title is not a task"     "$out" "tab rename w1:t9 [9] claude"
check_contains "a trailing slash changes nothing"    "$out" "tab rename w1:t10 claude"
check_contains "an email-opening task stays a task"  "$out" "tab rename w1:t11 bob@corp-rotate-keys"
teardown

# ======================================================================
# Scenario 21: the same agent pane in the default mode ("name") is named
# "claude", so the feature is opt-in end to end and not only inside ar_format.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[{"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true}]}}
JSON
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true,"agent":"claude",
   "agent_status":"working","terminal_title_stripped":"Adjust screensaver timeout on the Ubuntu box"}
]}}
JSON
fixture procinfo_p1.json <<'JSON'
{"result":{"process_info":{"foreground_process_group_id":100,
  "foreground_processes":[{"pid":100,"argv0":"claude","cmdline":"claude"}]}}}
JSON
run_event tab.focused
out=$(log)
check_contains "default mode -> agent name"   "$out" "tab rename w1:t1 [1] claude"
check_absent   "default mode -> no task name" "$out" "screensaver"
teardown

# ======================================================================
# Scenario 22: an agent that titles its pane with the working directory.
#
# codex does this ("herdr-automatic-rename"), which is the repo name the
# workspace label already carries, so it is treated as no title at all. The tab
# then falls back to the agent herdr DETECTED rather than the foreground
# program, because codex runs through a node wrapper: "codex", not "node".
#
# Matched on the shape of the title, not on the agent's name, so the next agent
# that titles a pane with its cwd needs no change here. No agents.json fixture:
# the fallback name must come off the pane object, with no `agent list` call.
# ======================================================================
setup
export NAME_TABS=1 AUTO_INDEX=1 AGENT_TAB_NAMES=task
fixture workspaces.json <<'JSON'
{"result":{"workspaces":[{"workspace_id":"w1","label":"api"}]}}
JSON
fixture tabs_w1.json <<'JSON'
{"result":{"tabs":[
  {"tab_id":"w1:t1","label":"1","pane_count":1,"focused":true},
  {"tab_id":"w1:t2","label":"2","pane_count":1,"focused":false},
  {"tab_id":"w1:t3","label":"3","pane_count":1,"focused":false}
]}}
JSON
# p1 titles itself with its cwd basename; p2 is the same agent with a real task;
# p3 matches its foreground_cwd instead, which counts the same.
fixture panes.json <<'JSON'
{"result":{"panes":[
  {"pane_id":"p1","tab_id":"w1:t1","focused":true,"agent":"codex","agent_status":"working",
   "cwd":"/home/u/code/myrepo","terminal_title_stripped":"myrepo"},
  {"pane_id":"p2","tab_id":"w1:t2","focused":false,"agent":"codex","agent_status":"idle",
   "cwd":"/home/u/code/myrepo","terminal_title_stripped":"Port the pricing model"},
  {"pane_id":"p3","tab_id":"w1:t3","focused":false,"agent":"codex","agent_status":"idle",
   "cwd":"/home/u","foreground_cwd":"/home/u/code/other","terminal_title_stripped":"other"}
]}}
JSON
for p in 1 2 3; do
  fixture "procinfo_p$p.json" <<JSON
{"result":{"process_info":{"foreground_process_group_id":$p,
  "foreground_processes":[{"pid":$p,"argv0":"node","cmdline":"node /usr/lib/codex"}]}}}
JSON
done
run_event tab.focused
out=$(log)
check_contains "cwd title -> detected agent, not the wrapper" "$out" "tab rename w1:t1 [1] codex"
check_absent   "wrapper process name never used"              "$out" "node"
check_contains "a real task from the same agent still wins"   "$out" "tab rename w1:t2 [2] pricing-model"
check_contains "foreground_cwd counts too"                    "$out" "tab rename w1:t3 [3] codex"
teardown


t_summary
