case $- in
  *i*) ;;
  *) return ;;
esac

# Path used by reload-bash (valid when sourced, not copied into subshells without export)
_DEVBOX_INIT_BASH_PATH="${BASH_SOURCE[0]}"

# History (Fish-ish: persistent, roomy; Bash 3.2 has no erasedups in HISTCONTROL)
export HISTSIZE=50000
export HISTFILESIZE=500000
export HISTCONTROL=ignoreboth
export HISTTIMEFORMAT='%F %T  '
export HISTFILE="${HISTFILE:-$HOME/.bash_history}"

shopt -s histappend cmdhist
shopt -s lithist 2>/dev/null || true

# Readline: show options, quieter bell, Fish-like prefix search
bind 'set show-all-if-ambiguous on' 2>/dev/null || true
bind 'set colored-stats on' 2>/dev/null || true
bind 'set bell-style none' 2>/dev/null || true
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
bind '"\C-p": history-search-backward'
bind '"\C-n": history-search-forward'

# Bash 3.2-safe usability
shopt -s checkwinsize extglob

_devbox_path_component_matches_case() {
  local parent="$1"
  local component="$2"
  local entry

  [[ "$component" == "." || "$component" == ".." ]] && return 0

  for entry in "$parent"/* "$parent"/.[!.]* "$parent"/..?*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    [[ "${entry##*/}" == "$component" ]] && return 0
  done

  return 1
}

_devbox_path_matches_case() {
  local target="$1"
  local path parent component
  local old_ifs="$IFS"
  local -a parts

  [[ -z "$target" || "$target" == "-" || "$target" == -* ]] && return 0

  case "$target" in
    "~") path="$HOME" ;;
    "~/"*) path="$HOME/${target#~/}" ;;
    /*) path="$target" ;;
    *) path="$PWD/$target" ;;
  esac

  IFS=/
  read -r -a parts <<< "$path"
  IFS="$old_ifs"

  parent="/"
  for component in "${parts[@]}"; do
    [[ -z "$component" || "$component" == "." ]] && continue
    if [[ "$component" == ".." ]]; then
      parent="${parent%/*}"
      [[ -n "$parent" ]] || parent="/"
      continue
    fi

    _devbox_path_component_matches_case "$parent" "$component" || return 1
    if [[ "$parent" == "/" ]]; then
      parent="/$component"
    else
      parent="$parent/$component"
    fi
  done

  return 0
}

cd() {
  if [[ $# -gt 0 ]] && ! _devbox_path_matches_case "$1"; then
    printf 'cd: path casing does not match: %s\n' "$1" >&2
    return 1
  fi

  builtin cd "$@"
}

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook bash)"
fi

# Merge history across sessions; run before direnv/Starship preserved hook chain.
_devbox_hist_sync() {
  history -a
  history -n 2>/dev/null || history -r 2>/dev/null || true
  return 0
}

if [[ -n "${PROMPT_COMMAND:-}" ]]; then
  PROMPT_COMMAND="_devbox_hist_sync;${PROMPT_COMMAND}"
else
  PROMPT_COMMAND="_devbox_hist_sync"
fi

# devbox helpers
alias dbr='devbox run'
alias dbgr='devbox global run'
alias cddevbox='cd "$DEVBOX_GLOBAL_ROOT"'

# other aliases
alias catp='bat --plain'
alias cat='bat'
alias ls='eza --icons=auto --group-directories-first'
alias l='ls -a'
alias l1='ls -1'
alias la='ls -AF'
alias lf='ls -F'
alias ll='ls -al --git'

# Git aliases (oh-my-zsh plugins/git port; see git-aliases.sh)
_git_aliases_file="$(dirname -- "${BASH_SOURCE[0]}")/git-aliases.sh"
if [[ -r "$_git_aliases_file" ]]; then
  # shellcheck source=/dev/null
  source "$_git_aliases_file"
fi
unset _git_aliases_file

if command -v starship >/dev/null 2>&1 && [[ ${TERM:-dumb} != dumb ]]; then
  eval "$(starship init bash)"
  starship_precmd
fi
