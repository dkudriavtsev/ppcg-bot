with (import <nixpkgs> { overlays = [(self: super: { ruby = super.ruby_2_7; })]; config.allowUnfree = true; });
let
  env = bundlerEnv {
    name = "qbot-bundler-env";
    inherit ruby;
    gemfile  = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset   = ./gemset.nix;
    gemdir   = ./.;
    gemConfig = pkgs.defaultGemConfig // {
      nokogiri = attrs: {
        buildInputs = [ pkgconfig zlib.dev ];
      };
    };
  };
in stdenv.mkDerivation rec {
  name = "qbot";

  src = builtins.filterSource
    (path: type:
      type != "directory" ||
      baseNameOf path != "vendor" &&
      baseNameOf path != ".git" &&
      baseNameOf path != ".bundle")
    ./.;

  buildInputs = [
    env.wrappedRuby
    bundler bundix
    git
    sqlite libxml2 zlib.dev zlib libiconv
    libopus libsodium ffmpeg youtube-dl
  ];

  LD_LIBRARY_PATH = "${libsodium}/lib:${libopus}/lib";

  installPhase = ''
    mkdir -p $out/{bin,share/qbot}
    cp -r * $out/share/qbot
    bin=$out/bin/qbot

    cat >$bin <<EOF
#!/bin/sh -e
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}
cd $out/share/qbot
exec ${bundler}/bin/bundle exec ${ruby_2_7}/bin/ruby $out/share/qbot/qbot "\$@"
EOF

    chmod +x $bin
  '';
}
