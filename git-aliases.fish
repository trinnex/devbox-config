#!/usr/bin/env fish
# Fish port of oh-my-zsh plugins/git (same coverage as git-aliases.bash).
# Uses `abbr` and `(helper)` expansions like lewisacidic/fish-git-abbr.
# Source from init.fish after fish-git-abbr if you want these definitions to win.

if not status is-interactive
    return
end

function _git_version_num
    git version 2>/dev/null | string replace -r 'git version ([0-9][0-9.]*).*$' '$1'
end

function _git_ver_ge -a required
    set -l cur (_git_version_num)
    test -n "$cur"; and test -n "$required"; or return 1
    awk -v a=$cur -v b=$required '
      function vnum(s,   t, n, i) {
        t = s
        gsub(/[^0-9.]/, "", t)
        n = split(t, p, ".")
        return p[1] * 1000000 + (n >= 2 ? p[2] : 0) * 1000 + (n >= 3 ? p[3] : 0)
      }
      BEGIN { exit !(vnum(a) >= vnum(b)) }
    '
end

function git_develop_branch
    command git rev-parse --git-dir &>/dev/null; or return 1
    for b in dev devel develop development
        if command git show-ref -q --verify refs/heads/$b
            echo $b
            return 0
        end
    end
    echo develop
    return 1
end

function git_main_branch
    command git rev-parse --git-dir &>/dev/null; or return 1
    for ref in refs/heads/main refs/heads/trunk refs/heads/mainline refs/heads/default refs/heads/stable refs/heads/master \
            refs/remotes/origin/main refs/remotes/origin/trunk refs/remotes/origin/mainline refs/remotes/origin/default refs/remotes/origin/stable refs/remotes/origin/master \
            refs/remotes/upstream/main refs/remotes/upstream/trunk refs/remotes/upstream/mainline refs/remotes/upstream/default refs/remotes/upstream/stable refs/remotes/upstream/master
        if command git show-ref -q --verify $ref
            set -l parts (string split -r -m1 / $ref)
            echo $parts[-1]
            return 0
        end
    end
    for remote in origin upstream
        set -l rhead (command git rev-parse --abbrev-ref "$remote/HEAD" 2>/dev/null)
        if string match -q "$remote/*" -- $rhead
            string replace "$remote/" '' -- $rhead
            return 0
        end
    end
    echo master
    return 1
end

function git_current_branch
    set -l ref (env GIT_OPTIONAL_LOCKS=0 command git symbolic-ref --quiet HEAD 2>/dev/null)
    set -l st $status
    if test $st -ne 0
        test $st -eq 128; and return 1
        set ref (env GIT_OPTIONAL_LOCKS=0 command git rev-parse --short HEAD 2>/dev/null); or return 1
        echo $ref
        return 0
    end
    string replace 'refs/heads/' '' -- $ref
end

function grename -a old new
    if test -z "$old"; or test -z "$new"
        echo "Usage: grename old_branch new_branch" >&2
        return 1
    end
    git branch -m $old $new
    if env GIT_OPTIONAL_LOCKS=0 git push origin :$old
        git push --set-upstream origin $new
    end
end

function gunwipall
    set -l c (git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)
    if test "$c" != (git rev-parse HEAD)
        git reset $c; or return 1
    end
end

function work_in_progress
    command git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- '--wip--'; and echo 'WIP!!'
end

function ggpnp
    if test (count $argv) -eq 0
        ggl; and ggp
    else
        ggl $argv; and ggp $argv
    end
end

function gbda
    set -l mb (git_main_branch 2>/dev/null)
    set -l db (git_develop_branch 2>/dev/null)
    set -l pat '^([+*]|\s*('"$mb"'|'"$db"')\s*$)'
    git branch --no-color --merged | command grep -vE $pat | command xargs git branch --delete 2>/dev/null
end

function gbds
    set -l default_branch (git_main_branch)
    set -l main_status $status
    if test $main_status -ne 0
        set default_branch (git_develop_branch)
    end
    for branch in (git for-each-ref refs/heads/ --format=%(refname:short))
        set -l merge_base (git merge-base $default_branch $branch)
        set -l tree (git rev-parse "$branch^{tree}")
        set -l commit (git commit-tree $tree -p $merge_base -m _)
        set -l cherry_out (git cherry $default_branch $commit)
        switch $cherry_out
            case '-*'
                git branch -D $branch
        end
    end
