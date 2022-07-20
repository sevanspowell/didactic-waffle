############################################################################
# Builds Haskell packages with Haskell.nix
############################################################################
haskell-nix:

# This creates the Haskell package set.
# https://input-output-hk.github.io/haskell.nix/user-guide/projects/
haskell-nix.cabalProject' [
  ({ pkgs, lib, config, buildProject, ...}:
    let
      inherit (haskell-nix) haskellLib;

      inherit (pkgs) stdenv;


      src = haskell-nix.cleanSourceHaskell {
        name = "leavers-src";
        src = ../.;
      };

      compiler-nix-name = "ghc8107";

      projectPackages = lib.attrNames (haskellLib.selectProjectPackages
        (haskell-nix.cabalProject {
          inherit src compiler-nix-name;
        }));

      isCrossBuild = stdenv.hostPlatform != stdenv.buildPlatform;
    in
      {
        inherit src compiler-nix-name;

        shell = {
          name = "leavers-shell";
          packages = ps: builtins.attrValues (haskellLib.selectProjectPackages ps);

          crossPlatforms = p: [ p.ghcjs ];

          tools.hoogle = {
            inherit (pkgs.haskell-build-tools.hoogle) version;
            inherit (pkgs.haskell-build-tools.hoogle.project) index-state;
          };
          nativeBuildInputs = with buildProject.hsPkgs; [
          ] ++ (with pkgs.buildPackages.buildPackages; [
            haskellPackages.ghcid
            pkgconfig
            curlFull
            jq
            yq
            nixWrapped
            cabalWrapped
          ] ++ lib.filter
            (drv: lib.isDerivation drv && drv.name != "regenerate-materialized-nix")
            (lib.attrValues haskell-build-tools));

          LD_LIBRARY_PATH = lib.makeLibraryPath [
            pkgs.zlib
          ];

          meta.platforms = lib.platforms.unix;
        };

        modules = [
          ({ pkgs, config, ... }: {
            # Packages we wish to ignore version bounds of.
            # This is similar to jailbreakCabal, however it
            # does not require any messing with cabal files.
            packages.katip.doExactConfig = true;

            # Haddock generation for webkit2gtk3 fails with:
            # Setup: Graphics/UI/Gtk/WebKit/JavaScriptCore/JSValueRef.chi not found in:
            # /nix/store/a2xpbp9v6qlkq9zh2bcsbfslb5nvc0rd-ghc-8.10.7/lib/ghc-8.10.7/base-4.14.3.0
            # dist/build
            # .
            #
            # See https://github.com/gtk2hs/webkit-javascriptcore/issues/6
            packages.webkit2gtk3-javascriptcore.doHaddock = false;
          })
          {
            packages = lib.genAttrs projectPackages
              (name: { configureFlags = [ "--ghc-option=-Werror" ]; });
          }
          ({ pkgs, ... }: lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
            # systemd can't be statically linked
            packages.cardano-config.flags.systemd = !pkgs.stdenv.hostPlatform.isMusl;
            packages.cardano-node.flags.systemd = !pkgs.stdenv.hostPlatform.isMusl;

            # FIXME: Error loading shared library libHSvoting-tools-0.2.0.0-HDZeaOp1VIwKhm4zJgwaOj.so: No such file or directory
            # packages.voting-tools.components.tests.unit-tests.buildable = lib.mkForce (!pkgs.stdenv.hostPlatform.isMusl);
          })
          # Musl libc fully static build
          ({ pkgs, ... }: lib.mkIf pkgs.stdenv.hostPlatform.isMusl (let
            # Module options which adds GHC flags and libraries for a fully static build
            fullyStaticOptions = {
              enableShared = false;
              enableStatic = true;
              configureFlags = [
                "--ghc-option=-optl=-lssl"
                "--ghc-option=-optl=-lcrypto"
                "--ghc-option=-optl=-L${pkgs.openssl.out}/lib"
              ];
            };
          in
            {
              packages = lib.genAttrs projectPackages (name: fullyStaticOptions);

              # Haddock not working and not needed for cross builds
              doHaddock = false;
            }
          ))

          (lib.mkIf isCrossBuild ({ pkgs, ... }: {
            # Remove hsc2hs build-tool dependencies (suitable version will
            # be available as part of the ghc derivation)
            packages.Win32.components.library.build-tools = lib.mkForce [ ];
            packages.terminal-size.components.library.build-tools = lib.mkForce [ ];
            packages.network.components.library.build-tools = lib.mkForce [ ];

            # Make sure we use a buildPackages version of happy
            packages.pretty-show.components.library.build-tools = [
              pkgs.buildPackages.haskell-nix.haskellPackages.happy
            ];

            # Disable cabal-doctest tests by turning off custom setups
            packages.pretty-simple.package.buildType = lib.mkForce "Simple";
            packages.comonad.package.buildType = lib.mkForce "Simple";
            packages.distributive.package.buildType = lib.mkForce "Simple";
            packages.lens.package.buildType = lib.mkForce "Simple";
            packages.nonempty-vector.package.buildType = lib.mkForce "Simple";
            packages.semigroupoids.package.buildType = lib.mkForce "Simple";
          }))
        ];
      }
  )
]
