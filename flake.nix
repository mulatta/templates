{
  description = "Project description";

  outputs =
    {
      self,
      nixpkgs,
      mulatta-nur,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      gitignore,
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

      overlays = {
        default = lib.composeManyExtensions [
          gitignore.overlay
          mulatta-nur.overlay
          (import ./nix/overlay.nix {
            inherit uv2nix pyproject-nix pyproject-build-systems;
          })
        ];
      };

      # Import nixpkgs with overlays for each system
      pkgsFor = forAllSystems (
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlays.default ];
          config = {
            allowUnfree = true;
          };
        }
      );

      # Common development tools
      commonDeps =
        system: with pkgsFor.${system}; [
          just
          edirect
          seqtk
          clustal-omega
          cd-hit
          blast-bin
          seqkit
        ];

      preCommitDeps =
        system: with pkgsFor.${system}; [
          actionlint
          codespell
          deadnix
          git
          just
          nixpkgs-fmt
          nodejs_20.pkgs.prettier
          shellcheck
          shfmt
          statix
          taplo-cli
        ];

    in
    {
      inherit overlays;

      # Packages for each supported system
      packages = forAllSystems (system: {
        default = pkgsFor.${system}.package312;
        inherit (pkgsFor.${system}) package312 uv;
      });

      # Development shells for each supported system
      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor.${system};
          python = pkgs.python312;

          # Create a uv2nix managed shell with the given environment
          mkUv2nixShell =
            env:
            pkgs.mkShell {
              inherit (env) name;
              packages = [
                env
                pkgs.uv
              ] ++ commonDeps system;

              shellHook = ''
                echo ""
                echo "Entered pure(uv2nix) shell"
                echo ""

                # Undo dependency propagation by nixpkgs.
                unset PYTHONPATH

                # Get repository root using git. This is expanded at runtime by the editable `.pth` machinery.
                export REPO_ROOT=$(git rev-parse --show-toplevel)
              '';
            };

          # Create an impure shell that uses uv to manage virtual environments
          mkImpureShell =
            pythonVersion:
            pkgs.mkShell {
              name = "package-impure-${lib.strings.removePrefix "python" (builtins.parseDrvName pythonVersion.name).name}";
              packages = [
                pythonVersion
                pkgs.uv
              ] ++ commonDeps system;

              env =
                {
                  # Prevent uv from managing Python downloads
                  UV_PYTHON_DOWNLOADS = "never";
                  # Force uv to use nixpkgs Python interpreter
                  UV_PYTHON = pythonVersion.interpreter;
                }
                // lib.optionalAttrs pkgs.stdenv.isLinux {
                  # Python libraries often load native shared objects using dlopen(3).
                  # Setting LD_LIBRARY_PATH makes the dynamic library loader aware
                  # of libraries without using RPATH for lookup.
                  LD_LIBRARY_PATH = lib.makeLibraryPath pkgs.pythonManylinuxPackages.manylinux1;
                };

              shellHook = ''
                echo ""
                echo "Entered impure shell"
                echo ""

                if [ -f .venv/bin/activate ]; then
                  source .venv/bin/activate
                fi

                # Undo dependency propagation by nixpkgs.
                unset PYTHONPATH

                if git rev-parse --show-toplevel >/dev/null 2>&1; then
                  export REPO_ROOT=$(git rev-parse --show-toplevel)
                else
                  export REPO_ROOT=$PWD
                  echo "Warning: Not in a git repository. Using current directory."
                fi
              '';
            };
        in
        {

          # set default shell as impure shell uses Python 3.12
          default = mkImpureShell pkgs.python312;

          # uv2nix managed shells for different Python versions
          pure = mkUv2nixShell (
            pkgs.packageDevEnv312.overrideAttrs (old: {
              name = "package-uv2nix-py312";
            })
          );

          # pre-commit
          preCommit = pkgs.mkShell {
            name = "preCommit";
            packages = preCommitDeps system ++ [ pkgs.packageDevEnv312 ];
          };
        }
      );
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    # Nix User Repository
    mulatta-nur.url = "github:mulatta/NUR";

    # Python packaging tools
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
    gitignore = {
      url = "github:hercules-ci/gitignore.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
