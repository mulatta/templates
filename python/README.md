# Project

# Guide to Enter Development Environment

## Primary Dependency

In this project, we highly recommend you to use `nix`.
With Nix, you can develop reproducible, declarative and reliable build ecosystem.

## General Workflow

At the initial status, use `impure shell` with `uv` to quickly add dependencies and packages for building/development.
Once we reach a stable phase, fix the build dependencies using `nix` in the `impure shell` to implement reproducible packages.

## DevShells

In this project, we provide 2 types of devshells, pure & impure shell.
Those shells give use encapsulated, reproducible development environments.

### Impure Shell (default shell)

In Impure shell, every python packages are managed by `uv` installed in nix devshell.

To enter impure shell, use `nix develop .#impure` in root directory.
Or, if you already in another shell and have just in your shell env, you can also use `just switch impure`.

You can use `uv add <packge name>` to add some python packages in your virtual environment.

### Pure shell (uv2nix shell)

In pure shell, every project dependencies are fixed by nix.
