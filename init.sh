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
alias dbgr='devbox global run'
alias cddevbox='cd $DEVBOX_GLOBAL_ROOT'

# other aliases
alias cat='bat'
alias ls='exa --icons=auto --group-directories-first'
alias l='ls -a'
alias l1='ls -1'
alias la='ls -AF'
alias lf='ls -F'
alias ll='ls -alh --git'
alias explorer='explorer.exe'
