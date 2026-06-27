{ pkgs, ... }:
{
  # What pip-installed ML wheels (torch / nerfstudio / gsplat) assume a stock FHS
  # Linux provides, but NixOS does not — set here so the consuming code (e.g. the
  # courtyard reconstruction worker) needs no NixOS-specific shims and just runs as
  # it would on Ubuntu.
  environment.sessionVariables = {
    # nerfstudio fetches the LPIPS weights through torch.hub at model build; the
    # uv-managed standalone Python has no default CA bundle, so without this its TLS
    # cannot verify the download.
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

    # Disable torch.compile / TorchInductor. Inductor shells out to `ldconfig -p`
    # for a library listing, which NixOS cannot produce (no /etc/ld.so.cache), so
    # any compiled forward pass aborts. The only thing splatfacto-w compiles is a
    # 4×4 matrix helper, so eager execution costs nothing; gsplat's own CUDA kernels
    # are unaffected.
    TORCHDYNAMO_DISABLE = "1";
  };
}
