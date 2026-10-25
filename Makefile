.DEFAULT_GOAL := start

.PHONY: start stop logs test check

start:
	docker compose up --build

stop:
	docker compose down

logs:
	docker compose logs -f

test:
	docker compose run --rm app mix test

check:
	docker compose config --quiet
	docker compose run --rm app mix precommit
