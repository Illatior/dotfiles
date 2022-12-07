# Path to your oh-my-zsh installation.
export ZSH="$HOME/.local/share/oh-my-zsh"

export EDITOR="vim"
export VISUAL="vim"

bindkey -v

[[ $- != *i* ]] && return


function extract {
 if [ -z "$1" ]; then
    # display usage if no parameters given
    echo "Usage: extract <path/file_name>.<zip|rar|bz2|gz|tar|tbz2|tgz|Z|7z|xz|ex|tar.bz2|tar.gz|tar.xz>"
    echo "       extract <path/file_name_1.ext> [path/file_name_2.ext] [path/file_name_3.ext]"
 else
    for n in "$@"
    do
      if [ -f "$n" ] ; then
          case "${n%,}" in
            *.cbt|*.tar.bz2|*.tar.gz|*.tar.xz|*.tbz2|*.tgz|*.txz|*.tar)
                         tar xvf "$n"       ;;
            *.lzma)      unlzma ./"$n"      ;;
            *.bz2)       bunzip2 ./"$n"     ;;
            *.cbr|*.rar)       unrar x -ad ./"$n" ;;
            *.gz)        gunzip ./"$n"      ;;
            *.cbz|*.epub|*.zip)       unzip ./"$n"       ;;
            *.z)         uncompress ./"$n"  ;;
            *.7z|*.arj|*.cab|*.cb7|*.chm|*.deb|*.dmg|*.iso|*.lzh|*.msi|*.pkg|*.rpm|*.udf|*.wim|*.xar)
                         7z x ./"$n"        ;;
            *.xz)        unxz ./"$n"        ;;
            *.exe)       cabextract ./"$n"  ;;
            *.cpio)      cpio -id < ./"$n"  ;;
            *.cba|*.ace)      unace x ./"$n"      ;;
            *)
                         echo "extract: '$n' - unknown archive method"
                         return 1
                         ;;
          esac
      else
          echo "'$n' - file does not exist"
          return 1
      fi
    done
fi
}


# ----- goenv ------
[[ -d "${HOME}/.goenv" ]] && export GOENV_ROOT="${HOME}/.goenv"

if [ ! -z "${GOENV_ROOT}" ]; then
  export PATH="${GOENV_ROOT}/bin:${PATH}"
  eval "$(goenv init -)"
  #export PATH="${GOENV_ROOT}/bin:${PATH}"
  #export PATH="${PATH}:${GOPATH}/bin"
fi

# ----- Aliases ------

alias vim="nvim"

alias dc="docker-compose"

alias grep="grep --color=auto"

alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'

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

# vi-mode configuration
VI_MODE_RESET_PROMT_ON_MODE_CHANGE=false
VI_MODE_SET_CURSOR=true

source $ZSH/oh-my-zsh.sh

eval "$(starship init zsh)"
eval "$(rbenv init - zsh)"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"
