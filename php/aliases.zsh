#PHP artisan aliases:
alias php='valet php'
alias pas='php artisan serve'
alias pa='php artisan'
alias a='php artisan'
alias controller='php artisan make:controller'
alias model='php artisan make:model'
alias art='docker compose exec app php artisan'
alias test='php artisan test'
alias tf='php artisan test --filter'
alias pt='php artisan test --parallel'
alias fresh='php artisan migrate:fresh --seed'

#Composer aliases:
alias dump-autoload='composer dump-autoload'
alias cr='composer require'

# phpstan
alias phpstan='./vendor/bin/phpstan'

# PhpStorm
alias phpstorm="/Applications/PhpStorm.app/Contents/MacOS/phpstorm ."

# PHPUnit
alias phpunit='./vendor/bin/phpunit'

alias init="composer install && yarn install && cp .env.example .env && php artisan key:generate"