# Robot fleet configuration

The task is described in [CHALLENGE.md](CHALLENGE.md). This README only covers the local setup.

## Prerequisites

Docker with Compose v2, Git and Make. On Windows, work inside WSL2 and clone the repository there.

## Setup

```sh
make up
```

This starts a local Gitea server with Gitea Actions and a runner, creates the repository in Gitea and pushes it there. The first run takes a few minutes. Then open http://localhost:3000 and log in as `candidate` with the password `candidate`.

## Remotes

After setup, `origin` is the local Gitea and `upstream` is where you cloned from. Push your work to `origin` and open pull requests in Gitea:

```sh
git push origin HEAD
```

## Example changes

The branches `change/telemetry-interval`, `change/customer-e-exposure` and `change/customer-b-release-upgrade` are example changes to try your workflow against. Rebase them onto your own work so your workflow runs on them, for example:

```sh
git switch -c change/telemetry-interval upstream/change/telemetry-interval
git rebase main
git push -f origin change/telemetry-interval
```

## Make targets

| Target | What it does |
| --- | --- |
| `make up` | Start everything and seed the repository. Safe to run again. |
| `make down` | Stop the containers and keep all data. |
| `make reset` | Delete Gitea and its data and start fresh. Your local clone is not touched. |
| `make status` | Show whether Gitea and the runner are up. |

## Troubleshooting

- **Port 3000 is already in use.** Stop whatever is listening on it (`lsof -i :3000` shows it), then run `make up` again.
- **The Docker socket is not available**, for example with Colima. First make `docker info` work in your shell (with Colima: `docker context use colima`). The runner mounts `/var/run/docker.sock` from the Docker VM; if your daemon's socket lives elsewhere, run `DOCKER_SOCKET=/path/to/docker.sock make up`.
- **The runner does not pick up jobs.** Run `make status` and `docker compose logs runner`. If the runner never registered, run `make reset`.
