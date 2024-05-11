---
title: Setting up Dape for Emacs
description: It's better than dap-mode
pubDatetime: 2024-05-11T06:00:00Z
tags:
  - emacs
---

<details>
  <summary>What is dape?</summary>
  
  Dape allows you to run DAP compatible debuggers in emacs.  It's essentially a replacement for dap-mode.
  
  https://github.com/svaante/dape
</details>

I use Doom Emacs, so you'll see some Doom-isms.

Once you install and load the package, you're basically done. Dape has a fair amount of debuggers configured out of the box, and it maps its keybindings to `C-x C-a`.

```lisp
;; packages.el
(package! dape)

;; config.el
(use-package! dape)
```

Now when you run dape via `M-x dape` or `C-X C-a d`, you can type in the name of the debugger you want. You can find the names for all the debuggers using `describe-variables` and looking for `dape-configs`. I recommend searching for the mode you want to debug (ie. `go-mode`).

```lisp
;; Excerpt from dape-configs
 (dlv modes
      (go-mode go-ts-mode)
      ensure dape-ensure-command command "dlv" command-args
      ("dap" "--listen" "127.0.0.1::autoport")
      command-cwd dape-command-cwd port :autoport :request "launch" :type "debug" :cwd "." :program ".")
```

As we can see here, the name of the debugger is `dlv`. When we type that in, we can see the total set of options given to us by dape.

```
Run adapter: dlv

command-cwd "/var/home/digyx/Code/ric/"
:cwd "."
:program "."
```

We can change these args by setting them in the `Run adapter:` line.

```
Run adapter: dlv command-cwd "/var/uwu" :cwd "/var/home"

command-cwd "/var/uwu"
:cwd "/var/home"
:program "."
```

## Installing codelldb

Codelldb needs to be manually installing due to it actually being a VSCode plugin. Instructions are here.

https://github.com/svaante/dape?tab=readme-ov-file#c-c-and-rust---codelldb

If you use Doom Emacs, you'll need to extract the file under `~/.emacs.d/.local/cache/debug-adapters/codelldb/` instead of `~/.emacs.d/debug-adapters/codelldb/`.

## Keybindings

If you want map the keybindings to your leader key, this is my current configuration.

```lisp
(map! :map dap-mode-map
      :leader
      :prefix ("d" . "dap")
      :desc "dap hydra" "h" #'hydra-dap/body

      :desc "dap debug"   "s" #'dape
      :desc "dap quit"    "q" #'dape-quit
      :desc "dap restart" "r" #'dape-restart

      :desc "dap breakpoint toggle"     "b" #'dape-breakpoint-toggle
      :desc "dap breakpoint remove all" "B" #'dape-breakpoint-remove-all
      :desc "dap breakpoint log"        "l" #'dape-breakpoint-log

      :desc "dap continue" "c" #'dape-continue
      :desc "dap next"     "n" #'dape-next
      :desc "dap step in"  "i" #'dape-step-in
      :desc "dap step out" "o" #'dape-step-out

      :desc "dap eval" "e" #'dape-evaluate-expression)
```

And then the hydra:

```lisp
(require 'hydra)
(defhydra hydra-dap (:color pink :hint nil)
  "
^Dape Hydra^
------------------------------------------------
_n_: Next       _e_: Eval    _Q_: Disconnect
_i_: Step In
_o_: Step Out
_c_: Continue
_r_: Restart

"
  ("n" #'dape-next)
  ("i" #'dape-step-in)
  ("o" #'dape-step-out)
  ("c" #'dape-continue)
  ("e" #'dape-evaluate-expression)
  ("r" #'dape-restart)
  ("q" nil "Quit" :color blue)
  ("Q" #'dape-quit :color blue))
```
