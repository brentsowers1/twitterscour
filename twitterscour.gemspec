Gem::Specification.new do |spec|
  spec.name        = 'twitterscour'
  spec.version     = '0.1.0'
  spec.files       = Dir['lib/**/*', 'test/**/*', 'README', 'History.txt']
  spec.test_files  = Dir.glob('test/tc_*.rb')

  spec.summary     = "Class for retrieving tweets directly from Twitter, not using the API"
  spec.description = "Search for tweets directly from the Twitter web site.  Using the API (which most Twitter gems use) returns limited results, this will return everything that you can see by going to the web site directly"

  spec.authors           = 'Brent Sowers'
  spec.email             = 'brent@coordinatecommons.com'
  spec.extra_rdoc_files  = ['README','History.txt']
  spec.homepage          = 'http://www.coordinatecommons.com/twitterscour/'
  spec.has_rdoc          = true
  spec.add_dependency('httparty')
  spec.add_dependency('nokogiri')
  spec.add_dependency('json_pure')
end