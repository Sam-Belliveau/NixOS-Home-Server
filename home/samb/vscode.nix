{ pkgs, ... }:
{
  programs.vscode = {
    enable = true;
    mutableExtensionsDir = true;
    profiles.default = {
      userSettings = {
        "workbench.colorTheme" = "Visual Studio Dark";
        "editor.cursorStyle" = "block";
        "editor.cursorSmoothCaretAnimation" = "on";
        "git.autofetch" = true;
        "jupyter.askForKernelRestart" = false;
        "github.copilot.nextEditSuggestions.enabled" = true;
      };
      extensions = with pkgs.vscode-extensions; [
        ms-toolsai.jupyter
        ms-toolsai.vscode-jupyter-cell-tags
        ms-toolsai.vscode-jupyter-slideshow
        ms-toolsai.jupyter-keymap
        ms-toolsai.jupyter-renderers
        google.colab
        llvm-vs-code-extensions.lldb-dap
        github.vscode-pull-request-github
      ];
    };
  };
}
