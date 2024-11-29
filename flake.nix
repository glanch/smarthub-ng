{
  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
  inputs.home-manager.url = github:nix-community/home-manager;
  inputs.deploy-rs.url = "github:serokell/deploy-rs";
  inputs.agenix.url = "github:ryantm/agenix";

  outputs = { self, nixpkgs, home-manager, deploy-rs, agenix, ... }@attrs: {
    nixosConfigurations."smarthub-ng" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [ ./configuration.nix home-manager.nixosModules.home-manager ];
    };
    deploy.nodes.smarthub-ng = {
      hostname = "192.168.178.60";
      fastConnection = true;
      profiles = {
        system = {
          sshUser = "root";
          path =
            deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations."smarthub-ng";
          user = "root";
        };
      };
    };

    checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;

  };
}
