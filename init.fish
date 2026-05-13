set fish_greeting ""

if status is-interactive
    function starship_transient_prompt_func
        starship module character
    end

    starship init fish | source
    enable_transience
    
    direnv hook fish | source

    # devbox helpers
    alias dbr='devbox run'
    alias dbgr='devbox global run'
    alias cddevbox='cd $DEVBOX_GLOBAL_ROOT'

    # other aliases
    alias catp='bat --plain'
    alias cat='bat'
    alias ls='eza --icons=auto --group-directories-first'
    alias l='ls -a'
    alias l1='ls -1'
    alias la='ls -AF'
    alias lf='ls -F'
    alias ll='ls -al --git'

    # Vendored autopair (see autopair.fish header): remove ~/.config/fish/conf.d/autopair.fish
    # and _autopair_*.fish if you still have Fisher’s copy, to avoid double bindings.
    set -l _devbox_fish_dir (path dirname (status filename))
    set -l _autopair $_devbox_fish_dir/autopair.fish
    if test -r "$_autopair"
        source "$_autopair"
    end

    set -l _git_aliases $_devbox_fish_dir/git-aliases.fish
    if test -r "$_git_aliases"
        source "$_git_aliases"
    end
end

# Plain version: Default native Docker Scout output
function scoutp
    if test -z "$argv[1]"
        echo "Usage: scoutp <image>"
        return 1
    end

    if not command -v docker >/dev/null; or not docker info >/dev/null 2>&1
        echo "Error: Docker not found or daemon not running"
        return 1
    end

    # Uses default native format and filters the stderr junk
    docker scout cves $argv 2>&1 | \
    grep -vE "SBOM of image|packages indexed|No vulnerable package detected"
end

# Pretty version: Forces markdown format to enable emoji replacement via w3m
function scout
    # We call docker scout directly here because it needs specific flags 
    # and pipes (markdown + w3m) that scoutp no longer uses.
    docker scout cves --format markdown $argv 2>&1 | \
    grep -vE "SBOM of image|packages indexed|No vulnerable package detected" | \
    sed -e 's/:mag:/🔍/g' \
        -e 's/:package:/📦/g' \
        -e 's/:white_check_mark:/✅/g' \
        -e 's/:x:/❌/g' \
        -e 's/:warning:/⚠️/g' \
        -e 's/Critical/💀 Critical/Ig' \
        -e 's/High/🔴 High/Ig' \
        -e 's/Medium/🟠 Medium/Ig' \
        -e 's/Low/🟡 Low/Ig' | \
    w3m -T text/html -dump
end
