---
title: "Packaging Elixir Applications"
description: How to release Elixir apps
pubDatetime: 2023-02-15T00:00:00Z
modDatetime: 2023-03-26T00:00:00Z

tags:
  - programming
  - elixir
  - docker

---

Working with elixir can feel euphoric when you're in the zone.  The BEAM VM being built around fault tolerance and inter-process communication that's exposed to you via abstractions such as `GenServer` and `Task`, which are pleasent to work with, means that errors are not more uncommon (such as in Rust) but they shoot you in the foot just as infrequently because a `Supervisor` will just restart your application instead of throwing itself off a cliff.

With all that said, most existing documentation aimed at beginners is for _starting_ a project in Elixir while very few are for packing it for deployment (unless you're using `phoenix`).  Digging into the documentation for `mix release` can feel daunting, so here's my attempt at explaining how to package an Elixir application with Docker.

The code for this project can be found on [Github](https://github.com/digyx/sydney).

# Drinking the FP Koolaid

We'll be building a simple web server, configuring it as an application, and then going through the process of `mix release` before delving into the land of docker.  Skip to whichever section you'd like, but there's no harm in reading top-to-bottom.

## Building a Simple Web Server

Let's start a new project:

``` console
➜  mix new sydney
* creating README.md
* creating .formatter.exs
* creating .gitignore
* creating mix.exs
* creating lib
* creating lib/sydney.ex
* creating test
* creating test/test_helper.exs
* creating test/sydney_test.exs

Your Mix project was created successfully.
You can use "mix" to compile it, test it, and more:

    cd sydney
    mix test

Run "mix help" for more commands
```

To make it an actual application, we'll define a webserver using [plug](https://hexdocs.pm/plug/readme.html).  We'll need to add it to our `mix.exs` file as a dependancy first.

``` elixir
# mix.exs

defmodule Sydney.MixProject do
  use Mix.Project

  def project do
    [
      app: :sydney,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.0"}
    ]
  end
end
```

Now we're able to actually write a simple web server.

``` elixir
# lib/sydney/server.ex

defmodule Sydney.Server do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> send_resp(200, "Ok")
  end

  match _ do
    conn
    |> send_resp(404, "Page not found")
  end

  def start_link(_) do
    Plug.Adapters.Cowboy.http(Server, [])
  end
end
```

It's not much, sure, but it'll do for our purposes.  Fancier things could require non-Elixir dependencies such as Discord bots using `ffmpeg` for audio transcoding, but at that point you know what you're getting yourself into.  Thankfully, the Elixir/Erlang community seems to shy away from cross-language contamination, but not nerely as bad as [golang is with cgo](https://karthikkaranth.me/blog/calling-c-code-from-go/).

## application.ex

Let's make an simple `application.ex` file to define Sydney.  This can be considered the entrypoint of our program, but in reality it's more of a top-level overview of how our application if structured.  Things such as an `Ecto.Repo` process for managing the database connection or a `Phoenix.PubSub` process would be defined here.

We'll use a `Supervisor` watch over Sydney's server and restart it on a crash.

``` elixir
# lib/sydney/application.ex

defmodule Sydney.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: Sydney.Server, options: [port: 8080]}
    ]

    opts = [
      strategy: :one_for_one,
      name: Sydney.Supervisor
    ]

    Supervisor.start_link(children, opts)
  end
end
```

Now we can add `Sydney.Application` to the function `application/0` in `mix.exs` under the `mod` key.  This specifies which module will be invoked when the application starts up.

``` elixir
  # mix.exs:14-20

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Sydney.Application, []},
      extra_applications: [:logger]
    ]
  end
```

To sanity check ourselves, let's check to see if Sydney works.

``` console
➜  mix deps.get
Resolving Hex dependencies...
Dependency resolution completed:
New:
  cowboy 2.9.0
  cowboy_telemetry 0.4.0
  cowlib 2.11.0
  mime 2.0.3
  plug 1.14.0
  plug_cowboy 2.6.0
  plug_crypto 1.2.3
  ranch 1.8.0
  telemetry 1.2.1
* Getting plug_cowboy (Hex package)
* Getting cowboy (Hex package)
* Getting cowboy_telemetry (Hex package)
* Getting plug (Hex package)
* Getting mime (Hex package)
* Getting plug_crypto (Hex package)
* Getting telemetry (Hex package)
* Getting cowlib (Hex package)
* Getting ranch (Hex package)
You have added/upgraded packages you could sponsor, run `mix hex.sponsor` to learn more
➜  mix run --no-halt
==> mime
Compiling 1 file (.ex)
Generated mime app
===> Analyzing applications...
===> Compiling telemetry
==> plug_crypto
Compiling 5 files (.ex)
Generated plug_crypto app
===> Analyzing applications...
===> Compiling ranch
==> plug
Compiling 1 file (.erl)
Compiling 41 files (.ex)
Generated plug app
===> Analyzing applications...
===> Compiling cowlib
===> Analyzing applications...
===> Compiling cowboy
===> Analyzing applications...
===> Compiling cowboy_telemetry
==> plug_cowboy
Compiling 5 files (.ex)
Generated plug_cowboy app
==> sydney
Compiling 3 files (.ex)
Generated sydney app

```

There's no output saying that our application is running, but we can test it pretty easily.

``` console
➜  curl http://localhost:8080/
Ok
```

Looks good to me!

## mix release

`mix release` is the command used to package and release an Elixir application.  The docs are [here](https://hexdocs.pm/mix/main/Mix.Tasks.Release.html), but it can be a long read.  I'll summarize the absolute necessities below.

We'll start by defining the release options in the `project/0` function within our `mix.exs` file.

``` elixir
# mix.exs:
  def project do
    [
      app: :sydney,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      
      # --- This is new ---
      releases: [
        sydney: [
          include_executables_for: [:unix]
        ]
      ]
    ]
  end
```

This is actually the only required option.  There are [a ton of other settings](https://hexdocs.pm/mix/main/Mix.Tasks.Release.html#module-options), which you should definitely look into, but none of them are required.  Actually, `include_executables_for` is also not required, but most elixir applications run on unix-based operating systems, so there's no reason to build a windows version.

Here are the most useful settings, in my opinion:
- `:steps` to build a `.tar.gz` artifact.
- `:strip_beams` for a smaller release by stripping debug info.
- `:path` to set where the build output path.
- `:overlays` more on them [here](https://hexdocs.pm/mix/main/Mix.Tasks.Release.html#module-overlays).

Once we have everything set, building the application is as simple as running `mix release sydney`.

``` console
➜  mix release sydney
Generated sydney app
* assembling sydney-0.1.0 on MIX_ENV=dev
* skipping runtime configuration (config/runtime.exs not found)

Release created at _build/dev/rel/sydney

    # To start your system
    _build/dev/rel/sydney/bin/sydney start

Once the release is running:

    # To connect to it remotely
    _build/dev/rel/sydney/bin/sydney remote

    # To stop it gracefully (you may also send SIGINT/SIGTERM)
    _build/dev/rel/sydney/bin/sydney stop

To list all commands:

    _build/dev/rel/sydney/bin/sydney

```

As you can see, the built application is located at `_build/dev/rel/sydney/bin/sydney`.  If you build with `MIX_ENV=prod` then the base path will be `_build/prod` instead of `_build/dev`.

Let's follow the directions and list all commands.

``` console
➜  _build/dev/rel/sydney/bin/sydney
Usage: sydney COMMAND [ARGS]

The known commands are:

    start          Starts the system
    start_iex      Starts the system with IEx attached
    daemon         Starts the system as a daemon
    daemon_iex     Starts the system as a daemon with IEx attached
    eval "EXPR"    Executes the given expression on a new, non-booted system
    rpc "EXPR"     Executes the given expression remotely on the running system
    remote         Connects to the running system via a remote shell
    restart        Restarts the running system via a remote command
    stop           Stops the running system via a remote command
    pid            Prints the operating system PID of the running system via a remote command
    version        Prints the release name and version to be booted
```

It works!  Let's take a look at `bin/sydney` and see how big the binary is.

``` console
➜  ls -lh _build/dev/rel/sydney/bin/sydney
-rwxr-xr-x 1 digyx digyx 5.2K Feb 15 10:00 _build/dev/rel/sydney/bin/sydney*
```

That's...tiny.  That can't be everything, right?  Let's take a look at the file.

``` shell
#!/bin/sh
set -e

SELF=$(readlink "$0" || true)
if [ -z "$SELF" ]; then SELF="$0"; fi
RELEASE_ROOT="$(CDPATH='' cd "$(dirname "$SELF")/.." && pwd -P)"
export RELEASE_ROOT
RELEASE_NAME="${RELEASE_NAME:-"sydney"}"
export RELEASE_NAME
RELEASE_VSN="${RELEASE_VSN:-"$(cut -d' ' -f2 "$RELEASE_ROOT/releases/start_erl.data")"}"
export RELEASE_VSN
RELEASE_COMMAND="$1"
export RELEASE_COMMAND
RELEASE_PROG="${RELEASE_PROG:-"$(echo "$0" | sed 's/.*\///')"}"
export RELEASE_PROG

REL_VSN_DIR="$RELEASE_ROOT/releases/$RELEASE_VSN"
. "$REL_VSN_DIR/env.sh"

RELEASE_COOKIE="${RELEASE_COOKIE:-"$(cat "$RELEASE_ROOT/releases/COOKIE")"}"
export RELEASE_COOKIE
RELEASE_MODE="${RELEASE_MODE:-"embedded"}"
export RELEASE_MODE
RELEASE_NODE="${RELEASE_NODE:-"$RELEASE_NAME"}"
export RELEASE_NODE
RELEASE_TMP="${RELEASE_TMP:-"$RELEASE_ROOT/tmp"}"
export RELEASE_TMP
RELEASE_VM_ARGS="${RELEASE_VM_ARGS:-"$REL_VSN_DIR/vm.args"}"
export RELEASE_VM_ARGS
RELEASE_REMOTE_VM_ARGS="${RELEASE_REMOTE_VM_ARGS:-"$REL_VSN_DIR/remote.vm.args"}"
export RELEASE_REMOTE_VM_ARGS
RELEASE_DISTRIBUTION="${RELEASE_DISTRIBUTION:-"sname"}"
export RELEASE_DISTRIBUTION
RELEASE_BOOT_SCRIPT="${RELEASE_BOOT_SCRIPT:-"start"}"
export RELEASE_BOOT_SCRIPT
RELEASE_BOOT_SCRIPT_CLEAN="${RELEASE_BOOT_SCRIPT_CLEAN:-"start_clean"}"
export RELEASE_BOOT_SCRIPT_CLEAN

rand () {
  dd count=1 bs=2 if=/dev/urandom 2> /dev/null | od -x | awk 'NR==1{print $2}'
}

release_distribution () {
  case $RELEASE_DISTRIBUTION in
    none)
      ;;

    name | sname)
      echo "--$RELEASE_DISTRIBUTION $1"
      ;;

    *)
      echo "ERROR: Expected sname, name, or none in RELEASE_DISTRIBUTION, got: $RELEASE_DISTRIBUTION" >&2
      exit 1
      ;;
  esac
}

rpc () {
  exec "$REL_VSN_DIR/elixir" \
       --hidden --cookie "$RELEASE_COOKIE" \
       $(release_distribution "rpc-$(rand)-$RELEASE_NODE") \
       --boot "$REL_VSN_DIR/$RELEASE_BOOT_SCRIPT_CLEAN" \
       --boot-var RELEASE_LIB "$RELEASE_ROOT/lib" \
       --vm-args "$RELEASE_REMOTE_VM_ARGS" \
       --rpc-eval "$RELEASE_NODE" "$1"
}

start () {
  export_release_sys_config
  REL_EXEC="$1"
  shift
  exec "$REL_VSN_DIR/$REL_EXEC" \
       --cookie "$RELEASE_COOKIE" \
       $(release_distribution "$RELEASE_NODE") \
       --erl "-mode $RELEASE_MODE" \
       --erl-config "$RELEASE_SYS_CONFIG" \
       --boot "$REL_VSN_DIR/$RELEASE_BOOT_SCRIPT" \
       --boot-var RELEASE_LIB "$RELEASE_ROOT/lib" \
       --vm-args "$RELEASE_VM_ARGS" "$@"
}

export_release_sys_config () {
  DEFAULT_SYS_CONFIG="${RELEASE_SYS_CONFIG:-"$REL_VSN_DIR/sys"}"

  if grep -q "RUNTIME_CONFIG=true" "$DEFAULT_SYS_CONFIG.config"; then
    RELEASE_SYS_CONFIG="$RELEASE_TMP/$RELEASE_NAME-$RELEASE_VSN-$(date +%Y%m%d%H%M%S)-$(rand).runtime"

    (mkdir -p "$RELEASE_TMP" && cat "$DEFAULT_SYS_CONFIG.config" >"$RELEASE_SYS_CONFIG.config") || (
      echo "ERROR: Cannot start release because it could not write $RELEASE_SYS_CONFIG.config" >&2
      exit 1
    )
  else
    RELEASE_SYS_CONFIG="$DEFAULT_SYS_CONFIG"
  fi

  export RELEASE_SYS_CONFIG
}

case $1 in
  start)
    start "elixir" --no-halt
    ;;

  start_iex)
    start "iex" --werl
    ;;

  daemon)
    start "elixir" --no-halt --pipe-to "${RELEASE_TMP}/pipe" "${RELEASE_TMP}/log"
    ;;

  daemon_iex)
    start "iex" --pipe-to "${RELEASE_TMP}/pipe" "${RELEASE_TMP}/log"
    ;;

  eval)
    if [ -z "$2" ]; then
      echo "ERROR: EVAL expects an expression as argument" >&2
      exit 1
    fi

    export_release_sys_config
    exec "$REL_VSN_DIR/elixir" \
       --cookie "$RELEASE_COOKIE" \
       --erl-config "$RELEASE_SYS_CONFIG" \
       --boot "$REL_VSN_DIR/$RELEASE_BOOT_SCRIPT_CLEAN" \
       --boot-var RELEASE_LIB "$RELEASE_ROOT/lib" \
       --vm-args "$RELEASE_VM_ARGS" --eval "$2"
    ;;

  remote)
    exec "$REL_VSN_DIR/iex" \
         --werl --hidden --cookie "$RELEASE_COOKIE" \
         $(release_distribution "rem-$(rand)-$RELEASE_NODE") \
         --boot "$REL_VSN_DIR/$RELEASE_BOOT_SCRIPT_CLEAN" \
         --boot-var RELEASE_LIB "$RELEASE_ROOT/lib" \
         --vm-args "$RELEASE_REMOTE_VM_ARGS" \
         --remsh "$RELEASE_NODE"
    ;;

  rpc)
    if [ -z "$2" ]; then
      echo "ERROR: RPC expects an expression as argument" >&2
      exit 1
    fi
    rpc "$2"
    ;;

  restart|stop)
    rpc "System.$1()"
    ;;

  pid)
    rpc "IO.puts System.pid()"
    ;;

  version)
    echo "$RELEASE_NAME $RELEASE_VSN"
    ;;

  *)
    echo "Usage: $(basename "$0") COMMAND [ARGS]

The known commands are:

    start          Starts the system
    start_iex      Starts the system with IEx attached
    daemon         Starts the system as a daemon
    daemon_iex     Starts the system as a daemon with IEx attached
    eval \"EXPR\"    Executes the given expression on a new, non-booted system
    rpc \"EXPR\"     Executes the given expression remotely on the running system
    remote         Connects to the running system via a remote shell
    restart        Restarts the running system via a remote command
    stop           Stops the running system via a remote command
    pid            Prints the operating system PID of the running system via a remote command
    version        Prints the release name and version to be booted
" >&2

    if [ -n "$1" ]; then
      echo "ERROR: Unknown command $1" >&2
      exit 1
    fi
    ;;
esac
```

Ohhhhh so it's just a launch script.  Makes sense.  Actually how many other files are there?  How big are they in total?

``` console
➜  du -sh _build/dev/rel/sydney/
16M     _build/dev/rel/sydney/
➜  find _build/dev/rel/sydney -type f | wc -l
874
```

WOW.  That's a lot of files.  Total size isn't bad, though.

Unlike other languages such as Go and Rust, Elixir compiles for the BEAM virtual machine, which is to Erlang what the JVM is to Java.  Taking a look at the file tree of `_build/dev/rel/sydney`, we can see a bunch of individual files.  Unlike the JVM, Elixir actually bundles the runtime with the application.  This means the machine we're running the application on doesn't need Elixir to be installed.

``` console
➜  docker run -it \
      --volume "$PWD/_build/dev/rel/sydney:/opt/sydney" \
      -p 8080:8080 \
      ubuntu /bin/bash
root@29f14932efe3:/# /opt/sydney/bin/sydney start
warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)
```

Ubuntu doesn't run `utf8` by default?  Huh, alright.  Welp, that doesn't matter to us right now, so we'll ignore it.

``` console
➜  curl http://localhost:8080/
Ok
```

Fantastic!

### Caveaught

Now, this doesn't mean Sydney is infinitely portable.  She still has some dependencies, just ones that are more "reasonable".  For example, the following doesn't work.

``` console
➜  docker run -it \
      --volume "$PWD/_build/dev/rel/sydney:/opt/sydney" \
      -p 8080:8080 \
      debian:latest /bin/bash
root@e138865fb957:/# /opt/sydney/bin/sydney start
/opt/sydney/erts-13.1.3/bin/erlexec: /lib/x86_64-linux-gnu/libc.so.6: version `GLIBC_2.34' not found (required by /opt/sydney/erts-13.1.3/bin/erlexec)
```

And we can see why by checking our `glibc` versions.

``` console
➜  ldd --version
ldd (GNU libc) 2.37
Copyright (C) 2023 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
Written by Roland McGrath and Ulrich Drepper.
➜  docker run -it debian:latest /bin/bash
root@031ee395c38d:/# ldd --version
ldd (Debian GLIBC 2.31-13+deb11u5) 2.31
Copyright (C) 2020 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
Written by Roland McGrath and Ulrich Drepper.
```

My Arch Linux installation has `glibc 2.37` while the debian images only have `glibc 2.31`.  We can solve this issue by simply building the application in a docker container with a lower `glibc` version and then moving the artifacts to another container so...

# Docker Time

Let's start with a simple, impossible to mess up configuration.

``` dockerfile
FROM elixir:latest

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

ENTRYPOINT ["/opt/sydney/bin/sydney"]
CMD ["start"]
```

As a note, you'll want to copy over your `config/` file and anything else necessary for the project to build.  We don't want to do a `COPY . .` for two reason:

1. We could accidentally copy our own `_build` folder over, which is totally not something that gave me multiple days worth of headaches and;

2. This will slow down our build by reducing the amount we can cache since any change to any file would require Docker to fully rebuild or dependencies instead of just our application.

Anyway, let's build the thing.

``` console
➜  docker build -t sydney .
[+] Building 37.6s (15/15) FINISHED
 => [internal] load build definition from Dockerfile                                           0.0s
 => => transferring dockerfile: 480B                                                           0.0s
 => [internal] load .dockerignore                                                              0.0s
 => => transferring context: 2B                                                                0.0s
 => [internal] load metadata for docker.io/library/elixir:latest                               0.1s
 => [internal] load metadata for docker.io/library/elixir:slim                                 0.2s
 => [build_stage 1/6] FROM docker.io/library/elixir:latest@sha256:6b43caee72c7d30e338cfd1419  19.4s
 => => resolve docker.io/library/elixir:latest@sha256:6b43caee72c7d30e338cfd14193162f981bf9c4  0.0s
 => => sha256:6b43caee72c7d30e338cfd14193162f981bf9c47aa6ea6226424ab7e8ab67bb 1.42kB / 1.42kB  0.0s
 => => sha256:c3aa11fbc85a2a9660c98cfb4d0a2db8cde983ce3c87565c356cfdf1ddf26 10.88MB / 10.88MB  0.5s
 => => sha256:2c9304afafd20dc07418015142cd316b6a09b09a4e1d7d9e41af25ebaa331ec 2.22kB / 2.22kB  0.0s
 => => sha256:7770942456a46c17a6d4d4744c2830c8e4e5c628e6b620c46388759b81e91de 8.81kB / 8.81kB  0.0s
 => => sha256:6c1024729feeb2893dad43684fe7679c4d866c3640dfc3912bbd93c5a51f32d 5.17MB / 5.17MB  0.3s
 => => sha256:aa54add66b3a47555c8b761f60b15f818236cc928109a30032111efc98c6f 54.59MB / 54.59MB  5.7s
 => => extracting sha256:6c1024729feeb2893dad43684fe7679c4d866c3640dfc3912bbd93c5a51f32d2      0.1s
 => => sha256:9e3a60c2bce7eed21ed40f067f9b3491ae3e0b7a6edbc8ed5d9dc7dd9e4 196.90MB / 196.90MB  5.9s
 => => sha256:e3b7d942a0e149a7bea9423d528d6eb3feab43c98aa1dfe76411f722e12 243.12MB / 243.12MB  8.2s
 => => extracting sha256:c3aa11fbc85a2a9660c98cfb4d0a2db8cde983ce3c87565c356cfdf1ddf2654c      0.2s
 => => extracting sha256:aa54add66b3a47555c8b761f60b15f818236cc928109a30032111efc98c6fcd4      1.6s
 => => sha256:a575a6735350a64d448af63013b1e6a8d2a8ee41c2718c0e22501828961 198.62kB / 198.62kB  5.9s
 => => sha256:59db57e4c8acbbdbf667b31b8fd4713e2a4fac33afd9593c843bae0641c 988.28kB / 988.28kB  6.0s
 => => sha256:6a6fa9498b870a0b0a4f2b9d9f5ff584bbba599c281c0172a9b2fdfc7ee8cf0 6.20MB / 6.20MB  6.5s
 => => extracting sha256:9e3a60c2bce7eed21ed40f067f9b3491ae3e0b7a6edbc8ed5d9dc7dd9e4a0f92      5.0s
 => => extracting sha256:e3b7d942a0e149a7bea9423d528d6eb3feab43c98aa1dfe76411f722e122f5bb      6.0s
 => => extracting sha256:a575a6735350a64d448af63013b1e6a8d2a8ee41c2718c0e2250182896136621      0.0s
 => => extracting sha256:59db57e4c8acbbdbf667b31b8fd4713e2a4fac33afd9593c843bae0641cb8d33      0.0s
 => => extracting sha256:6a6fa9498b870a0b0a4f2b9d9f5ff584bbba599c281c0172a9b2fdfc7ee8cf06      0.1s
 => [stage-1 1/3] FROM docker.io/library/elixir:slim@sha256:c9db6016833b2ffa57a5a37276215c8d  10.4s
 => => resolve docker.io/library/elixir:slim@sha256:c9db6016833b2ffa57a5a37276215c8dcbf13f996  0.0s
 => => sha256:c9db6016833b2ffa57a5a37276215c8dcbf13f9967679490d65f4e2c8131d4b 1.41kB / 1.41kB  0.0s
 => => sha256:7bb623d2806f43d77c1cbe68489a1737714a6682d13d54f7e41be37c8972fdf6 952B / 952B     0.0s
 => => sha256:96a79f0cd42af47aa8ec2495afbad867d02c0edddc3b7521a4fd55cb6028e2d 5.96kB / 5.96kB  0.0s
 => => sha256:121475a6527dd0c5a079a61159de0ec80f0befe4d5e2e733eb06b6ba826ea 65.93MB / 65.93MB  8.4s
 => => sha256:7fa7197cb3fda651dcd6412d3c61de5ba2cff3d71969bf11a76d0508c966455 6.70MB / 6.70MB  7.3s
 => => extracting sha256:121475a6527dd0c5a079a61159de0ec80f0befe4d5e2e733eb06b6ba826ea8f8      1.6s
 => => extracting sha256:7fa7197cb3fda651dcd6412d3c61de5ba2cff3d71969bf11a76d0508c966455a      0.2s
 => [internal] load build context                                                              0.0s
 => => transferring context: 228B                                                              0.0s
 => [stage-1 2/3] WORKDIR /opt/sydney                                                          0.0s
 => [build_stage 2/6] WORKDIR /opt/build                                                       0.0s
 => [build_stage 3/6] COPY mix.* ./                                                            0.0s
 => [build_stage 4/6] RUN mix local.hex --force &&   mix local.rebar --force &&   mix deps.g  16.0s
 => [build_stage 5/6] COPY lib ./lib                                                           0.0s
 => [build_stage 6/6] RUN mix release sydney                                                   1.4s
 => [stage-1 3/3] COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney        0.1s
 => exporting to image                                                                         0.4s
 => => exporting layers                                                                        0.4s
 => => writing image sha256:3fd48d8431e482766324ebdd8d0271ab2da79339e704d37ea725a6136e5414bc   0.0s
 => => naming to docker.io/library/sydney                                                      0.0s
```

Sheesh, I forgot how verbose docker can be.  From now on, we'll be passing the `--quiet` flag to make this more readable.

Anyway, let's try running the thing.

``` console
➜  docker run -p 8080:8080 sydney

```

Okay, no output, but we expect that.  Let's test it using `curl`.

``` console
➜  curl http://localhost:8080/
Ok
➜  curl http://localhost:8080/404
Page not found
```

Whoot!

Out of curiosity, how big is the container?

``` console
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED         SIZE
sydney       latest    92b52ae16b4c   15 seconds ago   1.6GB
```

...  Oh no...

## Miniturization

Let's start with the low hanging fruit:  slim images.

``` dockerfile
FROM elixir:slim

# The rest is the same
```

``` console
➜  docker build --quiet --tag sydney .
sha256:fdb4ea030f3a2984bdc5260d910eae2bd6a8e01a7359e930173f47ff5128e2cc
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
sydney       latest    fdb4ea030f3a   18 seconds ago   430MB
```

Better, but still unacceptable.  What if we use build stages?

For those unfamiliar, build stages allow us to build our artifacts in one container before copying them to another container.  This means our final image will only have runtime dependencies instead of build time and runtime dependencies.

``` dockerfile
FROM elixir:latest AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

FROM debian:bullseye-slim

WORKDIR /opt/sydney
COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

ENTRYPOINT ["/opt/sydney/bin/sydney"]
CMD ["start"]
```

``` console
➜  docker build --quiet --tag sydney .
sha256:9b2438ea418100d02d83a97fc9b74026c8adff001e1af0d1d089ae4f1cd29413
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED              SIZE
sydney       latest    1e6e55f851f0   About a minute ago   145MB
```

Another 3x improvement is great, but those will stop happening eventually.  We also get out good ol' friend `latin1` by using `debian:bullseye-slim` instead of `elixir:slim`.

``` console
➜  docker run -p 8080:8080 sydney
warning: the VM is running with native name encoding of latin1 which may cause Elixir to malfunction as it expects utf8. Please ensure your locale is set to UTF-8 (which can be verified by running "locale" in your shell)

```

Our next, and most drastic, step is switching to `alpine` images.  Those never cause issues.

``` dockerfile
FROM elixir:alpine AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

FROM alpine:latest

WORKDIR /opt/sydney
COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

ENTRYPOINT ["/opt/sydney/bin/sydney"]
CMD ["start"]
```

Okay, does it work?

``` console
➜  docker run -p 8080:8080 sydney
Error loading shared library libncursesw.so.6: No such file or directory (needed by /opt/sydney/erts-13.1.4/bin/beam.smp)
Error loading shared library libstdc++.so.6: No such file or directory (needed by /opt/sydney/erts-13.1.4/bin/beam.smp)
Error loading shared library libgcc_s.so.1: No such file or directory (needed by /opt/sydney/erts-13.1.4/bin/beam.smp)
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE10_M_replaceEmmPKcm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __cxa_begin_catch: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: tgetflag: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _Znwm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt20__throw_length_errorPKc: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __cxa_guard_release: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNKSt8__detail20_Prime_rehash_policy11_M_next_bktEm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __popcountdi2: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: tgetent: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt20__throw_out_of_rangePKc: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt17__throw_bad_allocv: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_appendEPKcm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE9_M_createERmm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: tputs: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructEmc: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __cxa_end_catch: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __cxa_guard_acquire: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNKSt8__detail20_Prime_rehash_policy14_M_need_rehashEmmm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt19__throw_logic_errorPKc: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: tgetnum: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt28__throw_bad_array_new_lengthv: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: pthread_getname_np: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE7reserveEm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: tgetstr: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __cxa_rethrow: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _Unwind_Resume: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZdlPvm: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv120__si_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv117__class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: _ZTVN10__cxxabiv121__vmi_class_type_infoE: symbol not found
Error relocating /opt/sydney/erts-13.1.4/bin/beam.smp: __gxx_personality_v0: symbol not found
```

Shit.

What about just using `elixir:alpine` as our final stage?  Yeah, sure, we won't save nerely as much, but it should be something...right?

``` dockerfile
...

COPY lib ./lib
RUN mix release sydney

# --- New image! ---
FROM elixir:alpine

WORKDIR /opt/sydney
COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

...
```

``` console
➜  docker build --quiet --tag sydney .
sha256:a6feb6fd7139c71a71a57c47127ba33a07abcd2d551e6df8af86930c66b4a50e
➜  docker run -p 8080:8080 sydney

```

``` console
➜  curl http://localhost:8080/
Ok
```

Okay, good, it works.  How big is it?

``` console
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
sydney       latest    a6feb6fd7139   14 seconds ago   96.1MB
```

Under 100mb, that's good!  We can still do better.  If we look through the error logs when using the `alpine:latest` image, we can see that we're missing a few libraries.  Let's add the following:

``` dockerfile
...

FROM alpine:3.16

WORKDIR /opt/sydney
# --- Let's install some runtime deps ---
RUN apk add \
    --update \
    --no-cache \
    openssl ncurses libstdc++
COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

...
```

``` console
➜  docker build --quiet --tag sydney .
sha256:67e05f2fcbad23bb00eabe90a520555beea423353031be687f4b87c3b930546b
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
sydney       latest    67e05f2fcbad   20 seconds ago   23.5MB
```

And there we have it!  Going from 1.6GB to 23.5MB feels pretty good.

Note:  we must use `alpine:3.16` because that's what `erlang:alpine` uses which is what `elixir:alpine` is based on ([click the alpine tag to see the image's dockerfile](https://hub.docker.com/_/erlang/)).  If we don't, we run into issues linking `libcrypto.so.1.1`, but this will _probably_ be resolved eventually.  Either way, always check what `erlang:alpine` is based on first.  That will guarantee compatibility...probably.

### Technically...

We can go further.  I mentioned earlier that adding `:tar` to the `:steps` section of your `releases` section in `mix.exs` will also produce a `.tar.gz` archive.  Well, that archive is about half the size.

``` elixir
  def project do
    [
      app: :sydney,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        sydney: [
          include_executables_for: [:unix],
          # --- This is new! ---
          steps: [:assemble, :tar]
        ]
      ]
    ]
  end
```

``` console
➜  mix release sydney --overwrite --quiet
* skipping runtime configuration (config/runtime.exs not found)
➜  ll _build/dev/sydney-0.1.0.tar.gz 
-rw-r--r-- 1 digyx digyx 6.9M Feb 15 16:42 _build/dev/sydney-0.1.0.tar.gz
```

This means we can instead ship a `.tar.gz` in the container and then decompress it before running.  As you can imagine, this is excessive, so...

``` dockerfile
# tar.Dockerfile
FROM elixir:alpine AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

FROM alpine:3.16

RUN apk add \
    --update \
    --no-cache \
    openssl ncurses libstdc++

WORKDIR /opt/sydney
COPY entrypoint.sh entrypoint.sh
RUN chmod +x entrypoint.sh
COPY --from=build_stage /opt/build/_build/prod/sydney-0.1.0.tar.gz sydney-0.1.0.tar.gz

CMD ["/opt/sydney/entrypoint.sh"]
```

``` sh
#!/usr/bin/env sh
# entrypoint.sh

tar -xzf /opt/sydney/sydney-0.1.0.tar.gz
/opt/sydney/bin/sydney start
```

``` console
➜  docker build --quiet --tag sydney --file Dockerfile_tar .
sha256:858056ca2956d73e9ab8d477df8f309c681cd17e37288ebe156efe73225a7a41
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED              SIZE
sydney       latest    858056ca2956   About a minute ago   16.1MB
```

Wow, that entire docker container is smaller than our uncompressed code.  Of course, this is a very niche extreme that you should _not_ try to emulate.

## Full Dockerfile

``` dockerfile
# Dockerflile
FROM elixir:alpine AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

FROM alpine:3.16

WORKDIR /opt/sydney
RUN apk add \
    --update \
    --no-cache \
    openssl ncurses libstdc++
COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

ENTRYPOINT ["/opt/sydney/bin/sydney"]
CMD ["start"]
```

# Distroless?

_sigh_

``` dockerfile
FROM elixir:latest AS build_stage

# Config
ENV MIX_ENV prod
WORKDIR /opt/build

# Dependendies
COPY mix.* ./

RUN mix local.hex --force && \
  mix local.rebar --force && \
  mix deps.get --only prod && \
  mix deps.compile

# Build project
COPY lib ./lib
RUN mix release sydney

FROM gcr.io/distroless/base

COPY --from=build_stage /opt/build/_build/prod/rel/sydney /opt/sydney

ENTRYPOINT ["/opt/sydney/bin/sydney"]
CMD ["start"]
```

``` console
➜  docker build --quiet --tag sydney .
sha256:99ba5748d07947241ad86f35a83800e7bd34ec5c47e38716858a15e1e869711a
➜  docker images sydney
REPOSITORY   TAG       IMAGE ID       CREATED          SIZE
sydney       latest    99ba5748d079   33 seconds ago   84.9MB
➜  docker run -p 8080:8080 sydney
exec /opt/sydney/bin/sydney: no such file or directory
```

Not only is it larger, but it also just doesn't run.  My guess is the wrong glibc version or another runtime dep not being there, but the image uses `debian11` as a base (aka. bullseye), so that doesn't seem to be it.  I'm honestly not sure what's wrong, and, imo, it's not worth it to figure it out.  Just use alpine.
