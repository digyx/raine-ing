{ pkgs, ... }:

{
  packages = with pkgs; [
    git

    nodejs
    nodePackages.pnpm
    nodePackages.typescript
    nodePackages.typescript-language-server
  ];

  scripts.server.exec = ''
    pnpm install
    pnpm dev
  '';

  languages.javascript.enable = true;
  languages.typescript.enable = true;
}
