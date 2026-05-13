#!/usr/bin/env fish
# Vendored from jorgebucaran/autopair.fish (MIT): https://github.com/jorgebucaran/autopair.fish
# Source from devbox init.fish.
#
# If you previously used Fisher for autopair, remove ~/.config/fish/conf.d/autopair.fish
# and the _autopair_*.fish function files, and drop autopair from fish_plugins / _fisher_plugins
# so bindings are not registered twice.
#
# To remove Fisher entirely: clear fish_plugins, delete functions/fisher.fish and
# completions/fisher.fish, and clean _fisher_* lines from fish_variables if unused.

if not status is-interactive
    return
end

set --global autopair_left "(" "[" "{" '"' "'"
set --global autopair_right ")" "]" "}" '"' "'"
set --global autopair_pairs "()" "[]" "{}" '""' "''"

function _autopair_backspace
    set --local index (commandline --cursor)
    set --local buffer (commandline)

    test $index -ge 1 &&
        contains -- (string sub --start=$index --length=2 -- "$buffer") $autopair_pairs &&
        commandline --function delete-char
    commandline --function backward-delete-char
end

function _autopair_insert_left --argument-names left right
    set --local buffer (commandline)
    set --local before (commandline --cut-at-cursor)

    commandline --insert -- $left

    switch "$buffer"
        case "$before"{," "\*,$autopair_right\*}
            set --local index (commandline --cursor)
            commandline --insert -- $right
            commandline --cursor $index
    end
end

function _autopair_insert_right --argument-names key
    set --local buffer (commandline)
    set --local before (commandline --cut-at-cursor)

    switch "$buffer"
        case "$before$key"\*
            commandline --cursor (math (commandline --cursor) + 1)
        case \*
            commandline --insert -- $key
    end
end

function _autopair_insert_same --argument-names key
    set --local buffer (commandline)
    set --local index (commandline --cursor)
    set --local next (string sub --start=(math $index + 1) --length=1 -- "$buffer")

    if test (math (count (string match --all --regex -- "$key" "$buffer")) % 2) = 0
        test $key = $next && commandline --cursor (math $index + 1) && return

        commandline --insert -- $key

        if test $index -lt 1 ||
                contains -- (string sub --start=$index --length=1 -- "$buffer") "" " " $autopair_left &&
                contains -- $next "" " " $autopair_right
            commandline --insert -- $key
            commandline --cursor (math $index + 1)
        end
    else
        commandline --insert -- $key
    end
end

function _autopair_tab
    commandline --paging-mode && down-or-search && return

    string match --quiet --regex -- '\$[^\s]*"$' (commandline --current-token) &&
        commandline --function end-of-line --function backward-delete-char
    commandline --function complete
end

function _autopair_fish_key_bindings --on-variable fish_key_bindings
    set --query fish_key_bindings[1] || return

    test $fish_key_bindings = fish_default_key_bindings &&
        set --local mode default insert ||
        set --local mode insert default

    bind --mode $mode[-1] --erase \177 \b \t

    bind --mode $mode[1] \177 _autopair_backspace # macOS ⌫
    bind --mode $mode[1] \b _autopair_backspace
    bind --mode $mode[1] \t _autopair_tab

    printf "%s\n" $autopair_pairs | while read --local left right --delimiter ""
        bind --mode $mode[-1] --erase $left $right
        if test $left = $right
            bind --mode $mode[1] $left "_autopair_insert_same \\$left"
        else
            bind --mode $mode[1] $left "_autopair_insert_left \\$left \\$right"
            bind --mode $mode[1] $right "_autopair_insert_right \\$right"
        end
    end
end

_autopair_fish_key_bindings
