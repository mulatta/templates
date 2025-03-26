{
  description = "pixi env";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };
  outputs =
    { self, nixpkgs, ... }:
    let
      # Define supported systems
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Our own forAllSystems function without flake-utils
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      # Create devShells.<system>.default for each system
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          isLinux = pkgs.stdenv.isLinux;
          isDarwin = pkgs.stdenv.isDarwin;
        in
        {
          default =
            if isLinux then
              # For Linux, use FHS environment
              (pkgs.buildFHSEnv {
                name = "pixi-env";
                targetPkgs = _: [ pkgs.pixi ];
              }).env
            else if isDarwin then
              # For macOS, use a simple shell with pixi
              pkgs.mkShell {
                packages = [ pkgs.pixi ];
                shellHook = ''
                  echo "pixi environment activated on macOS"
                '';
              }
            else
              # Fallback for other platforms
              pkgs.mkShell {
                packages = [ ];
                shellHook = ''
                  echo "pixi is not supported on this platform"
                  exit 1
                '';
              };
        }
      );
    };
}