end

function gccd
    if not env GIT_OPTIONAL_LOCKS=0 git clone --recurse-submodules $argv
        return $status
    end
    set -l url ''
    set -l dest ''
    for arg in $argv
        switch $arg
            case '-*'
            case '*'
                if test -d $arg
                    set dest $arg
                else if string match -q '*:*' $arg
                    set url $arg
                else if string match -q '*@*' $arg
                    set url $arg
                else if string match -q '/*.git' $arg
                    set url $arg
                else if string match -q '*.git' $arg
                    set url $arg
                else if string match -q 'git@*' $arg
                    set url $arg
                else if string match -q 'ssh://*' $arg
                    set url $arg
                else if string match -q 'http://*' $arg
                    set url $arg
                else if string match -q 'https://*' $arg
                    set url $arg
                end
        end
    end
    if test -n "$dest"
        cd $dest; or return 1
        return 0
    end
    if test -z "$url"
        return 0
    end
    set dest (string replace -r '^.*/' '' $url)
    set dest (string replace -r '\.git$' '' $dest)
    cd $dest; or return 1
end

function gdv
    if set -q PAGER[1]
        git diff -w $argv | eval $PAGER
    else
        git diff -w $argv | command less
    end
end

function gdnolock
    git diff $argv ':(exclude)package-lock.json' ':(exclude)*.lock'
end

function _git_log_prettily
    test -z "$argv[1]"; and return 1
    git log --pretty=$argv[1]
end

function glp
    _git_log_prettily $argv
end

function ggu
    if test (count $argv) -eq 1
        git pull --rebase origin $argv[1]
    else
        git pull --rebase origin (git_current_branch)
    end
end

function ggl
    set -l argc (count $argv)
    if test $argc -ge 2
        git pull origin $argv
    else if test $argc -eq 1
        git pull origin $argv[1]
    else
        git pull origin (git_current_branch)
    end
end

function ggf
    if test (count $argv) -eq 1
        git push --force origin $argv[1]
    else
        git push --force origin (git_current_branch)
    end
end

function ggfl
    if test (count $argv) -eq 1
        git push --force-with-lease origin $argv[1]
    else
        git push --force-with-lease origin (git_current_branch)
    end
end

function ggp
    set -l argc (count $argv)
    if test $argc -ge 2
        git push origin $argv
    else if test $argc -eq 1
        git push origin $argv[1]
    else
        git push origin (git_current_branch)
    end
end

function gtl -a prefix
    if test -z "$prefix"
        echo 'gtl: need a tag name prefix' >&2
        return 1
    end
    git tag --sort=-v:refname -n --list "$prefix"*
end

function gk
    command gitk --all --branches &
    disown
end

function gke
    command gitk --all (git log --walk-reflogs --pretty=%h) &
    disown
end

function gbg
    LANG=C command git branch -vv | command grep ': gone]'
end

function gbgd
    LANG=C command git branch --no-color -vv | command grep ': gone]' | cut -c 3- | awk '{print $1}' | command xargs command git branch -d 2>/dev/null
end

function gbgD
    LANG=C command git branch --no-color -vv | command grep ': gone]' | cut -c 3- | awk '{print $1}' | command xargs command git branch -D 2>/dev/null
end

function gunwip
    git rev-list --max-count=1 --format=%s HEAD | grep -q -- '--wip--'
    and git reset HEAD~1
end

