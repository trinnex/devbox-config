shell=`ps -p $$ | awk 'NR>1  {print $4}' | sed 's/-//g'`
SCRIPT_PATH="$HOME/.local/share/devbox/global/current"

case $(basename $shell) in
     "zsh" )
            . $DEVBOX_GLOBAL_ROOT/zsh/.zshrc
           ;;
     "bash" )
            . $DEVBOX_GLOBAL_ROOT/bash/.bashrc
           ;;
     * )
           ;;
esac

# devbox helpers
alias dbr='devbox run'
alias cddevbox='cd $DEVBOX_GLOBAL_ROOT'

# other aliases
alias cat='bat'
alias l='exa -a --icons=auto --hyperlink --group-directories-first'
alias l1='exa -1 --icons=auto --group-directories-first'
alias la='exa -AF --icons=auto --group-directories-first'
alias lf='exa -F --icons=auto --group-directories-first'
alias ll='exa -alh --icons=auto --hyperlink --group-directories-first --git'
alias ls='ls --color=auto'

export name=global