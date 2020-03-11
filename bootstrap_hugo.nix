let

  # See https://nixos.wiki/wiki/FAQ/Pinning_Nixpkgs for more information on pinning
  nixpkgs = builtins.fetchTarball {
    # Descriptive name to make the store path easier to identify
    name = "nixpkgs-2020.03-2020.03.11";
    # Commit hash for nixos-20.03 as of 2020.03.1
    url = https://github.com/NixOS/nixpkgs/archive/dbacfa172f9a6399f180bcd0aef7998fdec0d55a.tar.gz;
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "19xfl22gr6w198dphji37p9gzmlphk8aymldnm1vz7bpcgzila8z";
  };

in

{ pkgs ? import nixpkgs {} }:

with pkgs;

let

  hugo-theme-terminal = runCommand "hugo-theme-terminal" {
    pinned = builtins.fetchTarball {
      # Descriptive name to make the store path easier to identify
      name = "hugo-theme-terminal-2019-02-25";
      # Commit hash for hugo-theme-terminal as of 2019-02-25
      url = https://github.com/panr/hugo-theme-terminal/archive/487876daf1ebdf389f03a2dfdf6923cea5258e6e.tar.gz;
      # Hash obtained using `nix-prefetch-url --unpack <url>`
      sha256 = "17gvqml1wl14gc0szk1kjxi0ya995bmpqqfcwn9jgqf3gdx316av";
    };

    patches = [];

    preferLocalBuild = true;
  }
  ''
    cp -r $pinned $out
    chmod -R u+w $out

    for p in $patches; do
      echo "Applying patch $p"
      patch -d $out -p1 < "$p"
    done
  '';

in

mkShell {
  buildInputs = [
    hugo
  ];

  shellHook = ''
    mkdir -p themes
    ln -snf "${hugo-theme-terminal}" themes/hugo-theme-terminal
  '';
}
