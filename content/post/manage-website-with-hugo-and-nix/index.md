---
title: "Manage a static website with Hugo and Nix"
date: 2019-02-26T17:21:56-08:00
tags:
  - nix
  - hugo
description: "We use Nix, a reproducible package manager, to provide a
fixed environment with Hugo and the Hugo theme we want to use. This
method does not require us to copy the theme into our repository or to
add it as a submodule."
highlight: true
---

This blog is based on the original work found under
https://kalbas.it/2019/02/26/manage-a-static-website-with-hugo-and-nix/

This blog post describes how to create a sample host site with hugo
in a reproducible environment regardless of the host.

<!--more-->

# Installing Nix

If you'd like to follow along this tutorial, then you should have
installed [Nix](https://nixos.org/nix/) on your system.

Nix can be installed by following the instructions
[here](https://nixos.org/nix/download.html). At the time of writing this
guide, Nix can be installed by simply running `curl
https://nixos.org/nix/install | sh` as a non-root user.

Please note that if you would like to uninstall nix, simply remove the
directory `/nix`.

# Reproducible environment

## I just want to see a simple example page

If you're in a hurry and just want to run this example website.

Once you have nix and git installed the following sequence of commands should suffice

```
git clone https://github.com/ngiger/hugo-nix-example.git
cd hugo-nix-example
nix-shell bootstrap_hugo.nix
nix-shell nix-shell --command "hugo server" # will read the shell.nix file and execute the command hugo server

```

Now enter in your browser the URL http://localhost:1313 and you should see

![alt text](static/img/local_hugo.png "Logo Title Text 1")

Photo from https://en.wikipedia.org/wiki/John_Doe#/media/File:John_and_Jane_Doe_Headstones.jpp (Public Domain)

## Adapting to your needs

Beware that when whenever you changed a *.nix file. You must stop the hugo server (Ctrl-C), leave the nix shell and call `nix-shell nix-shell --command "hugo server"` again.
when you change text elsewhere, eg. content/post/another-blog.md you should see the changed output almost immediately.

# Describing the environment

To achieve reproducibility, we're going to rely on the awesome command
by Nix named `nix-shell`.  This command allows you to create a shell
environment given a list of packages and shell hooks. Go ahead, try it
with `nix-shell -p hello`; This should give you a shell with a modified
`PATH` giving you access to the command `hello`.

{{< highlight console >}}
# -f <nixpkgs> is not a required argument, but it's good to know about it
$ nix-shell -f '<nixpkgs>' -p hello
$ hello
Hello, world!
$ EOF                   # Ctrl-D
$ hello
hello: command not found
{{< /highlight >}}

One can simply run `nix-shell -p hugo` to install and use Hugo. Using
nix-shell like that has some limitations:

- There's no guarentee that the same version of Hugo is going to be
  used. Unless you specify `-I nixpkgs=/path/to/fixed/nixpkgs`.
- There's no way to write shell hooks to setup the theme at the correct
  place.

These limitations can be avoided by expressing the desired environment
in a Nix expression, automatically loaded by nix-shell. Create a file
named `shell.nix` at the root of your website with the following
contents:

{{< code file="/content/post/manage-website-with-hugo-and-nix/shell.nix" language="nix" >}}

Now, simply run `nix-shell` to get access to Hugo version 0.54. You
should also find the theme symlinked at `themes/hugo-theme-terminal` to
a path in `/nix/store/...`.

## Understanding the shell nix expression

Let's break the `shell.nix` into multiple pieces, so we can address them
separately. But before we dive in, keep in mind the following:

- shell.nix is expected to be a Nix expression returning a derivation.
- A derivation is a description of building something from other stuff.
- A Nix expression is a function. Functions in Nix follow the following format
  `arg: body` when in this case the arg is expected to be a set such as
  `{ pkgs }: body`.

So the expected barebones shell.nix should actually look like:

{{< highlight nix >}}
{ pkgs ? import <nixpkgs> {} }:

with pkgs;

mkShell {
  buildInputs = [
    hugo
  ];
}
{{< /highlight >}}

The `?` operator seen in `pkgs ? import <nixpkgs> {}` above specifies the
default value of the pkgs argument.

Now, let's talk about the first part of the script.

{{< highlight nix >}}
  # See https://nixos.wiki/wiki/FAQ/Pinning_Nixpkgs for more information on pinning
  nixpkgs = builtins.fetchTarball {
    # Descriptive name to make the store path easier to identify
    name = "nixpkgs-unstable-2019-02-26";
    # Commit hash for nixos-unstable as of 2019-02-26
    url = https://github.com/NixOS/nixpkgs/archive/2e23d727d640f0a96b167d105157f6e7183d8f82.tar.gz;
    # Hash obtained using `nix-prefetch-url --unpack <url>`
    sha256 = "15s7qjw4qm8mbimiv5fcg0nlgpx4gsws2kbx8z1qzqrid8jg76f8";
  };
{{< /highlight >}}

The above code block is defining a variable named `nixpkgs` to a
function call `builtins.fetchTarball` with one argument: the set that is
defining the `name`, `url` and the `sha256`. Nix is a lazy language, so
nixpkgs will remain a function until it's actually invoked! Once
invoked, the function will get evaluated and the return value is simply
a path on your filesystem within the nix store.

{{< highlight nix >}}
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
{{< /highlight >}}

Much like the first section, this one is defining the variable
`hugo-theme-terminal` to resolve to a simple derivation that provides
the hugo theme. Notice that I did not say **install** the theme, as the
`runCommand` barely downloads the theme and extracts it into a path that
gets returned and assigned to `hugo-theme-terminal`.

{{< highlight nix >}}
mkShell {
  buildInputs = [
    hugo
  ];

  shellHook = ''
    mkdir -p themes
    ln -snf "${hugo-theme-terminal}" themes/hugo-theme-terminal
  '';
}
{{< /highlight >}}

And finally, we get to the shell declaration itself. `mkShell` is a
function that returns a derivation, a derivation that can only be used
with `nix-shell` but cannot be built with `nix-build`.

The `shellHook` is a bash script that gets invoked within the same
folder where the `shell.nix` is located. I'm using this shellHook here
to create the themes folder and to symlink the theme we created earlier
with the `runCommand` to `themes/hugo-theme-terminal`.
