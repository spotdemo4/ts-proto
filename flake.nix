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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

      ts-proto = pkgs.stdenv.mkDerivation (finalAttrs: {
        pname = "ts-proto";
        version = "1.0.0";
        src = ./.;

        nativeBuildInputs = with pkgs; [
          buf
          pkgs.nur.repos.trev.lib.buf.configHook
        ];

        bufDeps = pkgs.nur.repos.trev.lib.buf.fetchDeps {
          inherit (finalAttrs) pname version src;
          hash = "sha256-W3141wtpQ4OHrEV+2soKzSiMsFiCVeSShbpOFUASe84=";
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
    in rec {
      devShells.default = pkgs.mkShell {
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

      checks =
        pkgs.nur.repos.trev.lib.mkChecks {
          lint = {
            src = ./.;
            deps = with pkgs; [
              alejandra
              prettier
              action-validator
              renovate
            ];
            script = ''
              alejandra -c .
              prettier --check .
              action-validator .github/workflows/*
              action-validator .gitea/workflows/*
              action-validator .forgejo/workflows/*
              renovate-config-validator
            '';
          };
        }
        // {
          build = ts-proto;
          shell = devShells.default;
        };

      packages.default = ts-proto;

      formatter = pkgs.alejandra;
    });
}
