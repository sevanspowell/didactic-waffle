{
  description = "Hydra";

  inputs = {
    nixpkgs.follows = "haskellNix/nixpkgs-2111";
    haskellNix = {
      url = "github:input-output-hk/haskell.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    utils.url = "github:numtide/flake-utils";
    iohkNix = {
      url = "github:input-output-hk/iohk-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, haskellNix, iohkNix, ... } @ inputs:
    let
      inherit (nixpkgs) lib;
      inherit (lib) head systems mapAttrs recursiveUpdate mkDefault
        getAttrs optionalAttrs nameValuePair attrNames;
      inherit (utils.lib) eachSystem mkApp flattenTree;
      inherit (iohkNix.lib) prefixNamesWith collectExes;

      supportedSystems = import ./nix/supported-systems.nix;
      defaultSystem = head supportedSystems;

      overlays = [
        haskellNix.overlay
        iohkNix.overlays.haskell-nix-extra
        iohkNix.overlays.utils
        (final: prev: {
          gitrev = self.rev or "dirty";
          commonLib = lib // iohkNix.lib;
        })
        (import ./nix/pkgs.nix)
        (import ./nix/build-tools.nix)
        (import ./nix/lib.nix)
      ];

      mkHydraJobs = system:
        lib.recursiveUpdate self.packages.${system} self.checks.${system} // {
          # nixosTests = import ./nix/nixos/tests/default.nix {
          #   inherit system inputs;
          #   pkgs = self.legacyPackages.${system};
          # };
        };

    in
      recursiveUpdate
        # System-dependent jobs
        (eachSystem supportedSystems (system:
          let
            pkgs = import nixpkgs {
              inherit system overlays;
              inherit (haskellNix) config;
            };

            project = (import ./nix/haskell.nix pkgs.haskell-nix).appendModule
              [
              ];

            flake = project.flake {
              crossPlatforms = p: with p; [ ghcjs ]
              ++ (lib.optionals (system == "x86_64-linux") [
                mingwW64
                musl64
              ]);
            };
            packages = collectExes flake.packages // {
            };

          in recursiveUpdate flake {

            inherit packages;

            legacyPackages = pkgs;

            devShell = project.shell;

            devShells.stylish = pkgs.mkShell { packages = with pkgs; [ stylish-haskell git ]; };

            # Built by `nix build .`
            defaultPackage = flake.packages."hydra:exe:ui";

            # Run by `nix run .`
            # defaultApp = flake.apps."voting-tools:exe:voting-tools";

            inherit (flake) apps;

            hydraJobs = mkHydraJobs system;
          }
        )
      )
    # Non-system-dependent jobs
    {
      hydraJobs.required = with self.legacyPackages.${lib.head supportedSystems}; releaseTools.aggregate {
        name = "github-required";
        meta.description = "All jobs required to pass CI";
        constituents = lib.collect lib.isDerivation (mkHydraJobs (lib.head supportedSystems)) ++ lib.singleton
          (writeText "forceNewEval" self.rev or "dirty");
      };
    };
}
