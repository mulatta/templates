# Usage

To check available flake templates,

```
  nix flake show github:mulatta/templates
```

To create new flake with templates,

```
  nix flake new --template github:mulatta/templates#python ./pytest
```

To init directory with flake templates,

```
  nix flake init -t github:mulatta/templates#python
```

To use direnv switch function, define following function to stdlib in your direnvrc

```
  nix flake new --template github:mulatta/templates#python ./pytest
```
