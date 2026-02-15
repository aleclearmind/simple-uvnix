# simple-uvnix

> [!WARNING]
> This project has been vibe coded.

Use uv-managed Python projects with Nix — without the boilerplate.

Wraps [uv2nix](https://github.com/pyproject-nix/uv2nix), [pyproject.nix](https://github.com/pyproject-nix/pyproject.nix), and [uv2nix_hammer_overrides](https://github.com/TyberiusPrime/uv2nix_hammer_overrides) into a single flake input.

## Quick start

```bash
mkdir myproject && cd myproject
git init
uv init --no-workspace
uv add numpy  # or whatever you need
```

Create `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    simple-uvnix.url = "github:aleclearmind/simple-uvnix.git";
    simple-uvnix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, simple-uvnix, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in {
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          env = simple-uvnix.lib.mkPythonShell {
            inherit pkgs;
            workspaceRoot = ./.;
          };
        in {
          default = env.devShell;
        }
      );

      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          env = simple-uvnix.lib.mkPythonShell {
            inherit pkgs;
            workspaceRoot = ./.;
          };
        in {
          default = env.package;
        }
      );
    };
}
```

```bash
git add -A
nix develop  # Python with all your deps
```

## API

`simple-uvnix.lib.mkPythonShell` takes an attrset:

| Parameter | Default | Description |
|---|---|---|
| `pkgs` | *required* | nixpkgs package set |
| `workspaceRoot` | *required* | Path to your project (contains `pyproject.toml` and `uv.lock`) |
| `python` | `pkgs.python312` | Python interpreter to use |
| `extraOverrides` | `_final: _prev: {}` | Additional per-package overrides (see below) |

It returns:

| Attribute | Description |
|---|---|
| `devShell` | `mkShell` with your Python virtualenv + uv |
| `package` | Standalone virtualenv derivation |

## Custom overrides

If a package needs extra native libraries that the hammer overrides don't cover:

```nix
env = simple-uvnix.lib.mkPythonShell {
  inherit pkgs;
  workspaceRoot = ./.;
  extraOverrides = final: prev: {
    some-package = prev.some-package.overrideAttrs (old: {
      buildInputs = (old.buildInputs or []) ++ [ final.pkgs.zlib ];
    });
  };
};
```

## Choosing a Python version

```nix
env = simple-uvnix.lib.mkPythonShell {
  inherit pkgs;
  workspaceRoot = ./.;
  python = pkgs.python313;
};
```
