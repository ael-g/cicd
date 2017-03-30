all: up

clean: down

up: up-ci up-monitoring up-front

down: down-ci down-monitoring down-front

up-ci:
	docker stack up -c ci.yml ci

up-monitoring:
	docker stack up -c monitoring.yml monitoring

up-front:
	docker stack up -c front.yml front

down-ci:
	docker stack down ci

down-monitoring:
	docker stack down monitoring

down-front:
	docker stack down front
