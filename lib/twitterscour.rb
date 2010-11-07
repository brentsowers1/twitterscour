require 'rubygems'
require 'nokogiri'
require 'httparty'
require File.dirname(__FILE__) + "/tweet"
require File.dirname(__FILE__) + "/tweet_location"
require 'json'

class TwitterScour
  # Currently, this is the number of tweets per page of results
  TWEETS_PER_PAGE = 20

  # Retrieves all tweets from the passed in username (no @ symbol)
  # - number_of_pages - By default, only up to 20 tweets (first page) will be
  #                     returned.  Specify more than one page here if you want
  #                     more than 20.  note that each page is a separate HTTP
  #                     request, so the higher the number of pages, the longer
  #                     the operation will take.
  # - fetch_location_info - By default, the location info will not be included,
  #                         because to retrieve location info takes another
  #                         HTTP request which can slow things down.  If you
  #                         want location set this to true
  def self.from_user(username, number_of_pages=1, fetch_location_info=false)
    rsp = HTTParty.get("http://twitter.com/#{username.gsub(/@/, "")}")
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
                    ll_sums = loc.bounding_box.inject([0,0]) {|sum, p| [sum[0] + p[0], sum[1] + p[1]]}
                    loc.center = [ll_sums[0] / loc.bounding_box.length, ll_sums[1] / loc.bounding_box.length]
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
      else
        break
      end
    end
    tweets
  end

  # Returns the most recent tweets that contain the search term passed in.  For
  # a hashtag search just send the hashtag in as the search term.  The default
  # is to return up to 20 results, if you want more, pass in a higher number of
  # pages.  Note that each page is a separate HTTP request, so the higher this
  # number, the longer the operation will take.
  # Note that tweets from a search will NOT have location info.  The only way
  # to get this is to do a from user search.
  def self.search_term(search_term, number_of_pages=1)
    search_url = "http://integratedsearch.twitter.com/search.html?_=#{Time.now.utc.to_i}000&q=#{search_term.gsub(/#/, "%23")}&rpp=20&maxId=null&locale=en&callback=processHomepageSearch&layout=none"
    rsp = HTTParty.get(search_url, :format => :html)
    raise Exception.new("Error code returned from Twitter - #{rsp.code}") if rsp.code != 200
    cur_page = 1
    tweets = []
    tweets_html = ""

    while rsp.code == 200
      if rsp.body =~ /^processHomepageSearch\("(.*)"\)$/
        tweets_html = $1
        # These escape sequences are used because Javascript is sent back, we
        # want to interpret it as HTML so get rid of them
        tweets_html.gsub!(/\\"/, "\"")
        tweets_html.gsub!(/\\t/, "")
        tweets_html.gsub!(/\\r/, "")
        tweets_html.gsub!(/\\n/, "")
      else
        raise Exception.new("Search results did not meet the expected format - #{rsp.body}")
      end

      page_body =  Nokogiri::HTML(tweets_html)
      new_tweets = page_body.css('li.result').collect do |tw|
        t = Tweet.new
        t.author_name = tw.css("a.username").first.text
        t.author_pic = tw.css("div.avatar img").first[:src]
        t.text = tw.css("span.msgtxt").text
        time_text = tw.css("div.info").text
        if time_text =~ /(about )?(\d+) (minute(s?)|hour(s?)|day(s?)) ago/
          num = $2.to_i
          if $3.include?("hour")
            num *= 60
          elsif $3.include?("day")
            num *= 1440
          end
          num *= 60  # 60 seconds in a minute
          t.time = Time.now - num
        end
        t
      end
      tweets = tweets.concat(new_tweets)
      cur_page += 1
      if new_tweets.length == TWEETS_PER_PAGE && cur_page <= number_of_pages
        url = search_url + "&page=#{cur_page}"
        rsp = HTTParty.get(url, :format => :html)
      else
        break
      end
    end
    tweets

  end
end

