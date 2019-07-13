#PHP artisan aliases:
alias pas='php artisan serve --host=junges'
alias pa='php artisan'

#Apache 2 aliases
alias start-apache2='sudo service apache2 start'
alias stop-apache2='sudo service apache2 stop'
alias restart-apache2='sudo service apache2 restart'

#Mysql aliases:
alias start-mysql='sudo service mysql start'
alias stop-mysql='sudo service mysql stop'
alias restart-mysql='sudo service mysql restart'

#Postgresql aliases:
alias start-pgsql='sudo service postgresql start'
alias stop-pgsql='sudo service postgresql stop'
alias restart-pgsql='sudo service postgresql restart'
alias pgadmin4='. ~/Programs/pgAdmin4/pgAdmin4/bin/activate; python ~/Programs/pgAdmin4/pgAdmin4/lib/python2.7/site-packages/pgadmin4/pgAdmin4.py'
#VPN aliases:
alias vpn-uepg='sudo openvpn --config /etc/openvpn/uepg.ovpn --auth-user-pass /etc/openvpn/auth.conf'

#Composer aliases:
alias new-laravel='composer create-project --prefer-dist laravel/laravel'
alias dump-autoload='composer dump-autoload'
alias cr='composer require'

#Git aliases:
alias gs='git status'
alias gc='git commit -m'
alias ga='git add'
alias gpush='git push origin'
alias gpull='git pull origin'
alias checkout='git checkout'


# Scilab:
alias scilab='cd /opt/scilab; ./bin/scilab'

#Redis:
alias start-redis='redis-server'

# PHPUnit
alias phpunit='./vendor/bin/phpunit'
