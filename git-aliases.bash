#!/usr/bin/env bash
# Bash port of oh-my-zsh plugins/git (see https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git).
# Source from init.bash.
case $- in *i*) ;; *) return ;; esac

# Aliases use '!' (e.g. gc!); avoid Bash history expansion on those names
set +o histexpand 2>/dev/null || true

_git_version_num() {
  git version 2>/dev/null | sed -n 's/^git version \([0-9][0-9.]*\).*/\1/p'
}

_git_ver_ge() {
  local cur req
  cur="$(_git_version_num)"
  req="$1"
  [[ -n "$cur" && -n "$req" ]] || return 1
  awk -v a="$cur" -v b="$req" '
    function vnum(s,   t, n, i) {
      t = s
      gsub(/[^0-9.]/, "", t)
      n = split(t, p, ".")
      return p[1] * 1000000 + (n >= 2 ? p[2] : 0) * 1000 + (n >= 3 ? p[3] : 0)
    }
    BEGIN { exit !(vnum(a) >= vnum(b)) }
  '
}

#
# Functions (match oh-my-zsh naming for $(git_main_branch) etc. in aliases)
#

git_develop_branch() {
  command git rev-parse --git-dir &>/dev/null || return 1
  local branch
  for branch in dev devel develop development; do
    if command git show-ref -q --verify "refs/heads/$branch"; then
      echo "$branch"
      return 0
    fi
  done
  echo develop
  return 1
}

git_main_branch() {
  command git rev-parse --git-dir &>/dev/null || return 1
  local ref remote rhead

  for ref in refs/heads/main refs/heads/trunk refs/heads/mainline refs/heads/default refs/heads/stable refs/heads/master \
    refs/remotes/origin/main refs/remotes/origin/trunk refs/remotes/origin/mainline refs/remotes/origin/default refs/remotes/origin/stable refs/remotes/origin/master \
    refs/remotes/upstream/main refs/remotes/upstream/trunk refs/remotes/upstream/mainline refs/remotes/upstream/default refs/remotes/upstream/stable refs/remotes/upstream/master; do
    if command git show-ref -q --verify "$ref"; then
      echo "${ref##*/}"
      return 0
    fi
  done

  for remote in origin upstream; do
    rhead="$(command git rev-parse --abbrev-ref "${remote}/HEAD" 2>/dev/null)"
    case "$rhead" in
      "${remote}"/*)
        echo "${rhead#"${remote}"/}"
        return 0
        ;;
    esac
  done

  echo master
  return 1
}

git_current_branch() {
  local ref ret
  ref="$(GIT_OPTIONAL_LOCKS=0 command git symbolic-ref --quiet HEAD 2>/dev/null)"
  ret=$?
  if [[ "$ret" != 0 ]]; then
    [[ "$ret" == 128 ]] && return 1
    ref="$(GIT_OPTIONAL_LOCKS=0 command git rev-parse --short HEAD 2>/dev/null)" || return 1
  fi
  echo "${ref#refs/heads/}"
}

grename() {
  if [[ -z "${1:-}" || -z "${2:-}" ]]; then
    echo "Usage: $0 old_branch new_branch"
    return 1
  fi
  git branch -m "$1" "$2"
  if GIT_OPTIONAL_LOCKS=0 git push origin ":${1}"; then
    git push --set-upstream origin "$2"
  fi
}

gunwipall() {
  local _commit
  _commit="$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)"
  if [[ "$_commit" != "$(git rev-parse HEAD)" ]]; then
    git reset "$_commit" || return 1
  fi
}

work_in_progress() {
  command git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- "--wip--" && echo "WIP!!"
}

ggpnp() {
  if [[ $# == 0 ]]; then
    ggl && ggp
  else
    ggl "$@" && ggp "$@"
  fi
}

gbda() {
  git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch)|$(git_develop_branch))\s*$)" | command xargs git branch --delete 2>/dev/null
}

gbds() {
  local default_branch merge_base tree commit cherry_out branch main_status
  default_branch="$(git_main_branch)"
  main_status=$?
  if [[ "$main_status" -ne 0 ]]; then
    default_branch="$(git_develop_branch)"
  fi

  git for-each-ref refs/heads/ "--format=%(refname:short)" | while read -r branch; do
    merge_base="$(git merge-base "$default_branch" "$branch")"
    tree="$(git rev-parse "${branch}^{tree}")"
    commit="$(git commit-tree "$tree" -p "$merge_base" -m _)"
    cherry_out="$(git cherry "$default_branch" "$commit")"
    case "$cherry_out" in
      -*) git branch -D "$branch" ;;
    esac
  done
}

gccd() {
  if ! GIT_OPTIONAL_LOCKS=0 git clone --recurse-submodules "$@"; then
    return $?
  fi
  local arg url dest
  url=""
  dest=""
  for arg in "$@"; do
    case "$arg" in
      -*) ;;
      *)
        if [[ -d "$arg" ]]; then
          dest="$arg"
        elif [[ "$arg" == *:* || "$arg" == *@* || "$arg" == /*.git || "$arg" == *.git || "$arg" == git@* || "$arg" == ssh://* || "$arg" == http://* || "$arg" == https://* ]]; then
          url="$arg"
        fi
        ;;
    esac
  done
  if [[ -n "$dest" ]]; then
    cd "$dest" || return 1
    return 0
  fi
  if [[ -z "$url" ]]; then
    return 0
  fi
  dest="${url##*/}"
  dest="${dest%.git}"
  cd "$dest" || return 1
}

