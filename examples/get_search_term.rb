#!/usr/bin/env ruby
require "./" + File.dirname(__FILE__) + "/../lib/twitterscour"
require 'pp'

my_tweets = TwitterScour.search_term('#Rails', 1)
my_tweets.each {|t| pp t }
