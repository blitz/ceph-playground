{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, rust-overlay }: {

    nixosConfigurations = {
      liveIso = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ pkgs, ... }: {
            boot.initrd.supportedFilesystems = [ "virtiofs" ];
            security.sudo.wheelNeedsPassword = false;
            
            # XXX Doesn't work?
            fileSystems."/myfs" = {
              device = "myfs";
              fsType = "virtiofs";
              options = [ "defaults" ];
            };
            
            environment.systemPackages = [
              (pkgs.writeShellScriptBin "mount-virtiofs" ''
                sudo mkdir -p /myfs
                sudo mount -t virtiofs myfs /myfs
                echo foo | sudo tee /myfs/foo
              '')
              
              pkgs.tmux
              pkgs.strace
              self.packages.x86_64-linux.virtiofs-test
            ];
          })
        ];
      };
    };

    # A statically linked virtiofsd.
    packages.x86_64-linux.virtiofsd = let
      system = "x86_64-linux";
      overlays = [ (import rust-overlay) ];

      pkgs = import nixpkgs {
        inherit system overlays;

        crossSystem = nixpkgs.lib.systems.examples.musl64 // {
          rust.rustcTarget = "x86_64-unknown-linux-musl";
          isStatic = true;
        };
      };
    in pkgs.callPackage ./virtiofsd.nix {};

    packages.x86_64-linux.liveIso = self.nixosConfigurations.liveIso.config.system.build.isoImage;
    packages.x86_64-linux.virtiofs-test = nixpkgs.legacyPackages.x86_64-linux.callPackage ./ceph-test.nix {};
    
    checks.x86_64-linux.ceph = nixpkgs.legacyPackages.x86_64-linux.nixosTest (import ./ceph.nix {
      liveIso = self.packages.x86_64-linux.liveIso;
    });
  };
}
