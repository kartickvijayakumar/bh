#!/bin/bash

set -vx

#bundle install

bundle exec rake db:migrate

rm -f tmp/pids/server.pid

bundle exec rails s -p 80 -b '0.0.0.0' &
bundle exec sidekiq 2>&1 >> log/sidekiq.log &

tail -f log/${RAILS_ENV}.log & tail -f log/sidekiq.log
