require 'rubygems'
require 'nokogiri'
require 'httparty'
require File.dirname(__FILE__) + "/tweet"
require File.dirname(__FILE__) + "/tweet_location"
require 'json'

class TwitterScour
  TWEETS_PER_PAGE = 20

  def self.from_user(username, number_of_pages=1, fetch_location_info=false)
    rsp = HTTParty.get("http://twitter.com/#{username}")
    raise Exception.new("Error code returned from Twitter - #{rsp.code}") if rsp.code != 200
    locations = {}
    cur_page = 1
    tweets = []
    tweets_html = rsp.body
    pagination_html = rsp.body

    main_page = Nokogiri::HTML(rsp.body)
    authenticity_token = main_page.css("input#authenticity_token").first[:value]
    
    while rsp.code == 200
      page_body =  Nokogiri::HTML(tweets_html)

      new_tweets = page_body.css('li.status').collect do |tw|
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
          if place_id && fetch_location_info
            if locations[place_id]
              t.location = locations[place_id]
            else
              geo_result = HTTParty.get("http://twitter.com/1/geo/id/#{place_id}.json?authenticity_token=#{authenticity_token}&twttr=true")
              if geo_result && geo_result.code == 200 && geo_result.body &&
                 geo_result.body =~ /^\{.*/
                geo_data = JSON.parse(geo_result.body)
                if geo_data["geometry"] && geo_data["geometry"]["coordinates"]
                  loc = TweetLocation.new
                  loc.place_name = geo_data["name"]
                  if geo_data["geometry"]["type"] == "Point"
                    loc.center = geo_data["geometry"]["coordinates"]
                  elsif geo_data["geometry"]["type"] == "Polygon"
                    loc.bounding_box = geo_data["geometry"]["coordinates"].first
                  end
                  t.location = loc
                  locations[place_id] = loc
                end
              end
            end
          end
        end
        t
      end
      tweets = tweets.concat(new_tweets)
      cur_page += 1
      if new_tweets.length == TWEETS_PER_PAGE && cur_page <= number_of_pages
        pagination = Nokogiri::HTML(pagination_html)
        next_link = pagination.css("a#more").first[:href]
        unless next_link.include?("authenticity_token=")
          next_link << "&authenticity_token=#{authenticity_token}"
        end
        rsp = HTTParty.get("http://twitter.com/#{next_link}")
        pagination_html = rsp.body
        tweets_html = rsp.body
#        if rsp.code == 200 #&& rsp.body =~ /^\{.*/
#          result = JSON.parse(rsp.body)
#          pagination_html = result["#pagination"]
#          tweets_html = result["#timeline"]
#        end
      else
        break
      end
    end
    tweets
  end
end

