class TweetLocation
  # Text name for the location
  attr_accessor :place_name

  # Center point for the location, an array where first item is latitude,
  # second is longitude
  attr_accessor :center

  # If the location is an area, this is an array of coordinates (array where
  # first item is latitude, second longitude) for each point of the bounding
  # box for the area
  attr_accessor :bounding_box
end