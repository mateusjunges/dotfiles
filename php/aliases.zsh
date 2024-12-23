# herd aliases
alias php='herd php'
alias composer='herd composer'

#PHP artisan aliases:
alias pas='herd php artisan serve'
alias pa='herd php artisan'
alias a='herd php artisan'
alias controller='herd php artisan make:controller'
alias model='herd php artisan make:model'
alias art='docker compose exec app php artisan'
alias test='herd php artisan test'
alias tf='herd php artisan test --filter'
alias pt='herd php artisan test --parallel'
alias fresh='herd php artisan migrate:fresh --seed'
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
