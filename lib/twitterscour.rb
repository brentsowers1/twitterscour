require 'rubygems'
require 'nokogiri'
require 'httparty'
require File.dirname(__FILE__) + "/tweet"
require File.dirname(__FILE__) + "/tweet_location"
require 'json'

class TwitterScour
  def self.from_user(username, number_of_pages=1, fetch_location_info=false)
    rsp = HTTParty.get("http://twitter.com/#{username}")
    raise Exception.new("Error code returned from Twitter - #{rsp.code}") if rsp.code != 200
    main_page =  Nokogiri::HTML(rsp.body)
    main_page.css('li.status').collect do |tw|
      t = Tweet.new
      if tw[:class] =~ /.* u\-(.*?) .*/
        t.author_name = $1
      end
      t.text = tw.css("span.entry-content").text
      # For some reason, time isn't in quotes in the JSON string which causes problems
      t.time = Time.parse(tw.css("span.timestamp").first[:data].match(/\{time:'(.*)'\}/)[1])
      meta_data_str = tw.css("span.entry-meta").first[:data]
      if meta_data_str.length > 2
        meta_data = JSON.parse(meta_data_str)
        t.author_pic = meta_data["avatar_url"]
        place_id = meta_data["place_id"]
        token = main_page.css("input#authenticity_token").first[:value]
        if place_id && fetch_location_info
          geo_data_str = HTTParty.get("http://twitter.com/1/geo/id/#{place_id}.json?authenticity_token=#{token}&twttr=true").body
          geo_data = JSON.parse(geo_data_str)
          if geo_data["geometry"] && geo_data["geometry"]["coordinates"]
            loc = TweetLocation.new
            loc.place_name = geo_data["name"]
            if geo_data["geometry"]["type"] == "Point"
              loc.center = geo_data["geometry"]["coordinates"]
            elsif geo_data["geometry"]["type"] == "Polygon"
              loc.bounding_box = geo_data["geometry"]["coordinates"].first
            end
            t.location = loc
          end
        end
      end
      t
    end
  end
end

