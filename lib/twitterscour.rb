require 'rubygems'
require 'nokogiri'
require 'httparty'
require File.dirname(__FILE__) + "/tweet"
require File.dirname(__FILE__) + "/tweet_location"
require 'json'
require 'cgi'
require 'time'

# Fetches Tweet objects from twitter.com based on the parameters that you
# specify for your search
class TwitterScour
  # Currently, this is the number of tweets per page of results
  TWEETS_PER_PAGE = 20

  # Retrieves all tweets from the passed in username.  An array of Tweet objects
  # is returned.
  # - username - Twitter username to search from.  No @ symbol is necessary.
  # - number_of_pages - By default, only up to 20 tweets (first page) will be
  #   returned.  Specify more than one page here if you want more than 20.  Note
  #   that each page is a separate HTTP request, so the higher the number of
  #   pages, the longer the operation will take.
  # - fetch_location_info - By default, the location info will not be included,
  #   because to retrieve location info takes another HTTP request which can
  #   slow things down.  If you want location set this to true
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

  # Returns the most recent tweets that contain the search term passed in.  An
  # array of Tweet objects is returned.
  # - search_term - The term to search for.  For a hashtag search, just pass
  #   in the whole search including the hash symbol.
  # - number_of_pages - By default, only up to 15 tweets (first page) will be
  #   returned.  Specify more than one page here if you want more than 15.  Note
  #   that each page is a separate HTTP request, so the higher the number of
  #   pages, the longer the operation will take.
  # Note that tweets from a search will not have a full location. If a location
  # was attached, the center coordinates will be returned but no name or
  # polygon
  def self.search_term(search_term, number_of_pages=1)
    term = CGI.escape(search_term)
    url_base = "http://search.twitter.com/search.json"
    url = url_base + "?q=#{CGI.escape(search_term)}"
    rsp = HTTParty.get(url, :format => :json)
    raise Exception.new("Rate limit exceeded, slow down") if rsp.code == 420
    raise Exception.new("Error code returned from Twitter - #{rsp.code}") if rsp.code != 200
    cur_page = 1
    tweets = []
    tweets_html = ""
    results_per_page = 15

    while rsp.code == 200
      obj = JSON.parse(rsp.body)
      if (obj["error"])
        raise Exception.new("Got error from Twitter - " + obj["error"])
      end
      if obj["results_per_page"]
        results_per_page = obj["results_per_page"]
      end
      new_tweets = []
      obj["results"].each do |o|
        t = Tweet.new
        t.author_name = o["from_user"]
        t.author_pic = o["profile_image_url"]
        t.time = Time.parse(o["created_at"])
        t.text = o["text"]
        if o["geo"]
          if o["geo"]["type"] == "Point"
            loc = TweetLocation.new
            loc.center = [o["geo"]["coordinates"][1], o["geo"]["coordinates"][0]]
            t.location = loc
          end
        end
        new_tweets << t
      end
      tweets = tweets.concat(new_tweets)
      cur_page += 1
      if new_tweets.length == results_per_page && cur_page <= number_of_pages
        url = url_base + obj["next_page"]
        rsp = HTTParty.get(url, :format => :json)
      else
        break
      end
    end
    tweets

  end
end

