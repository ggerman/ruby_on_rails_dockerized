#!/usr/bin/env bash

run_ruby_on_rails() {
    set -e
    if [ "$RAILS_ENV" != production ] && [ "$RAILS_ENV" != stage ]; then
    export $(cat .env | grep -v ^# | xargs)
    until PGPASSWORD=$POSTGRES_PASSWORD psql -h db -U "$POSTGRES_USER" -c '\l'; do
        sleep 1
    done
    fi

    cd /app
    rm -f tmp/pids/server.pid

    bundle install

    bundle exec rake db:create RAILS_ENV=$RAILS_ENV
    bundle exec rake db:migrate RAILS_ENV=$RAILS_ENV

    if [ "$RAILS_ENV" = "development" ]; then
    bundle exec foreman start -f Procfile.dev
    exec tail -f log/development.log
    else
    rake assets:precompile
    bundle exec puma -C config/puma.rb -d
    exec nginx -g 'daemon off;'
    fi
}

project_dir="."

if [ -f "$project_dir/Gemfile.lock" ] && grep -q "rails" "$project_dir/Gemfile.lock"; then
    run_ruby_on_rails
else
    rails new ruby_stack_news --database=postgresql
    rsync -a --ignore-existing ruby_stack_news/* .
    rm -rvf ruby_stack_news
    bundle add foreman
    echo "web: bin/rails server -p 3000 -b 0.0.0.0" > /app/Procfile.dev
    cp /app/tmp/database.yml /app/config/
    bundle install
    run_ruby_on_rails
fi

