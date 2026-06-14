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
    '';
  };
}
