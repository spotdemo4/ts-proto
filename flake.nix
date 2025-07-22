{
  description = "Trevstack Protobufs";

  nixConfig = {
    extra-substituters = [
      "https://trevnur.cachix.org"
    ];
    extra-trusted-public-keys = [
      "trevnur.cachix.org-1:hBd15IdszwT52aOxdKs5vNTbq36emvEeGqpb25Bkq6o="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    nur,
    ...
  }: let
    build-systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
    forSystem = f:
      nixpkgs.lib.genAttrs build-systems (
        system:
          f {
            inherit system;
            pkgs = import nixpkgs {
              inherit system;
              overlays = [nur.overlays.default];
            };
          }
      );

    fetchBufDeps = {
      pkgs,
      hash,
    }:
      pkgs.stdenv.mkDerivation (finalAttrs: {
        name = "source";
        src = pkgs.nix-gitignore.gitignoreSource [] ./.;

        nativeBuildInputs = with pkgs; [
          buf
        ];

        buildPhase = ''
          HOME=$(pwd)
          buf dep graph
        '';
        installPhase = ''
          cp -r . "$out"
        '';

        # fixed output derivation
        outputHashAlgo = "sha256";
        outputHashMode = "recursive";
        outputHash = hash;
      });

    ts-proto = forSystem ({pkgs, ...}:
      pkgs.stdenv.mkDerivation {
        pname = "ts-proto";
        version = "1.0.0";

        src = fetchBufDeps {
          pkgs = pkgs;
          hash = "sha256-e3UcfoeYqPn7wsiC9PVUslhJhhwCM958a1wmR6k8wUs=";
        };

        nativeBuildInputs = with pkgs; [
          buf
        ];

        doCheck = true;
        checkPhase = ''
          HOME=$(pwd)
          buf lint
        '';
        dontBuild = true;
        installPhase = ''
          touch $out
        '';
      });
  in rec {
    devShells = forSystem ({pkgs, ...}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          git
          buf

          # Nix
          nix-update
          alejandra

          # Actions
          prettier
          action-validator
          renovate
        ];
        shellHook = ''
          echo "nix flake check --accept-flake-config" > .git/hooks/pre-push
          chmod +x .git/hooks/pre-push
        '';
      };
    });

    checks = forSystem ({
      system,
      pkgs,
      ...
    }:
      pkgs.nur.repos.trev.lib.mkChecks {
        lint = {
          src = ./.;
          nativeBuildInputs = with pkgs; [
            alejandra
            prettier
            action-validator
            renovate
          ];
          checkPhase = ''
            alejandra -c .
            prettier --check .
            action-validator .github/workflows/*
            action-validator .gitea/workflows/*
            action-validator .forgejo/workflows/*
            renovate-config-validator
          '';
          installPhase = ''
            cp -r .cache/buf "$out"
          '';
          outputHashAlgo = "sha256";
          outputHashMode = "recursive";
          outputHash = "sha256-W3141wtpQ4OHrEV+2soKzSiMsFiCVeSShbpOFUASe84=";
        };
      }
      // {
        build = ts-proto."${system}";
        shell = devShells."${system}".default;
      });

    formatter = forSystem ({pkgs, ...}: pkgs.alejandra);

    packages = forSystem ({system, ...}: {
      default = ts-proto."${system}";
    });
  };
}
