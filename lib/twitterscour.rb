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
    rsp = HTTParty.get("http://mobile.twitter.com/#{username.gsub(/@/, "")}")
    raise Exception.new("Error code returned from Twitter - #{rsp.code}") if rsp.code != 200
    locations = {}
    cur_page = 1
    tweets = []
    tweets_html = rsp.body
    pagination_html = rsp.body

    main_page = Nokogiri::HTML(rsp.body)

    while rsp.code == 200
      page_body =  Nokogiri::HTML(tweets_html)

      new_tweets = page_body.css('div.list-tweet').collect do |tw|
        t = Tweet.new
        links = tw.css("strong a")
        t.author_name = links[0].text
        t.text = tw.css("span.status").text
        # For some reason, time isn't in quotes in the JSON string which causes problems
        #t.time = Time.parse(tw.css("span.js-tweet-timestamp")[0][:"data-time"])
        time_text = tw.css("a.status_link").text
        if time_text =~ /(about )?(\d+) (minute(s?)|hour(s?)|day(s?)) ago.*/
          num = $2.to_i
          if $3.include?("hour")
            num *= 60
          elsif $3.include?("day")
            num *= 1440
          end
          num *= 60  # 60 seconds in a minute
          t.time = Time.now - num
        end
        if fetch_location_info && tw.css("img.geo-icon").length > 0
          link = tw.css("a.status_link")[0][:href]
          detailed_result = HTTParty.get("http://mobile.twitter.com#{link}")
          if detailed_result && detailed_result.code == 200 && detailed_result.body
            page = Nokogiri::HTML(detailed_result.body)
            tweet = page.css("div#tweets-list")[0]
            imgs = tweet.css("img")
            map = imgs.find {|i| i[:src] =~ /maps\.google\.com/}
            if map
              if map[:src] =~ /.*\|(\-?\d+\.?\d*),(\-?\d+\.?\d*).*/
                loc = TweetLocation.new
                loc.center = [$2.to_f, $1.to_f]
                t.location = loc
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
        next_link = pagination.css("a#more_link").first[:href]
        rsp = HTTParty.get("http://mobile.twitter.com/#{next_link}")
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

