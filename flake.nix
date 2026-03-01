{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.x86_64-linux.default = pkgs.rustPlatform.buildRustPackage {
        pname = "nixos-test-keyring";
        version = "0.1.0";
        src = pkgs.lib.cleanSource ./.;
        cargoLock.lockFile = ./Cargo.lock;
      };
      nixosModules.default = { config, pkgs, lib, ... }: {
        config = {
          systemd.user.services.nixos-test-keyring = {
            description = "nixos-test-keyring";
            wantedBy = [ "default.target" ];
            serviceConfig = {
              Type = "simple";
              Restart = "always";
              ExecStart = ''
                ${self.packages.${system}.default}/bin/nixos-test-keyring
              '';
              Environment = [ "RUST_LOG=debug" ];
            };
          };
        };
      };
      checks.${system}.default = pkgs.testers.nixosTest {
        name = "nixos-test-keyring";
        nodes.machine = { config, pkgs, lib, ... }: {
          imports = [
            self.nixosModules.default
          ];
          users.users.machine = {
            linger = true;
            isNormalUser = true;
            home = "/home/machine";
            createHome = true;
            extraGroups = [ "wheel" ];
            password = "machine";
          };
          users.users.root = {
            hashedPassword = "";
            hashedPasswordFile = null;
          };
          services.gnome.gnome-keyring.enable = true;
          security.pam.services = {
            login.enableGnomeKeyring = true;
            su.enableGnomeKeyring = true;
          };
          services.xserver = {
            enable = true;
            updateDbusEnvironment = true;
            displayManager.startx.enable = true;
          };
          services.getty.autologinUser = "machine";
        };
        testScript = ''
          machine.start();
          machine.wait_for_unit("user@1000.service");
          machine.succeed("su -l machine -c 'echo -n \"machine\" | gnome-keyring-daemon --unlock'");
          machine.wait_for_unit("nixos-test-keyring.service", user="machine");
          machine.sleep(4); # wait for logs to be written
          machine.fail("su -l machine -c 'journalctl --user-unit nixos-test-keyring | grep ERROR'");
        '';
      };
    };
}
