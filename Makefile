.PHONY: up down logs run break reset
up:    ; docker compose up -d --build
down:  ; docker compose down -v
logs:  ; docker compose logs -f scheduler
run:   ; docker compose exec -T scheduler airflow dags trigger core_daily
break: ; ./scripts/break-core.sh
reset: ; ./scripts/reset-core.sh
