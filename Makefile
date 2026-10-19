.PHONY: up down reset status

## up: start Gitea and the runner, and seed the repository
up:
	@sh scripts/bootstrap.sh

## down: stop the containers and keep all data
down:
	@docker compose down

## reset: delete Gitea and its data, then run 'up' again
reset:
	@printf 'This deletes the Gitea server and everything pushed to it. Your local clone is not touched. Continue? [y/N] '; \
	read answer; case "$$answer" in [yY]*) ;; *) echo "Aborted."; exit 1 ;; esac
	@docker compose down --volumes --remove-orphans
	@$(MAKE) --no-print-directory up

## status: show whether Gitea and the runner are up
status:
	@if [ -z "$$(docker compose ps --all --quiet)" ]; then \
	  echo "Gitea and the runner are not running. Start them with 'make up'."; \
	else \
	  docker compose ps --all --format 'table {{.Service}}\t{{.State}}\t{{.Status}}'; \
	fi
