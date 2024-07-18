{ stdenv, meson, ninja }:
stdenv.mkDerivation {
  name = "virtiofs-test";
  src = ./test;
  buildInputs = [ meson ninja ];
}