gdv() {
  git diff -w "$@" | ${PAGER:-less}
}

gdnolock() {
  git diff "$@" ":(exclude)package-lock.json" ":(exclude)*.lock"
}

_git_log_prettily() {
  [[ -z "${1:-}" ]] && return 1
  git log --pretty="$1"
}

ggu() {
  local b
  if [[ $# != 1 ]]; then
    b="$(git_current_branch)"
  fi
  git pull --rebase origin "${b:-$1}"
}

ggl() {
  if [[ $# != 0 && $# != 1 ]]; then
    git pull origin "$@"
  else
    local b
    [[ $# == 0 ]] && b="$(git_current_branch)"
    git pull origin "${b:-$1}"
  fi
}

ggf() {
  local b
  if [[ $# != 1 ]]; then
    b="$(git_current_branch)"
  fi
  git push --force origin "${b:-$1}"
}

ggfl() {
  local b
  if [[ $# != 1 ]]; then
    b="$(git_current_branch)"
  fi
  git push --force-with-lease origin "${b:-$1}"
}

ggp() {
  if [[ $# != 0 && $# != 1 ]]; then
    git push origin "$@"
  else
    local b
    [[ $# == 0 ]] && b="$(git_current_branch)"
    git push origin "${b:-$1}"
  fi
}

gtl() {
  if [[ -z "${1:-}" ]]; then
    echo "gtl: need a tag name prefix" >&2
    return 1
  fi
  set -f
  git tag --sort=-v:refname -n --list "${1}*"
  set +f
}

gk() {
  command gitk --all --branches >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

gke() {
  command gitk --all "$(git log --walk-reflogs --pretty=%h)" >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

#
# Aliases (oh-my-zsh git plugin)
#

alias grt='cd "$(git rev-parse --show-toplevel || echo .)"'
alias ggpur='ggu'
alias g='git'
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'
alias gwip='git add -A; git rm $(git ls-files --deleted) 2> /dev/null; git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"'
alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias gamscp='git am --show-current-patch'
alias gams='git am --skip'
alias gap='git apply'
alias gapt='git apply --3way'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsn='git bisect new'
alias gbso='git bisect old'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gbl='git blame -w'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -d'
alias gbgD='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -D'
alias gbm='git branch --move'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'
alias ggsup='git branch --set-upstream-to=origin/$(git_current_branch)'
alias gbg='LANG=C git branch -vv | grep ": gone\]"'
alias gco='git checkout'
alias gcor='git checkout --recurse-submodules'
alias gcb='git checkout -b'
alias gcB='git checkout -B'
alias gcd='git checkout $(git_develop_branch)'
alias gcm='git checkout $(git_main_branch)'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gclean='git clean --interactive -d'
alias gcl='git clone --recurse-submodules'
alias gclf='git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'

alias gcam='git commit --all --message'
alias gcas='git commit --all --signoff'
alias gcasm='git commit --all --signoff --message'
alias gcs='git commit --gpg-sign'
alias gcss='git commit --gpg-sign --signoff'
alias gcssm='git commit --gpg-sign --signoff --message'
alias gcmsg='git commit --message'
alias gcsm='git commit --signoff --message'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias 'gca!='='git commit --verbose --all --amend'
alias 'gcan!='='git commit --verbose --all --no-edit --amend'
alias 'gcans!='='git commit --verbose --all --signoff --no-edit --amend'
alias 'gcann!='='git commit --verbose --all --date=now --no-edit --amend'
alias 'gc!='='git commit --verbose --amend'
alias gcn='git commit --verbose --no-edit'
alias 'gcn!='='git commit --verbose --no-edit --amend'
alias gcf='git config --list'
alias gcfu='git commit --fixup'
alias gdct='git describe --tags $(git rev-list --tags --max-count=1)'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'
alias gdup='git diff @{upstream}'
alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gf='git fetch'

if _git_ver_ge 2.8; then
  alias gfa='git fetch --all --tags --prune --jobs=10'
else
  alias gfa='git fetch --all --tags --prune'
fi

alias gfo='git fetch origin'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ghh='git help'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glp='_git_log_prettily'
alias glg='git log --stat'
alias glgp='git log --stat --patch'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias gfg='git ls-files | grep'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gms='git merge --squash'
alias gmff='git merge --ff-only'
alias gmom='git merge origin/$(git_main_branch)'
alias gmum='git merge upstream/$(git_main_branch)'
alias gmtl='git mergetool --no-prompt'
alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'

alias gl='git pull'
alias gpr='git pull --rebase'
alias gprv='git pull --rebase -v'
alias gpra='git pull --rebase --autostash'
alias gprav='git pull --rebase --autostash -v'
alias gprom='git pull --rebase origin $(git_main_branch)'
alias gpromi='git pull --rebase=interactive origin $(git_main_branch)'
alias gprum='git pull --rebase upstream $(git_main_branch)'
alias gprumi='git pull --rebase=interactive upstream $(git_main_branch)'
alias ggpull='git pull origin "$(git_current_branch)"'
alias gluc='git pull upstream $(git_current_branch)'
alias glum='git pull upstream $(git_main_branch)'
alias gp='git push'
alias gpd='git push --dry-run'
alias 'gpf!='='git push --force'

if _git_ver_ge 2.30; then
  alias gpf='git push --force-with-lease --force-if-includes'
  alias gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease --force-if-includes'
else
  alias gpf='git push --force-with-lease'
  alias gpsupf='git push --set-upstream origin $(git_current_branch) --force-with-lease'
fi

alias gpsup='git push --set-upstream origin $(git_current_branch)'
alias gpv='git push --verbose'
alias gpoat='git push origin --all && git push origin --tags'
alias gpod='git push origin --delete'
alias ggpush='git push origin "$(git_current_branch)"'
alias gpu='git push upstream'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grbo='git rebase --onto'
alias grbs='git rebase --skip'
alias grbd='git rebase $(git_develop_branch)'
alias grbm='git rebase $(git_main_branch)'
alias grbom='git rebase origin/$(git_main_branch)'
alias grbum='git rebase upstream/$(git_main_branch)'
alias grf='git reflog'
alias gr='git remote'
alias grv='git remote --verbose'
alias gra='git remote add'
alias grau='git remote add upstream'
alias grrm='git remote remove'
alias grmv='git remote rename'
alias grset='git remote set-url'
alias grup='git remote update'
alias grh='git reset'
alias gru='git reset --'
alias grhh='git reset --hard'
alias grhk='git reset --keep'
alias grhs='git reset --soft'
alias gpristine='git reset --hard && git clean --force -dfx'
alias gwipe='git reset --hard && git clean --force -df'
alias groh='git reset origin/$(git_current_branch) --hard'
alias grs='git restore'
alias grss='git restore --source'
alias grst='git restore --staged'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
alias grev='git revert'
alias greva='git revert --abort'
alias grevc='git revert --continue'
alias grm='git rm'
alias grmc='git rm --cached'
alias gcount='git shortlog --summary --numbered'
alias gsh='git show'
alias gsps='git show --pretty=short --show-signature'

if _git_ver_ge 2.13; then
  alias gsta='git stash push'
else
  alias gsta='git stash save'
fi

alias gstall='git stash --all'
alias gstaa='git stash apply'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'
alias gsts='git stash show --patch'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gsi='git submodule init'
alias gsu='git submodule update'
alias gsd='git svn dcommit'
alias git-svn-dcommit-push='git svn dcommit && git push github $(git_main_branch):svntrunk'
alias gsr='git svn rebase'
alias gsw='git switch'
alias gswc='git switch --create'
alias gswd='git switch $(git_develop_branch)'
alias gswm='git switch $(git_main_branch)'
alias gta='git tag --annotate'
alias gts='git tag --sign'
alias gtv='git tag | sort -V'
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
alias gwch='git log --patch --abbrev-commit --pretty=medium --raw'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'
alias gwtmv='git worktree move'
alias gwtrm='git worktree remove'
alias gstu='gsta --include-untracked'
