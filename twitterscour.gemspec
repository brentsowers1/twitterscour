Gem::Specification.new do |spec|
  spec.name        = 'twitterscour'
  spec.version     = '0.2.0'
  spec.files       = Dir['twitterscour.rb', 'lib/**/*', 'test/**/*', 'example/**/*' 'README', 'History.txt']
  spec.test_files  = Dir.glob('test/tc_*.rb')

  spec.summary     = "Class for retrieving tweets from Twitter, by user and search term"
  spec.description = "Search for tweets by a search term in one function call.  Uses the Twitter API underneath.  Also find all tweets by user.  This doesn't use the API, because the API returns only what Twitter considers the \"most popular\" tweets in many cases. Using this gem will return everything that you can see by going to the Twitter web site for a user.  User search probably shouldn't be relied upon for a production system, as Twitter can change the structure of their web page at any moment, and if so, this will not work until I update it."

  spec.authors           = 'Brent Sowers'
  spec.email             = 'brent@coordinatecommons.com'
  spec.extra_rdoc_files  = ['README','History.txt']
  spec.homepage          = 'http://coordinatecommons.com/twitterscour/'
  spec.has_rdoc          = true
  spec.add_dependency('httparty')
  spec.add_dependency('nokogiri')
  spec.add_dependency('json_pure')
end