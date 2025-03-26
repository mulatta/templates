{
  description = "Nix Development Environment for Python Template";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          # overlays = overlays;
          config = {
            allowUnfree = true;
          };
        }
      );

      # Function to create Python environment for each system
      pythonEnvFor =
        system:
        let
          pkgs = pkgsFor.${system};
          python = pkgs.python312;

          # Load workspace configuration from current directory
          workspace = uv2nix.lib.workspace.loadWorkspace {
            workspaceRoot = ./.;
          };

          # Create package overlay from workspace
          overlay = workspace.mkPyprojectOverlay {
            # Prefer prebuilt binary wheels for better compatibility
            sourcePreference = "wheel";
          };

          # Define custom overrides for packages if needed
          pyprojectOverrides = _final: _prev: {
            # Add package-specific overrides here if necessary
          };

          # Construct the Python package set with all overlays
          pythonSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                  pyprojectOverrides
                ]
              );
        in
        {
          inherit
            workspace
            pythonSet
            pkgs
            python
            ;
        };

    in
    {
      # Define development shells for all supported systems
      devShells = forAllSystems (
        system:
        let
          env = pythonEnvFor system;
          inherit (env)
            workspace
            pythonSet
            pkgs
            python
            ;
        in
        {
          # Impure development shell using uv for virtual environment management
          impure = pkgs.mkShell {
            packages = [
              python
              pkgs.uv
            ];
            env =
              {
                # Prevent uv from managing Python downloads
                UV_PYTHON_DOWNLOADS = "never";
                # Force uv to use nixpkgs Python interpreter
                UV_PYTHON = python.interpreter;
              }
              // lib.optionalAttrs pkgs.stdenv.isLinux {
                # Set library path for Linux systems to help with native dependencies
                LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux1;
              };
            shellHook = ''
              # Clear PYTHONPATH to avoid conflicts with system Python
              unset PYTHONPATH

              echo "Entered impure Python development shell"
              echo "Use 'uv venv create --python $UV_PYTHON .venv' to create a virtual environment"
              echo "Then 'source .venv/bin/activate' to activate it"
            '';
          };

          # Pure development shell using uv2nix
          uv2nix =
            let
              # Create overlay for editable local packages
              editableOverlay = workspace.mkEditablePyprojectOverlay {
                # Use environment variable to find repository root
                root = "$REPO_ROOT";
                # Uncomment to enable editable mode only for specific packages
                # members = [ "your-package-name" ];
              };

              # Apply editable overlay to the Python set
              editablePythonSet = pythonSet.overrideScope (
                lib.composeManyExtensions [
                  editableOverlay

                  # Add package-specific editable fixes if needed
                  (final: prev: {
                    # Example override for a local package
                    # your-package = prev.your-package.overrideAttrs (old: {
                    #   # Filter source files for faster rebuilds
                    #   src = lib.fileset.toSource {
                    #     root = old.src;
                    #     fileset = lib.fileset.unions [
                    #       (old.src + "/pyproject.toml")
                    #       (old.src + "/src")
                    #     ];
                    #   };
                    #
                    #   # Add editables dependency for PEP-660 support
                    #   nativeBuildInputs = old.nativeBuildInputs
                    #     ++ final.resolveBuildSystem {
                    #       editables = [ ];
                    #     };
                    # });
                  })
                ]
              );

              # Create virtual environment with all dependencies
              virtualenv = editablePythonSet.mkVirtualEnv "dev-env" workspace.deps.all;

            in
            pkgs.mkShell {
              packages = [
                virtualenv
                pkgs.uv
              ];

              env = {
                # Disable uv sync since we're using the Nix-built venv
                UV_NO_SYNC = "1";
                # Use Python from the virtual environment
                UV_PYTHON = "${virtualenv}/bin/python";
                # Don't download Python interpreters
                UV_PYTHON_DOWNLOADS = "never";
              };

              shellHook = ''
                # Clear PYTHONPATH to avoid conflicts
                unset PYTHONPATH

                # Get repository root for editable packages
                export REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo $PWD)

                echo "Entered pure Python development shell using uv2nix"
                echo "All dependencies are already installed in a Nix-managed virtual environment"
                echo "Local packages are in editable mode - changes will be immediately available"
              '';
            };

          # Default development shell
          default = pkgs.mkShell {
            packages = [
              python
            ];
            shellHook = ''
              echo "Entered basic Python development shell"
              echo "For more advanced environments, use:"
              echo "  - nix develop .#impure  (for uv-managed virtual environments)"
              echo "  - nix develop .#uv2nix  (for fully Nix-managed development with editable mode)"
            '';
          };
        }
      );
    };
}
