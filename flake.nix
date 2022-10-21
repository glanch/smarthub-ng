{
  inputs.nixpkgs.url = github:NixOS/nixpkgs;
  inputs.home-manager.url = github:nix-community/home-manager;
  
  outputs = { self, nixpkgs, home-manager, ... }@attrs: {
    nixosConfigurations."smarthub-ng" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = attrs;
      modules = [ ./configuration.nix home-manager.nixosModules.home-manager ];
    };
  };
}