# Abbreviations (oh-my-zsh git plugin)
abbr grt 'cd (git rev-parse --show-toplevel 2>/dev/null; or echo .)'
abbr ggpur ggu
abbr g 'git'
abbr ga 'git add'
abbr gaa 'git add --all'
abbr gapa 'git add --patch'
abbr gau 'git add --update'
abbr gav 'git add --verbose'
abbr gwip "git add -A; and git rm (git ls-files --deleted) 2>/dev/null; and git commit --no-verify --no-gpg-sign --message '--wip-- [skip ci]'"
abbr gam 'git am'
abbr gama 'git am --abort'
abbr gamc 'git am --continue'
abbr gamscp 'git am --show-current-patch'
abbr gams 'git am --skip'
abbr gap 'git apply'
abbr gapt 'git apply --3way'
abbr gbs 'git bisect'
abbr gbsb 'git bisect bad'
abbr gbsg 'git bisect good'
abbr gbsn 'git bisect new'
abbr gbso 'git bisect old'
abbr gbsr 'git bisect reset'
abbr gbss 'git bisect start'
abbr gbl 'git blame -w'
abbr gb 'git branch'
abbr gba 'git branch --all'
abbr gbd 'git branch --delete'
abbr gbD 'git branch --delete --force'
abbr gbm 'git branch --move'
abbr gbnm 'git branch --no-merged'
abbr gbr 'git branch --remote'
abbr ggsup 'git branch --set-upstream-to=origin/(git_current_branch)'
abbr gco 'git checkout'
abbr gcor 'git checkout --recurse-submodules'
abbr gcb 'git checkout -b'
abbr gcB 'git checkout -B'
abbr gcd 'git checkout (git_develop_branch)'
abbr gcm 'git checkout (git_main_branch)'
abbr gcp 'git cherry-pick'
abbr gcpa 'git cherry-pick --abort'
abbr gcpc 'git cherry-pick --continue'
abbr gclean 'git clean --interactive -d'
abbr gcl 'git clone --recurse-submodules'
abbr gclf 'git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'

abbr gcam 'git commit --all --message'
abbr gcas 'git commit --all --signoff'
abbr gcasm 'git commit --all --signoff --message'
abbr gcs 'git commit --gpg-sign'
abbr gcss 'git commit --gpg-sign --signoff'
abbr gcssm 'git commit --gpg-sign --signoff --message'
abbr gcmsg 'git commit --message'
abbr gcsm 'git commit --signoff --message'
abbr gc 'git commit --verbose'
abbr gca 'git commit --verbose --all'
abbr gc! 'git commit --verbose --amend'
abbr gca! 'git commit --verbose --all --amend'
abbr gcan! 'git commit --verbose --all --no-edit --amend'
abbr gcans! 'git commit --verbose --all --signoff --no-edit --amend'
abbr gcann! 'git commit --verbose --all --date=now --no-edit --amend'
abbr gcn 'git commit --verbose --no-edit'
abbr gcn! 'git commit --verbose --no-edit --amend'
abbr gcf 'git config --list'
abbr gcfu 'git commit --fixup'
abbr gdct 'git describe --tags (git rev-list --tags --max-count=1)'
abbr gd 'git diff'
abbr gdca 'git diff --cached'
abbr gdcw 'git diff --cached --word-diff'
abbr gds 'git diff --staged'
abbr gdw 'git diff --word-diff'
abbr gdup 'git diff @{upstream}'
abbr gdt 'git diff-tree --no-commit-id --name-only -r'
abbr gf 'git fetch'

if _git_ver_ge 2.8
    abbr gfa 'git fetch --all --tags --prune --jobs=10'
else
    abbr gfa 'git fetch --all --tags --prune'
end

abbr gfo 'git fetch origin'
abbr gg 'git gui citool'
abbr gga 'git gui citool --amend'
abbr ghh 'git help'
abbr glgg 'git log --graph'
abbr glgga 'git log --graph --decorate --all'
abbr glgm 'git log --graph --max-count=10'
abbr glods 'git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
abbr glod 'git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
abbr glola 'git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
abbr glols 'git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
abbr glol 'git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
abbr glo 'git log --oneline --decorate'
abbr glog 'git log --oneline --decorate --graph'
abbr gloga 'git log --oneline --decorate --graph --all'
abbr glg 'git log --stat'
abbr glgp 'git log --stat --patch'
abbr gignored 'git ls-files -v | grep "^[[:lower:]]"'
abbr gfg 'git ls-files | grep'
abbr gm 'git merge'
abbr gma 'git merge --abort'
abbr gmc 'git merge --continue'
abbr gms 'git merge --squash'
abbr gmff 'git merge --ff-only'
abbr gmom 'git merge origin/(git_main_branch)'
abbr gmum 'git merge upstream/(git_main_branch)'
abbr gmtl 'git mergetool --no-prompt'
abbr gmtlvim 'git mergetool --no-prompt --tool=vimdiff'

