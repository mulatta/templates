{ pkgs }:
final: prev:
let
  inherit (pkgs) lib stdenv;
  inherit (final) resolveBuildSystem;

  addBuildSystems =
    pkg: spec:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ resolveBuildSystem spec;
    });

  # Define common build system overrides for packages
  # These are necessary because uv.lock doesn't contain build-system metadata
  buildSystemOverrides = {
    # Add custom build backend overrides
    # packages  = {
    #   # add custom backend dependencies here
    #   setuptools = [ ];
    #   cython = [ ];
    # };
  };
in
lib.mapAttrs (name: spec: addBuildSystems prev.${name} spec) buildSystemOverrides
// {
  # Add specific package overrides here
  # Example for packages with C extensions or special build requirements:
  #
  # biopython = prev.biopython.overrideAttrs (attrs: {
  #   nativeBuildInputs = attrs.nativeBuildInputs or [ ] ++ [ final.setuptools ];
  #   buildInputs = attrs.buildInputs or [ ] ++ [ pkgs.zlib ];
  # });
}
