# Valet aliases
alias php='valet php'
alias composer='valet composer'

#PHP artisan aliases:
alias pas='valet php artisan serve'
alias pa='valet php artisan'
alias a='valet php artisan'
alias controller='valet php artisan make:controller'
alias model='valet php artisan make:model'
alias art='docker compose exec app php artisan'
alias test='valet php artisan test'
alias tf='valet php artisan test --filter'
alias pt='valet php artisan test --parallel'
alias fresh='valet php artisan migrate:fresh --seed'
alias cl="rm storage/logs/laravel.log && touch storage/logs/laravel.log"

#Composer aliases:
alias dump-autoload='composer dump-autoload'
alias cr='composer require'

# phpstan
alias phpstan='./vendor/bin/phpstan'

# PhpStorm
alias phpstorm="/Applications/PhpStorm.app/Contents/MacOS/phpstorm ."

# PHPUnit
alias phpunit='./vendor/bin/phpunit'

alias init="composer install && npm install && cp .env.example .env && php artisan key:generate"