abbr gl 'git pull'
abbr gpr 'git pull --rebase'
abbr gprv 'git pull --rebase -v'
abbr gpra 'git pull --rebase --autostash'
abbr gprav 'git pull --rebase --autostash -v'
abbr gprom 'git pull --rebase origin (git_main_branch)'
abbr gpromi 'git pull --rebase=interactive origin (git_main_branch)'
abbr gprum 'git pull --rebase upstream (git_main_branch)'
abbr gprumi 'git pull --rebase=interactive upstream (git_main_branch)'
abbr ggpull 'git pull origin (git_current_branch)'
abbr gluc 'git pull upstream (git_current_branch)'
abbr glum 'git pull upstream (git_main_branch)'
abbr gp 'git push'
abbr gpd 'git push --dry-run'
abbr gpf! 'git push --force'

if _git_ver_ge 2.30
    abbr gpf 'git push --force-with-lease --force-if-includes'
    abbr gpsupf 'git push --set-upstream origin (git_current_branch) --force-with-lease --force-if-includes'
else
    abbr gpf 'git push --force-with-lease'
    abbr gpsupf 'git push --set-upstream origin (git_current_branch) --force-with-lease'
end

abbr gpsup 'git push --set-upstream origin (git_current_branch)'
abbr gpv 'git push --verbose'
abbr gpoat 'git push origin --all && git push origin --tags'
abbr gpod 'git push origin --delete'
abbr ggpush 'git push origin (git_current_branch)'
abbr gpu 'git push upstream'
abbr grb 'git rebase'
abbr grba 'git rebase --abort'
abbr grbc 'git rebase --continue'
abbr grbi 'git rebase --interactive'
abbr grbo 'git rebase --onto'
abbr grbs 'git rebase --skip'
abbr grbd 'git rebase (git_develop_branch)'
abbr grbm 'git rebase (git_main_branch)'
abbr grbom 'git rebase origin/(git_main_branch)'
abbr grbum 'git rebase upstream/(git_main_branch)'
abbr grf 'git reflog'
abbr gr 'git remote'
abbr grv 'git remote --verbose'
abbr gra 'git remote add'
abbr grau 'git remote add upstream'
abbr grrm 'git remote remove'
abbr grmv 'git remote rename'
abbr grset 'git remote set-url'
abbr grup 'git remote update'
abbr grh 'git reset'
abbr gru 'git reset --'
abbr grhh 'git reset --hard'
abbr grhk 'git reset --keep'
abbr grhs 'git reset --soft'
abbr gpristine 'git reset --hard && git clean --force -dfx'
abbr gwipe 'git reset --hard && git clean --force -df'
abbr groh 'git reset origin/(git_current_branch) --hard'
abbr grs 'git restore'
abbr grss 'git restore --source'
abbr grst 'git restore --staged'
abbr grev 'git revert'
abbr greva 'git revert --abort'
abbr grevc 'git revert --continue'
abbr grm 'git rm'
abbr grmc 'git rm --cached'
abbr gcount 'git shortlog --summary --numbered'
abbr gsh 'git show'
abbr gsps 'git show --pretty=short --show-signature'

if _git_ver_ge 2.13
    abbr gsta 'git stash push'
else
    abbr gsta 'git stash save'
end

abbr gstall 'git stash --all'
abbr gstaa 'git stash apply'
abbr gstc 'git stash clear'
abbr gstd 'git stash drop'
abbr gstl 'git stash list'
abbr gstp 'git stash pop'
abbr gsts 'git stash show --patch'
abbr gst 'git status'
abbr gss 'git status --short'
abbr gsb 'git status --short --branch'
abbr gsi 'git submodule init'
abbr gsu 'git submodule update'
abbr gsd 'git svn dcommit'
abbr git-svn-dcommit-push 'git svn dcommit && git push github (git_main_branch):svntrunk'
abbr gsr 'git svn rebase'
abbr gsw 'git switch'
abbr gswc 'git switch --create'
abbr gswd 'git switch (git_develop_branch)'
abbr gswm 'git switch (git_main_branch)'
abbr gta 'git tag --annotate'
abbr gts 'git tag --sign'
abbr gtv 'git tag | sort -V'
abbr gignore 'git update-index --assume-unchanged'
abbr gunignore 'git update-index --no-assume-unchanged'
abbr gwch 'git log --patch --abbrev-commit --pretty=medium --raw'
abbr gwt 'git worktree'
abbr gwta 'git worktree add'
abbr gwtls 'git worktree list'
abbr gwtmv 'git worktree move'
abbr gwtrm 'git worktree remove'

if _git_ver_ge 2.13
    abbr gstu 'git stash push --include-untracked'
else
    abbr gstu 'git stash save --include-untracked'
end
