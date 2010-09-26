class Tweet
  # Name of the author of this tweet, without the @ symbol.
  # If the tweet was a straight retweet without any added text, this is the original author.
  attr_accessor :author_name

  # URL for the author's picture
  attr_accessor :author_pic

  # The full text of the tweet
  attr_accessor :text

  # A TweetLocation instance containing the location of the tweet, if the tweet has a location
  attr_accessor :location

  # Ruby Time for when this tweet was published
  attr_accessor :time

end

