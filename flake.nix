{
  description = "simple-uvnix: use uv + Nix without the boilerplate";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix-hammer-overrides = {
      url = "github:TyberiusPrime/uv2nix_hammer_overrides";
    };
  };

  outputs =
    {
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      uv2nix-hammer-overrides,
      ...
    }:
    {
      lib.addUvVirtualEnvToShell =
        {
          baseShell,
          pkgs,
          workspaceRoot,
          python,
          extraOverrides ? (_final: _prev: { }),
        }:
        let
          inherit (pkgs) lib;

          workspace = uv2nix.lib.workspace.loadWorkspace { inherit workspaceRoot; };

          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };

          baseSet =
            (pkgs.callPackage pyproject-nix.build.packages {
              inherit python;
            }).overrideScope
              (
                lib.composeManyExtensions [
                  pyproject-build-systems.overlays.default
                  overlay
                ]
              );

          hammerOverrides = lib.composeExtensions (uv2nix-hammer-overrides.overrides pkgs) extraOverrides;

          pythonSet = baseSet.pythonPkgsHostHost.overrideScope hammerOverrides;

          virtualenv = pythonSet.mkVirtualEnv "python-dev-env" workspace.deps.all;
        in
        baseShell
        // {
          packages = (baseShell.packages or [ ]) ++ [
            virtualenv
            pkgs.uv
          ];
          env = (baseShell.env or { }) // {
            UV_NO_SYNC = "1";
            UV_PYTHON = "${pythonSet.python.interpreter}";
            UV_PYTHON_DOWNLOADS = "never";
          };
          shellHook = (baseShell.shellHook or "") + ''
            unset PYTHONPATH
          '';
        };
    };
}
