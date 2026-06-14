{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # C / C++
    gcc
    clang
    clang-tools
    lld
    llvmPackages.lldb
    gdb
    # Build systems
    cmake
    ninja
    meson
    pkg-config
    autoconf
    automake
    libtool
    gnumake
    # Rust
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    # Other languages
    go
    ruby
    perl
    nodejs_22
    pnpm
    yarn
    bun
    jdk
    # Nix
    nixd
    statix
    deadnix
  ];
}
