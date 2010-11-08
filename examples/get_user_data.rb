#!/usr/bin/env ruby
require "rubygems"
require "twitterscour"
require 'pp'

my_tweets = TwitterScour.from_user('sowersb', 2, true)
my_tweets.each {|t| pp t }
