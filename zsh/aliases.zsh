alias reload!='. ~/.zshrc'

alias cls='clear'

# Alias definitions.
# You may want to put all your additions into a separete file like
# ~/.aliases, instead of adding them directly.

alias reloadcli='source $HOME/.zshrc'

# Apache 2 aliases
alias start-apache2='sudo service apache2 start'
alias stop-apache2='sudo service apache2 stop'
alias restart-apache2='sudo service apache2 restart'

#PHP artisan aliases:
alias pas='php artisan serve'
alias pa='php artisan'
alias a='php artisan'
alias controller='php artisan make:controller'
alias model='php artisan make:model'
alias art='docker compose exec app php artisan'
alias test='php artisan test'
alias tf='php artisan test --filter'

#Composer aliases:
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

# Docker 
alias dc='docker compose'
alias dce='docker compose exec'

# Copy
alias copy='xclip -sel clip'

# PhpStorm
alias phpstorm="/Applications/PhpStorm.app/Contents/MacOS/phpstorm ."

# Tighten
alias precommit="./vendor/bin/duster fix && ./vendor/bin/duster lint && ./vendor/bin/phpstan && ./vendor/bin/phpunit --exclude-testsuite Integration"


# determine versions of PHP installed with HomeBrew
installedPhpVersions=($(brew ls --versions | ggrep -E 'php(@.*)?\s' | ggrep -oP '(?<=\s)\d\.\d' | uniq | sort))

# create alias for every version of PHP installed with HomeBrew
for phpVersion in ${installedPhpVersions[*]}; do
    value="{"

    for otherPhpVersion in ${installedPhpVersions[*]}; do
        if [ "${otherPhpVersion}" = "${phpVersion}" ]; then
            continue;
        fi

        value="${value} brew unlink php@${otherPhpVersion};"
    done

    value="${value} brew link php@${phpVersion} --force --overwrite; } &> /dev/null && php -v"

    alias "${phpVersion}"="${value}"
done
