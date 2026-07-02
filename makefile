.PHONY: build up down restart logs shell test migrate fresh optimize production

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

restart: down up

logs:
	docker-compose logs -f

shell:
	docker-compose exec app bash

test:
	docker-compose exec app php artisan test

migrate:
	docker-compose exec app php artisan migrate

fresh:
	docker-compose exec app php artisan migrate:fresh --seed

optimize:
	docker-compose exec app php artisan optimize

production:
	cp .env.ci .env
	composer install --no-dev --optimize-autoloader
	php artisan config:cache
	php artisan route:cache
	php artisan view:cache
	docker-compose -f docker-compose.yml up -d

key-generate:
	docker-compose exec app php artisan key:generate

deploy:
	git add .
	git commit -m "Deploy update"
	git push origin main