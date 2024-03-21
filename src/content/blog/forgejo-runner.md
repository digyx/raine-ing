---
title: Self-Hosting a Forgejo Runner
description: Run a self-hosted Forgejo runner using docker-compose.
pubDatetime: 2024-03-20T09:29:11Z
tags:
  - forgejo
  - homelab
  - docker
---

[Codeberg](https://codeberg.org) hosts its own Woodpecker CI, but the software Codeberg runs, [Forgejo](https://forgejo.org/), has recently released its own variation on Github Actions.  While you are able to enable actions in Codeberg, they won't actually run, because Codeberg doesn't provide any runners (yet?).

Thankfully, it's relatively easy for one to self-host their own runner.  We'll focus exclusively on hosting a Docker runner, not an LXC or "self-hosted" runner.

# The Docker-Compose

Tldr; here's the `docker-compose.yml` file that I use.

```yaml
services:
  docker-in-docker:
    image: docker:dind
    privileged: true
    command: ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]

  runner-register:
    image: code.forgejo.org/forgejo/runner:3.3.0
    links:
      - docker-in-docker
    environment:
      DOCKER_HOST: tcp://docker-in-docker:2375
    volumes:
      - runner-data:/data
    user: 0:0
    command: >-
      bash -ec '
      if [ -f config.yml ]; then
        exit 0
      fi

      forgejo-runner register \
        --no-interactive \
        --name skadi-runner \
        --token $FORGEJO_TOKEN \
        --instance $FORGEJO_HOST;

      forgejo-runner generate-config > config.yml;
      chown -R 1000:1000 /data;
      '

  runner-daemon:
    image: code.forgejo.org/forgejo/runner:3.3.0
    restart: unless-stopped
    environment:
      DOCKER_HOST: "tcp://docker-in-docker:2375"
    env_file:
      - '.env'
    links:
      - docker-in-docker
    depends_on:
      runner-register:
        condition: service_completed_successfully
    volumes:
      - runner-data:/data
    command: "forgejo-runner --config config.yml daemon"

volumes:
  runner-data:

```

This `docker-compose.yml` file expects you to have a `.env` file similar to the following:

```dotenv
FORGEJO_HOST=https://codeberg.org
FORGEJO_TOKEN=<token>
```

You'll need to get your Forgejo Runner registration token using [this guide here](https://forgejo.org/docs/latest/admin/actions/#registration).  This token will be the `FORGEJO_TOKEN` in the `.env` file.

Once you have these two things, starting your runner should be as simple as running `docker-compose up -d`.

Now, let's go through each service individually.

## docker-in-docker

```yaml
  docker-in-docker:
    image: docker:dind
    privileged: true
    command: ["dockerd", "-H", "tcp://0.0.0.0:2375", "--tls=false"]
```

This little bit is responsible for actually executing containers.  Docker-in-docker creates a child container inside of itself rather than exposing the `docker.sock` on our host machine to the Forgejo Runner container.  In theory, this is more secure due to us not being forced to change the `docker.sock` permissions to `666`.  In practice...eh.  You already own the machine, host the runner container, and choose what code is ran on it.  Your Forgejo Runner can run without listening on any ports, so there's no reason to expose it to public internet traffic either.

## runner-register

```yaml
  runner-register:
    image: code.forgejo.org/forgejo/runner:3.3.0
    links:
      - docker-in-docker
    environment:
      DOCKER_HOST: tcp://docker-in-docker:2375
    volumes:
      - runner-data:/data
    user: 0:0
    command: >-
      bash -ec '
      if [ -f config.yml ]; then
        exit 0
      fi

      forgejo-runner register \
        --no-interactive \
        --name skadi-runner \
        --token $FORGEJO_TOKEN \
        --instance $FORGEJO_HOST;

      forgejo-runner generate-config > config.yml;
      chown -R 1000:1000 /data;
      '
```

This service is a oneshot that connects to our Forgejo (or Codeberg) instance and registers the runner using the environment variables.  Once it's done that, it will generate a config file that our `runner-daemon` can use.

The config file is saved to our `runner-data` volume.  If this file currently exists, then the `runner-register` will skip the registration.  Registering the same runner twice will create a duplicate runner on your account on your Forgejo Instance.

## runner-daemon

```yaml
  runner-daemon:
    image: code.forgejo.org/forgejo/runner:3.3.0
    restart: unless-stopped
    environment:
      DOCKER_HOST: "tcp://docker-in-docker:2375"
    env_file:
      - '.env'
    links:
      - docker-in-docker
    depends_on:
      runner-register:
        condition: service_completed_successfully
    volumes:
      - runner-data:/data
    command: "forgejo-runner --config config.yml daemon"
```

This is the Forgejo Runner itself.  Once it detects that `runner-register` has successfully completed, it will start up and wait for any actions to be triggered.

# Fin.

Overall, I've been quite happy with Codeberg.  The service is (relatively) stable, quick, and feature-full enough that I don't miss Github.  They are experiencing growing pains, but Codeberg over-communicates about every incident they've had, and I much prefer that the alternative.  I still self-host my own Forgejo instance for rough projects and my dotfiles, but my public repos are now all on Codeberg.

If you have any questions, feel free to message me on [Mastodon](https://mstdn.social/@godmaire)!
