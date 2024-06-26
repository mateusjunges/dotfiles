alias reload!='. ~/.zshrc'

alias cls='clear'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.aliases, instead of adding them directly.

alias reloadcli='source $HOME/.zshrc'

#PHP artisan aliases:
alias controller='php artisan make:controller'
alias model='php artisan make:model'
alias test='php artisan test'
alias tf='php artisan test --filter'
alias pt='php artisan test --parallel'
alias fresh='php artisan migrate:fresh --seed'
alias pp='php please'

#Composer aliases:
alias dump-autoload='composer dump-autoload'
alias cr='composer require'

# PHPUnit
alias phpunit='./vendor/bin/phpunit'

# Pest
alias pest='./vendor/bin/pest'

# phpstan
alias phpstan='./vendor/bin/phpstan'

# Redis:
alias start-redis='redis-server'

# Copy
alias copy='xclip -sel clip'


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
