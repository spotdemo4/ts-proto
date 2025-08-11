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
    systems.url = "systems";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    nixpkgs,
    utils,
    nur,
    ...
  }:
    utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [nur.overlays.default];
      };
    in rec {
      devShells.default = pkgs.mkShell {
        packages = with pkgs; [
          git
          buf

          # Nix
          alejandra
          nix-update
          flake-checker

          # Actions
          prettier
          action-validator
          pkgs.nur.repos.trev.renovate
        ];
        shellHook = pkgs.nur.repos.trev.shellhook.ref;
      };

      packages.default = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "ts-proto";
        version = "1.0.0";
        src = ./.;

        nativeBuildInputs = with pkgs; [
          buf
          pkgs.nur.repos.trev.lib.buf.configHook
        ];

        bufDeps = pkgs.nur.repos.trev.lib.buf.fetchDeps {
          inherit (finalAttrs) pname version src;
          hash = "sha256-jyUITwCLholh4t8+j9ELDqGoBLzI8J/2u9B1iVLnSiQ=";
        };

        dontBuild = true;

        doCheck = true;
        checkPhase = ''
          buf lint
        '';

        installPhase = ''
          touch $out
        '';
      });

      checks =
        pkgs.nur.repos.trev.lib.mkChecks {
          lint = {
            src = ./.;
            deps = with pkgs; [
              alejandra
              prettier
              action-validator
              pkgs.nur.repos.trev.renovate
            ];
            script = ''
              alejandra -c .
              prettier --check .
              action-validator .github/workflows/*
              action-validator .gitea/workflows/*
              renovate-config-validator
              renovate-config-validator .github/renovate-global.json
              renovate-config-validator .gitea/renovate-global.json
            '';
          };
        }
        // {
          build = packages.default;
          shell = devShells.default;
        };

      formatter = pkgs.alejandra;
    });
}
