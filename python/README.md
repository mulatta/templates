# Project Name

## Directory Structure

```
    project-name/
  ├── .git/
  ├── .gitignore
  ├── .envrc                   # direnv configuration
  ├── README.md
  ├── LICENSE
  ├── pyproject.toml           # project configuration file
  ├── flake.nix                # Nix configurations
  ├── flake.lock               # Nix dependencies lock file
  ├── src/                     # source codes
  │   └── package_name/        # package name directory
  │       ├── __init__.py      # package declaration script
  │       ├── main.py          # core function module
  │       └── module1.py       # function module 1
  ├── tests/                   # test code
  │   ├── __init__.py
  │   ├── test_main.py
  │   └── test_module1.py
  ├── docs/                    # Documentations
  │   └── index.md
  └── .venv/                   # virtual environment for python
```

## Usage

### Development Environments

There are 2 types of python shell in nix dev-envs: `impure` shell and `uv2nix` shell.
For scalability and integration, both UV-based and Nix-based Python environments are supported.
In the Nix-python environment, dependencies fixed by uv will be locked into nix by uv2nixl.

### Direnv configuration

For switching shell easily, direnv support `switch_shell` function
since direnv does not directly support exporting function in `.envrc`, you should add `export_func` in direnvrc file.
switch_shell function scripts
