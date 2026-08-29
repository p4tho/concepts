{
  description = "A Nix-flake-based Rust development environment (Nightly) with embedded target support";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1"; # unstable Nixpkgs
    fenix = {
      url = "https://flakehub.com/f/nix-community/fenix/0.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, ... }@inputs:

    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                inputs.self.overlays.default
              ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        rustToolchain =
          let
            fenixPkgs = inputs.fenix.packages.${prev.stdenv.hostPlatform.system};
          in
          fenixPkgs.combine [
            (fenixPkgs.complete.withComponents [
              "cargo"
              "clippy"
              "rustc"
              "rustfmt"
              "rust-src"
              "llvm-tools-preview" # <-- Added here
            ])
            # Use .latest.rust-std (or .complete.rust-std) for the target standard library
            fenixPkgs.targets.thumbv7em-none-eabihf.latest.rust-std
          ];
      };

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              rustToolchain
              openssl
              pkg-config
              cargo-deny
              cargo-edit
              cargo-watch
              rust-analyzer

              cargo-bootimage
              qemu

              self.formatter.${system}
            ];

            env = {
              # Required by rust-analyzer
              RUST_SRC_PATH = "${pkgs.rustToolchain}/lib/rustlib/src/rust/library";
            };
          };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);
    };
}