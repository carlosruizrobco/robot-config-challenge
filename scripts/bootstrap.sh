#!/bin/sh
# Starts the local Gitea server and runner, seeds the repository and sets up
# the Git remotes. Safe to run repeatedly.
set -eu

cd "$(dirname "$0")/.."

GITEA_URL=http://localhost:3000
GITEA_USER=candidate
GITEA_PASSWORD=candidate
REPO_NAME=robot-config-challenge
REPO_PATH="$GITEA_USER/$REPO_NAME"
REMOTE_URL="http://$GITEA_USER:$GITEA_PASSWORD@localhost:3000/$REPO_PATH.git"
JOB_IMAGE=robot-config-job:1.0.0
MIN_COMPOSE_VERSION=2.23.1

changed=0

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
fail() { printf '\nError: %s\n' "$*" >&2; exit 1; }

gitea_cli() { docker compose exec -T -u git gitea gitea "$@"; }

# Calls the Gitea API from inside the gitea container, so no HTTP client is
# needed on the host. Prints the HTTP status code.
gitea_api() {
  method=$1 path=$2 body=${3:-}
  docker compose exec -T gitea curl -s -o /dev/null -w '%{http_code}' \
    -u "$GITEA_USER:$GITEA_PASSWORD" -X "$method" \
    -H 'Content-Type: application/json' ${body:+-d "$body"} \
    "http://localhost:3000/api/v1$path"
}

version_at_least() { # version_at_least HAVE WANT
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -t. -k1,1n -k2,2n -k3,3n | head -n1)" = "$2" ]
}

port_in_use() {
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -q '[:.]3000 '
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:3000 -sTCP:LISTEN >/dev/null 2>&1
  elif command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 3000 >/dev/null 2>&1
  else
    return 1
  fi
}

service_running() {
  docker compose ps --status running --services 2>/dev/null | grep -qx "$1"
}

# 1. Prerequisites
step "Checking prerequisites"
command -v docker >/dev/null 2>&1 || fail "Docker is not installed. Install Docker Desktop, OrbStack, Colima or Docker Engine."
docker info >/dev/null 2>&1 || fail "Docker is installed but not reachable. Start Docker, or check that DOCKER_HOST points at a running daemon."
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is not available. 'docker compose' must work (not only 'docker-compose')."
compose_version=$(docker compose version --short | sed 's/^v//')
version_at_least "$compose_version" "$MIN_COMPOSE_VERSION" \
  || fail "Docker Compose $compose_version is too old. Version $MIN_COMPOSE_VERSION or newer is needed."
command -v git >/dev/null 2>&1 || fail "Git is not installed."
command -v make >/dev/null 2>&1 || fail "Make is not installed."
git rev-parse --git-dir >/dev/null 2>&1 || fail "Run this from inside your clone of the repository."
if ! service_running gitea && port_in_use; then
  fail "Port 3000 is already in use. Stop whatever is listening on it and run 'make up' again."
fi
info "Docker, Docker Compose $compose_version, Git and Make are available"

# 2. Gitea
step "Starting Gitea"
if service_running gitea; then
  info "Gitea is already running"
else
  docker compose up -d --wait gitea
  changed=1
fi
info "Gitea is healthy at $GITEA_URL"

# 3. Admin user
step "Creating the user $GITEA_USER"
if gitea_cli admin user list --admin | awk 'NR > 1 { print $2 }' | grep -qx "$GITEA_USER"; then
  info "User $GITEA_USER already exists"
else
  gitea_cli admin user create --username "$GITEA_USER" --password "$GITEA_PASSWORD" \
    --email "$GITEA_USER@example.com" --admin --must-change-password=false >/dev/null
  info "Created user $GITEA_USER"
  changed=1
fi

# 4. Runner
step "Setting up the Actions runner"
if docker compose run --rm --no-deps -T --entrypoint test runner -f /data/.runner 2>/dev/null; then
  info "Runner is already registered"
else
  token=$(gitea_cli actions generate-runner-token | tr -d '\r' | tail -n1)
  [ -n "$token" ] || fail "Could not generate a runner registration token."
  printf 'RUNNER_REGISTRATION_TOKEN=%s\n' "$token" > .env
  info "Wrote a new runner registration token to .env"
  changed=1
fi
if docker image inspect "$JOB_IMAGE" >/dev/null 2>&1; then
  info "Job image $JOB_IMAGE already exists"
else
  info "Building the job image $JOB_IMAGE (first run only, takes a minute or two)"
  docker build -q -t "$JOB_IMAGE" runner >/dev/null
  changed=1
fi
if service_running runner; then
  info "Runner is already running"
else
  docker compose up -d runner
  changed=1
fi
tries=0
until docker compose exec -T runner test -f /data/.runner 2>/dev/null; do
  tries=$((tries + 1))
  [ "$tries" -le 60 ] || fail "The runner did not register within 60 seconds. Check 'docker compose logs runner'."
  sleep 1
done
info "Runner is registered"

# 5. Repository
step "Creating the repository $REPO_PATH"
status=$(gitea_api GET "/repos/$REPO_PATH")
if [ "$status" = 200 ]; then
  info "Repository already exists"
else
  status=$(gitea_api POST /user/repos "{\"name\":\"$REPO_NAME\",\"default_branch\":\"main\"}")
  [ "$status" = 201 ] || fail "Could not create the repository (HTTP $status)."
  info "Created $GITEA_URL/$REPO_PATH"
  changed=1
fi

# 6. Branches
step "Pushing branches to Gitea"
case "$(git remote get-url origin 2>/dev/null || true)" in
  *"localhost:3000/$REPO_PATH"*) source_remote=upstream ;;
  *) source_remote=origin ;;
esac
branches="main $(git for-each-ref --format='%(refname:lstrip=3)' "refs/remotes/$source_remote/change/")"
for branch in $branches; do
  if [ -n "$(git ls-remote --heads "$REMOTE_URL" "refs/heads/$branch")" ]; then
    info "$branch is already on Gitea"
    continue
  fi
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    ref="refs/heads/$branch"
  else
    ref="refs/remotes/$source_remote/$branch"
  fi
  git push -q "$REMOTE_URL" "$ref:refs/heads/$branch"
  info "Pushed $branch"
  changed=1
done

# 7. Remotes
step "Setting up Git remotes"
if [ "$source_remote" = upstream ]; then
  info "origin already points to Gitea"
else
  git remote rename origin upstream
  git remote add origin "$REMOTE_URL"
  git fetch -q origin
  if git show-ref --verify --quiet refs/heads/main; then
    git branch -q --set-upstream-to=origin/main main
  fi
  info "Renamed origin to upstream and added origin -> $GITEA_URL/$REPO_PATH"
  changed=1
fi

# 8. Summary
if [ "$changed" = 0 ]; then
  step "Everything is already set up"
else
  step "Setup complete"
fi
cat <<EOF

    Gitea:     $GITEA_URL/$REPO_PATH
    Username:  $GITEA_USER
    Password:  $GITEA_PASSWORD

    Next steps:
      1. Read CHALLENGE.md for the task.
      2. Commit your work and run 'git push origin HEAD'.
      3. Open a pull request in Gitea and watch the workflow under Actions.
EOF
