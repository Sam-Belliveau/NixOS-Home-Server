{ lib, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      # Fall back to completion-based suggestions when history has no match,
      # matching the Mac's ZSH_AUTOSUGGEST_STRATEGY=(history completion).
      strategy = [ "history" "completion" ];
    };
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

      # Rebuild samb-tower from the latest commit on GitHub main, pinning the
      # exact rev so the build is reproducible (and printed). Builds straight
      # from the GitHub flake ref, so it needs no local checkout. Reboots on a
      # successful switch -- swap `sudo reboot` for
      # `systemctl --user restart sunshine` if you only want to re-activate
      # user services without a full reboot.
      pull_and_rebuild() {
        local repo="Sam-Belliveau/NixOS-Home-Server" host="samb-tower" sha
        sha=$(git ls-remote "https://github.com/$repo" refs/heads/main | cut -f1) || return 1
        [[ -n "$sha" ]] || { echo "pull_and_rebuild: could not resolve latest commit" >&2; return 1; }
        echo "==> Rebuilding $host from $repo @ $sha"
        sudo nixos-rebuild switch --flake "github:$repo/$sha#$host" || return 1
        echo "==> Switch OK. Rebooting…"
        sudo reboot
      }

      bindkey -e   # emacs keybindings (so the bindings below land predictably)

      # Tab is left as the stock completion menu — one key, one behavior, never
      # dependent on whether a grey suggestion happens to be showing. Accept the
      # grey autosuggestion with → / End / Ctrl-E / Ctrl-F (bound by
      # zsh-autosuggestions by default).

      # Up / Down: prefix history search. Default Up (up-line-or-history) walks
      # ALL history chronologically; these walk only history lines starting with
      # what you've already typed — landing on the same line the grey suggestion
      # shows, then cycling older matches.
      autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
      zle -N up-line-or-beginning-search
      zle -N down-line-or-beginning-search
      bindkey '^[[A' up-line-or-beginning-search      # Up   (CSI)
      bindkey '^[[B' down-line-or-beginning-search    # Down (CSI)
      bindkey '^[OA' up-line-or-beginning-search      # Up   (application/keypad mode)
      bindkey '^[OB' down-line-or-beginning-search    # Down (application/keypad mode)
      [[ -n "''${terminfo[kcuu1]}" ]] && bindkey "''${terminfo[kcuu1]}" up-line-or-beginning-search
      [[ -n "''${terminfo[kcud1]}" ]] && bindkey "''${terminfo[kcud1]}" down-line-or-beginning-search
    '';
  };
}
