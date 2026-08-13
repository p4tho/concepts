{
  description = "Web3 Foundry Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";

    # Community flake tracking pre-compiled Foundry binaries (stable branch recommended)
    foundry.url = "github:shazow/foundry.nix/stable";
  };

  outputs = { self, nixpkgs, utils, foundry }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ foundry.overlay ];
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            foundry-bin
            solc
          ];
        };
      });
}
