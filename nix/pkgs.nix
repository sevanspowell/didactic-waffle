# our packages overlay
pkgs: prev: with pkgs;
let
  compiler = config.haskellNix.compiler or "ghc8107";
in {
  # systemd can't be statically linked:
  postgresql = (prev.postgresql_11
    .overrideAttrs (_: { dontDisableStatic = stdenv.hostPlatform.isMusl; }))
    .override {
      enableSystemd = stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isMusl;
      gssSupport = stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isMusl;
    };
}
