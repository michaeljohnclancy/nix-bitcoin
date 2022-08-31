{ lib, fetchFromGitHub, rustPlatform, rustfmt, pkg-config, libiconv, darwin, stdenv, protobuf, perl}:

rustPlatform.buildRustPackage rec {
  pname = "rust-teos";
  version = "v0.1.1";

  src = fetchFromGitHub {
    owner = "talaia-labs";
    repo = pname;
    rev = version;
    sha256 = "sha256-6ayn8j2s5lYLIvCcSEo7pB3kLaUJdy3t84Ah+9Q5ezw=";
  };

  nativeBuildInputs = [
    protobuf 
    rustfmt
    perl
  ] ++ lib.optionals stdenv.isDarwin [ pkg-config libiconv ];

  buildInputs = lib.optionals stdenv.isDarwin [ 
    darwin.apple_sdk.frameworks.Security 
    darwin.apple_sdk.frameworks.SystemConfiguration 
  ];

  cargoPatches = [
    # Teos doesn't provide a Cargo.lock file with this release, so need to add it manually
    ./add-Cargo.lock.patch
  ];

  cargoHash = "sha256-b8h3dND9zMiH2BzpUNiPu39W5RuEEDhabBiIRY494n8=";

  meta = with lib; {
    description = "A Lightning watchtower compliant with BOLT13, written in Rust.";
    homepage = "https://github.com/talaia-labs/rust-teos";
    license = licenses.mit;
    maintainers = with maintainers; [ sr-gi ];
  };
}
