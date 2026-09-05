{
  description = "CUDA development environment flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          cudaPackages.cudatoolkit
          cudaPackages.cuda_nvcc
          gcc
          gnumake
        ];

        shellHook = ''
          export CUDA_PATH=${pkgs.cudaPackages.cudatoolkit}
          export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib:$LD_LIBRARY_PATH
          
          echo "CUDA Environment Loaded."
          nvcc --version
          make --version
        '';
      };
    };
}