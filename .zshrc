# Path to your oh-my-zsh installation.
export ZSH="$HOME/.local/share/oh-my-zsh"

export EDITOR="vim"
export VISUAL="vim"

bindkey -v

[[ $- != *i* ]] && return

# ----- brew autocompletions --------
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# ----- goenv ------
[[ -d "${HOME}/.goenv" ]] && export GOENV_ROOT="${HOME}/.goenv"
if [ ! -z "${GOENV_ROOT}" ]; then
  export PATH="${GOENV_ROOT}/bin:${PATH}"
  eval "$(goenv init -)"
  #export PATH="${GOENV_ROOT}/bin:${PATH}"
  #export PATH="${PATH}:${GOPATH}/bin"
fi

# ----- nvm ------
[[ -d "${HOME}/.nvm)" ]] && export NVM_DIR="${HOME}/.nvm"
if [ ! -z "$(brew --prefix nvm)" ]; then
  source $(brew --prefix nvm)/nvm.sh
fi

# ----- Aliases ------

alias vim="nvim"

alias python="python3"
alias dc="docker-compose"
alias code="codium"

alias grep="grep --color=auto"

alias openvpn-connect='"/Applications/OpenVPN Connect/OpenVPN Connect.app/Contents/MacOS/OpenVPN Connect"'

alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'

alias config='$(which git) --git-dir=$HOME/.cfg/.git --work-tree=$HOME'

CASE_SENSITIVE="false" # case-insensetive completions

plugins=(
  docker
  docker-compose
  git
  golang
  zsh-autosuggestions
  zsh-syntax-highlighting
  vi-mode
  z
)

bindkey -s ^f "tmux-sessionizer\n"
bindkey -s ^g "tmux-grep\n"
bindkey -s ^t "tmux-attach\n"

# vi-mode configuration
VI_MODE_RESET_PROMT_ON_MODE_CHANGE=false
VI_MODE_SET_CURSOR=true

source $ZSH/oh-my-zsh.sh

eval "$(starship init zsh)"
eval "$(rbenv init - zsh)"
eval "$(direnv hook zsh)"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

