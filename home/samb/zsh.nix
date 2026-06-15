{ lib, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = {
      ls = "eza --group-directories-first";
      ll = "eza -lah --git";
      cat = "bat";
      g = "git";
      nrs = "sudo nixos-rebuild switch --flake .#samb-tower";
    };

    initContent = lib.mkOrder 1000 ''
      eval "$(zoxide init zsh)"

      # Auto-activate ./.venv on cd; deactivate on leaving it.
      _auto_venv() {
        if [[ -n $VIRTUAL_ENV && $PWD/ != ''${VIRTUAL_ENV:h}/* ]]; then
          deactivate 2>/dev/null
        fi
        if [[ -z $VIRTUAL_ENV && -f ./.venv/bin/activate ]]; then
          source ./.venv/bin/activate
        fi
      }
      autoload -U add-zsh-hook
      add-zsh-hook chpwd _auto_venv
      _auto_venv

      # OSC 52 clipboard over SSH (Ghostty): pbcopy sends stdin to the
      # terminal's clipboard; pbpaste queries it back.
      pbcopy() {
        printf '\033]52;c;%s\007' "$(base64 | tr -d '\r\n')" > /dev/tty
      }
      pbpaste() {
        local _old _data
        _old=$(stty -g < /dev/tty) || return 1
        stty raw -echo min 0 time 10 < /dev/tty   # read() returns after ~1s idle
        printf '\033]52;c;?\007' > /dev/tty        # ask the terminal for the clipboard
        _data=$(cat < /dev/tty)
        stty "$_old" < /dev/tty
        _data=''${_data#*;c;}                       # strip up to the payload
        _data=''${_data%%$'\007'*}                  # strip BEL terminator
        _data=''${_data%%$'\033'*}                  # ...or ST terminator
        printf '%s' "$_data" | base64 -d 2>/dev/null
      }
    '';
  };
}
