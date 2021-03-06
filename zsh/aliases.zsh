alias reload!='. ~/.zshrc'

alias cls='clear'

# Alias definitions.
# You may want to put all your additions into a separete file like
# ~/.aliases, instead of adding them directly.

alias reloadcli='soruce $HOME/.zshrc'

# Apache 2 aliases
alias start-apache2='sudo service apache2 start'
alias stop-apache2='sudo service apache2 stop'
alias restart-apache2='sudo service apache2 restart'

#PHP artisan aliases:
alias pas='php artisan serve --host=junges'
alias pa='php artisan'
alias controller='php artisan make:controller'
alias model='php artisan make:model'

#Composer aliases:
alias new-laravel='composer create-project --prefer-dist laravel/laravel'
alias dump-autoload='composer dump-autoload'
alias cr='composer require'

# Mysql aliases:
alias start-mysql='sudo service mysql start'
alias stop-mysql='sudo service mysql stop'
alias restart-mysql='sudo service mysql restart'

# PHPUnit
alias phpunit='./vendor/bin/phpunit'

# Postgresql aliases:
alias start-pgsql='sudo service postgresql start'
alias stop-pgsql='sudo service postgresql stop'
alias restart-pgsql='sudo service postgresql restart'
alias pgadmin4='. ~/Programs/pgAdmin4/pgAdmin4/bin/activate; python ~/Programs/pgAdmin4/pgAdmin4/lib/python2.7/site-packages/pgadmin4/pgAdmin4.py'

# Redis:
alias start-redis='redis-server'
