#!/usr/bin/env ruby
require "rubygems"
require "twitterscour"
require 'pp'

my_tweets = TwitterScour.search_term('#Ruby', 3)
my_tweets.each {|t| pp t }
