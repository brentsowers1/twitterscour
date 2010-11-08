# Class representing the location of a tweet.
class TweetLocation
  # Text name for the location
  attr_accessor :place_name

  # Center point for the location, an array where first item is longitude,
  # second is latitude
  attr_accessor :center

  # If the location is an area, this is an array of coordinates (array where
  # first item is longitude, second latitude) for each point of the bounding
  # box for the area
  attr_accessor :bounding_box
end