{ rustPlatform, fetchFromGitLab, pkgs, stdenv }:

rustPlatform.buildRustPackage rec {
    name = "anup-${version}";
    version = "6062dfbef4d5c0f061b9f6e342acab54f34e089a";
    
    src = fetchFromGitLab {
      owner = "Acizza";
      repo = "anup";
      rev = "${version}";
      sha256 = "03l720ya9bqlww18x0ymswvrcbmpg0m8bx1ky13s3zfzynz0ss9a";
    };
    
    cargoSha256 = "0fsll5ainq5g0f7azlr8idij6q09hmiw25345rv9q105lm9jlh91";
    
    nativeBuildInputs = with pkgs; [ buildPackages.stdenv.cc pkgconfig ];
    buildInputs = with pkgs; [ openssl.dev xdg_utils ];

    postInstall = ''
      cp anup.sh $out/bin/anup.sh
    '';
    
    meta = with stdenv.lib; {
      license = licenses.asl20;
      platforms = platforms.linux;
    };
}
