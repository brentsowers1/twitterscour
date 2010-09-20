require 'nokogiri'
require 'open-uri'
require './tweet'
require 'json'

class TwitterScour
  def self.from_user(username)
    main_page =  Nokogiri::HTML(open("http://twitter.com/#{username}"))
    main_page.css('li.status').collect do |tw|
      t = Tweet.new
      t.text = tw.css("span.entry-content").text
      t.time = Time.parse(tw.css("span.timestamp").first[:data].match(/\{time:'(.*)'\}/)[1])
      t
    end
  end
end

