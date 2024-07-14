{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    checks.x86_64-linux.ceph = nixpkgs.legacyPackages.x86_64-linux.nixosTest ./ceph.nix;
  };
}
