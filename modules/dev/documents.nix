{ pkgs, ... }:
{
  # Document/media tooling that past sessions kept reaching for via `nix shell`.
  environment.systemPackages = with pkgs; [
    # LaTeX: full scheme so latexmk/lualatex/biber and any .sty just work
    texlive.combined.scheme-full
    # PDF
    poppler-utils # pdftotext, pdftoppm, pdfinfo, pdffonts
    qpdf
    pandoc
    # Image / media
    imagemagick
    ffmpeg
    yt-dlp
  ];
}
