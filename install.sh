#!/bin/bash
# this is a goofy hack; will move to Rake soon

bundle install
gem=`bundle exec gem build cfnpp.gemspec |grep File | sed -e 's/.*File: *//'`
bundle exec gem install $gem
