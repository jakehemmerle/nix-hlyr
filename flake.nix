{
  description = "HumanLayer / Riptide desktop app — unofficial Nix package, auto-updated from the Homebrew cask";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Upstream ships an arm64 macOS DMG only.
      systems = [ "aarch64-darwin" ];
      lib = nixpkgs.lib;
      forSystems = lib.genAttrs systems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      # Add `humanlayer` to any nixpkgs instance (nix-darwin / home-manager).
      overlays.default = final: _prev: {
        humanlayer = final.callPackage ./pkgs/humanlayer { };
      };

      packages = forSystems (
        system:
        let
          pkgs = pkgsFor system;
          humanlayer = pkgs.callPackage ./pkgs/humanlayer { };
        in
        {
          inherit humanlayer;
          default = humanlayer;
        }
      );

      apps = forSystems (
        system:
        let
          pkgs = pkgsFor system;
          humanlayer = self.packages.${system}.humanlayer;
          # `nix run` opens the GUI app.
          open = pkgs.writeShellScript "humanlayer-open" ''
            exec /usr/bin/open "${humanlayer}/Applications/HumanLayer.app" "$@"
          '';
        in
        {
          default = {
            type = "app";
            program = "${open}";
            meta.description = "Open the HumanLayer / Riptide desktop app";
          };
          # `nix run .#riptided` runs the bundled daemon directly.
          riptided = {
            type = "app";
            program = "${humanlayer}/bin/riptided";
            meta.description = "Run the bundled HumanLayer riptided daemon";
          };
        }
      );

      # `nix flake check` builds the package (downloads + unpacks the DMG).
      checks = forSystems (system: {
        build = self.packages.${system}.humanlayer;
      });

      formatter = forSystems (system: (pkgsFor system).nixfmt);
    };
}
