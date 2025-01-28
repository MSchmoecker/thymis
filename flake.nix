{
  description = "Thymis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixpkgs-for-playwright-browsers.url = "github:NixOS/nixpkgs/e24b4c09e963677b1beea49d411cd315a024ad3a";
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators.url = "github:nix-community/nixos-generators";
    nixos-generators.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = inputss@{ self, nixpkgs, home-manager, poetry2nix, flake-utils, ... }:
    let
      inputs = inputss // {
        thymis = self;
      };
      eachSystem = nixpkgs.lib.genAttrs (import ./flake.systems.nix);
      nixosModules = {
        thymis-device = ./thymis-device-nixos-module.nix;
        thymis-controller = ./thymis-controller-nixos-module.nix;
      } // (nixpkgs.lib.mapAttrs'
        (name: value: {
          name = "thymis-device-${name}";
          value = value;
        })
        (import ./devices.nix { inherit inputs; lib = nixpkgs.lib; })
      ) // (nixpkgs.lib.mapAttrs'
        (name: value: {
          name = "thymis-image-${name}";
          value = value;
        })
        (import ./image-formats.nix { inherit inputs; lib = nixpkgs.lib; })
      );

      thymis-controller-pi-3-sd-image = (nixpkgs.lib.nixosSystem {
        modules = [
          nixosModules.thymis-device
          nixosModules."thymis-device-raspberry-pi-3"
          nixosModules."thymis-image-sd-card-image"
          nixosModules.thymis-controller
          {
            services.thymis-controller.enable = true;
            system.stateVersion = "24.11";
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      }).config.system.build.thymis-image-with-secrets-builder-aarch64;

      thymis-controller-pi-4-sd-image = (nixpkgs.lib.nixosSystem {
        modules = [
          nixosModules.thymis-device
          nixosModules."thymis-device-raspberry-pi-4"
          nixosModules."thymis-image-sd-card-image"
          nixosModules.thymis-controller
          {
            services.thymis-controller.enable = true;
            system.stateVersion = "24.11";
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      }).config.system.build.thymis-image-with-secrets-builder-aarch64;

      thymis-controller-pi-5-sd-image = (nixpkgs.lib.nixosSystem {
        modules = [
          nixosModules.thymis-device
          nixosModules."thymis-device-raspberry-pi-5"
          nixosModules."thymis-image-sd-card-image"
          nixosModules.thymis-controller
          {
            services.thymis-controller.enable = true;
            system.stateVersion = "24.11";
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      }).config.system.build.thymis-image-with-secrets-builder-aarch64;

      thymis-controller-generic-x86_64-image = (nixpkgs.lib.nixosSystem {
        modules = [
          nixosModules.thymis-device
          nixosModules."thymis-device-generic-x86_64"
          nixosModules."thymis-image-qcow"
          nixosModules.thymis-controller
          {
            services.thymis-controller.enable = true;
            system.stateVersion = "24.11";
          }
        ];
        specialArgs = {
          inherit inputs;
        };
      }).config.system.build.thymis-image-with-secrets-builder-x86_64;

      frontendPlaywrightVersion = (nixpkgs.lib.importJSON ./frontend/package-lock.json).packages."node_modules/playwright-core".version;

      removeRecurseForDerivations = nixpkgs.lib.filterAttrsRecursive (k: v: k != "recurseForDerivations");
    in
    {
      inputs = inputs;
      formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixpkgs-fmt);
      devShells = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsWithPlayWrightOverlays = import nixpkgs {
            inherit system;
            overlays = self.overlays;
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.poetry
              pkgs.python313
              pkgs.nodejs_22
              pkgs.pre-commit
              pkgsWithPlayWrightOverlays.playwright-driver-by-version."${frontendPlaywrightVersion}".browsers
              pkgs.mdbook
              pkgs.nixpkgs-fmt
            ];
            shellHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${pkgsWithPlayWrightOverlays.playwright-driver-by-version."${frontendPlaywrightVersion}".browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
              export THYMIS_DEV_SHELL=true
              export THYMIS_FLAKE_ROOT=$(git rev-parse --show-toplevel)
              alias run-dev="cd controller && UVICORN_PORT=8080 THYMIS_BASE_URL=http://127.0.0.1:8080 poetry run uvicorn thymis_controller.main:app --reload --host 0.0.0.0 --port 8080; cd .."
            '';
          };
          ci = pkgs.mkShell {
            packages = [
              pkgs.poetry
              pkgs.python313
              pkgs.nodejs_22
              pkgs.nixpkgs-fmt
            ];
          };
          onlyPlaywrightBrowsers = pkgs.mkShell {
            packages = [ pkgsWithPlayWrightOverlays.playwright-driver-by-version."${frontendPlaywrightVersion}".browsers ];
            shellHook = ''
              export PLAYWRIGHT_BROWSERS_PATH=${pkgsWithPlayWrightOverlays.playwright-driver-by-version."${frontendPlaywrightVersion}".browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
            PLAYWRIGHT_BROWSERS_PATH = pkgsWithPlayWrightOverlays.playwright-driver-by-version."${frontendPlaywrightVersion}".browsers;
            PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "true";
          };
        });

      overlays = [
        (import ./nix/playwright-by-version/playwright-driver-overlay.nix nixpkgs)
      ];
      packages = eachSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          pkgsWithPlayWrightOverlays = import inputs.nixpkgs-for-playwright-browsers {
            inherit system;
            overlays = self.overlays;
          };
          thymis-frontend = pkgs.callPackage ./frontend {
            git-rev = inputs.self.rev or inputs.self.dirtyRev or null;
          };
          thymis-controller = pkgs.callPackage ./controller {
            poetry2nix = (
              (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; })
            );
            thymis-frontend = thymis-frontend;
          };
          thymis-agent = pkgs.callPackage ./agent {
            poetry2nix = (
              (poetry2nix.lib.mkPoetry2Nix { inherit pkgs; })
            );
          };
        in
        {
          thymis-frontend = thymis-frontend;
          thymis-controller = thymis-controller;
          thymis-controller-container = import ./docker.nix { inherit pkgs thymis-controller; };
          thymis-agent = thymis-agent;
          playwright-driver-all = pkgs.writeText "playwright-driver-all.json"
            (builtins.toJSON (
              builtins.mapAttrs
                (name: driver: [ driver driver.browsers ])
                pkgsWithPlayWrightOverlays.playwright-driver-by-version
            ));
        }
      );
      nixosModules = nixosModules;
      thymis-controller-pi-3-sd-image = thymis-controller-pi-3-sd-image;
      thymis-controller-pi-4-sd-image = thymis-controller-pi-4-sd-image;
      thymis-controller-pi-5-sd-image = thymis-controller-pi-5-sd-image;
      thymis-controller-generic-x86_64-image = thymis-controller-generic-x86_64-image;
    };
}
