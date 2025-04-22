{
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  ...
}:
pkgs: super:
let
  # Create package overlay from workspace.
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };

  envOverlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Create an overlay enabling editable mode for all local dependencies.
  # This is for usage with `nix develop`
  editableOverlay = workspace.mkEditablePyprojectOverlay {
    root = "$REPO_ROOT";
  };

  # Build fixups overlay
  pyprojectOverrides = import ./pyproject-overrides.nix { inherit pkgs; };

  # Default dependencies for env
  defaultDeps = {
    package = [ ];
  };

  inherit (pkgs) lib stdenv;

  mkEnv' =
    {
      # Python dependency specification
      deps,
      # Installs project package as an editable package for use with `nix develop`.
      # This means that any changes done to your local files do not require a rebuild.
      editable,
    }:
    python:
    let
      inherit (stdenv) targetPlatform;
      # Construct package set
      pythonSet =
        # Use base package set from pyproject.nix builders
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
          stdenv = stdenv.override {
            targetPlatform =
              targetPlatform
              // lib.optionalAttrs targetPlatform.isDarwin {
                darwinSdkVersion = if targetPlatform.isAarch64 then "14.0" else "12.0";
              };
          };
        }).overrideScope
          (
            lib.composeManyExtensions (
              [
                pyproject-build-systems.overlays.default
                envOverlay
                pyprojectOverrides
              ]
              ++ lib.optionals editable [ editableOverlay ]
            )
          );
    in
    # Build virtual environment
    pythonSet.mkVirtualEnv "package-${python.pythonVersion}" deps;

  mkEnv = mkEnv' {
    deps = defaultDeps;
    editable = false;
  };

  mkDevEnv = mkEnv' {
    # Enable all dependencies for development shell
    deps = workspace.deps.all;
    editable = true;
  };

in
{
  # Add development environments for various Python versions
  package312 = mkEnv pkgs.python312;
  packageDevEnv312 = mkDevEnv pkgs.python312;
}
