require_relative '../lib/twitterscour'
require 'pp'

my_tweets = TwitterScour.from_user('sowersb')
my_tweets.each {|t| pp t }
