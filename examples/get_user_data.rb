#!/usr/bin/env ruby
require "./" + File.dirname(__FILE__) + "/../lib/twitterscour"
require 'pp'

my_tweets = TwitterScour.from_user('sowersb')
my_tweets.each {|t| pp t }
