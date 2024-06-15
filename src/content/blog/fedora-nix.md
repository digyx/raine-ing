---
title: Using Nix with Fedora's Immutable Distros
description: Yeah, I should probably just use NixOS.
pubDatetime: 2024-06-15T07:00:00
tags:
  - linux
  - nix
  - fedora
---

<small>_Disclaimer: This is my personal setup. It works well for me, but you might want to just use NixOS._</small>

## Table of Contents

## Installing Nix and Home Manager

I've come up with a script for installing Nix using the Determinate Installer. I love using this because _It Just Works_<sup>TM</sup> for Linux and MacOS.

```bash
#!/bin/sh
echo "Installing Nix..."
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

echo "Updating Nix Channels..."
nix-channel --add https://nixos.org/channels/nixpkgs-unstable
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update

echo "Installing Home Manager..."
nix-shell '<home-manager>' -A install
home-manager switch
```

This script:

1. Installs nix
2. Adds the [unstable channel](https://nixos.wiki/wiki/Nix_channels)
3. Adds the Home Manager channel
4. Updates all our channels
5. Installs home-manager
6. Activates home-manager

If you're not familiar with Home Manager, you'll want to follow [the official guide](https://nix-community.github.io/home-manager/index.xhtml#ch-usage).

## Multiple Machines

I use my nix config on my personal desktop, personal laptop, and my work laptop, but each one requires a slightly different config. To get around this, I have a single `common.nix` file then an individual nix file for each machine.

```bash
❯ ll .config/home-manager/
total 24K
-rw-r--r--. 1 godmaire godmaire  133 Apr  4 15:20 artemis.nix
-rw-r--r--. 1 godmaire godmaire 1.1K Apr  6 08:42 charles.nix
-rw-r--r--. 1 godmaire godmaire 2.6K Jun 15 10:37 common.nix
-rw-r--r--. 1 godmaire godmaire 5.0K May 14 18:04 diana.nix
```

If we take a peek inside `artemix.nix`, we can see how it imports `common.nix` and which settings it needs.

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./common.nix ];

  home.username = "godmaire";
  home.homeDirectory = "/var/home/godmaire";
}
```

To actually use this config on Artemis, we can symlink it to `home.nix`.

```bash
❯ ll .config/home-manager/home.nix
lrwxrwxrwx. 1 godmaire godmaire 9 Apr  4 15:19 .config/home-manager/home.nix -> artemis.nix
```

The only things we need to set in `artemis.nix` or any other machine specific file are the `home.username` and `home.homeDirectory`. Everything else is in `common.nix`. For my work machine, which runs MacOS, I have a few other customizations.

```nix
{ config, lib, pkgs, ... }:

{
  imports = [ ./common.nix ];

  home.username = "rgodmaire";
  home.homeDirectory = "/Users/rgodmaire";

  # Overrides
  programs.emacs.package = lib.mkForce pkgs.emacs-macport;

  home.packages = with pkgs; [
    go
    gopls
    delve
    gotests
    gotools

    python3
    pyright
    ruff

    shellcheck
  ];

  programs.alacritty = {
      enable = true;
      settings = {
          font = {
              normal.family = "Hack Nerd Font Mono";
              size = 12.0;
            };

          colors = {
              primary = {
                  background = "#282828";
                  foreground = "#ebdbb2";
                };

              normal = {
                black   = "#282828";
                red     = "#cc241d";
                green   = "#98971a";
                yellow  = "#d79921";
                blue    = "#458588";
                magenta = "#b16286";
                cyan    = "#689d6a";
                white   = "#ebdbb2";
                };
            };
        };
    };

}
```

The interesting things here are the additional packages, alacritty, and the different package for emacs. We use `lib.mkForce` to overwrite the existing setting in `common.nix`. Everything else, such as `home.packages` merges with `common.nix`.

## Why Not Use NixOS?

I started using Feodra Silverblue before I started using Nix. By the time I started entertaining the idea of using NixOS, I already had this setup. Either way, I'd need to have most of this in place due to me being forced to use a Macbook for work (Linux was banned 😢).
