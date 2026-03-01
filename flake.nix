{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (pkgs) lib;
    in
    {
      packages.x86_64-linux.default = pkgs.rustPlatform.buildRustPackage {
        pname = "nixos-test-keyring";
        version = "0.1.0";
        src = lib.cleanSourceWith {
          filter = path: _type: !lib.hasSuffix ".nix" path;
          src = lib.cleanSource ./.;
        };
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
            isNormalUser = true;
            home = "/home/machine";
            createHome = true;
            extraGroups = [ "wheel" ];
            password = "machine";
          };
          services.gnome.gnome-keyring.enable = true;
          services.xserver = {
            enable = true;
            updateDbusEnvironment = true;
            displayManager.startx.enable = true;
          };
        };
        testScript = ''
          machine.start();
          machine.wait_until_tty_matches("1", "login: ")
          machine.send_chars("machine\n")
          machine.wait_until_tty_matches("1", "Password: ")
          machine.send_chars("machine\n")
          machine.wait_for_unit("user@1000.service")
          machine.wait_for_unit("nixos-test-keyring.service", user="machine")
          machine.sleep(4) # wait for logs to be written
          logs = machine.succeed("journalctl _SYSTEMD_USER_UNIT=nixos-test-keyring.service")
          assert "ERROR" not in logs
          assert "successfully set password" in logs
          assert "successfully got password: password" in logs
        '';
      };
    };
}
