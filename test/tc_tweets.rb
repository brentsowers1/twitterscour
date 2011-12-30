require 'rubygems'
require 'net/http'
require 'test/unit'
require 'mocha'
require File.dirname(__FILE__) +  '/../lib/twitterscour'

class MockSuccess < Net::HTTPSuccess #:nodoc: all
  def initialize
  end

  def code
    200
  end
end

class MockFailure < Net::HTTPServiceUnavailable #:nodoc: all
  def initialize
  end
  def code
    100
  end
  def body
    "epic fail"
  end
end

class MockHttpResponse #:nodoc: all
  def initialize
  end
end

class TwitterScourTest < Test::Unit::TestCase #:nodoc: all
  def test_get_user_tweets_success
    test_data = File.read(File.dirname(__FILE__) + "/fixtures/brent_page_1.html")
    MockHttpResponse.any_instance.stubs(:body).returns(test_data)
    MockHttpResponse.any_instance.stubs(:code).returns(200)
    HTTParty.expects(:get).twice.returns(MockHttpResponse.new)
    tweets = nil
    assert_nothing_raised do
      tweets = TwitterScour.from_user('sowersb', 2, false)
    end
    assert_not_nil tweets
    assert_equal 40, tweets.length
    [tweets[1], tweets[21]].each do |t|
      assert_equal "Got something working this AM that I spent all afternoon yesterday trying to figure out, and I didn't change anything...", t.text
      assert_equal "sowersb", t.author_name
      assert_equal "http://a0.twimg.com/profile_images/1420695224/Snapshot_of_me_1_normal.jpg", t.author_pic
      assert(t.time >= Time.now - 86401 && t.time <= Time.now - 86399, "Now = #{Time.now - 86400}, t time = #{t.time}")
      assert_nil t.location
    end
  end

  def test_get_search_tweets_success
    test_data = File.read(File.dirname(__FILE__) + "/fixtures/search.json")
    MockHttpResponse.any_instance.stubs(:body).returns(test_data)
    MockHttpResponse.any_instance.stubs(:code).returns(200)
    HTTParty.expects(:get).twice.returns(MockHttpResponse.new)
    tweets = nil
    assert_nothing_raised do
      tweets = TwitterScour.search_term('#Ruby', 2)
    end
    assert_not_nil tweets
    assert_equal 30, tweets.length
    [tweets[3], tweets[18]].each do |t|
      assert_equal "Senior Ruby Developer at Zooppa. Seattle, USA http://goo.gl/fb/OjiZC #ruby", t.text
      assert_equal "JobMotel_Ruby", t.author_name
      assert_equal "http://a3.twimg.com/profile_images/66481318/logos_jobmotel3._normal.jpg", t.author_pic
      assert_equal Time.parse("Fri, 29 Jul 2011 01:31:43 +0000"), t.time
      assert_not_nil t.location
      assert_equal [-3.180498, 51.481307], t.location.center
    end
  end


  def test_get_tweets_error
    MockHttpResponse.any_instance.stubs(:body).returns("Error")
    MockHttpResponse.any_instance.stubs(:code).returns(403)
    HTTParty.expects(:get).twice.returns(MockHttpResponse.new)
    tweets = nil
    assert_raises Exception do
      tweets = TwitterScour.from_user('sowersb', 1, false)
    end

    assert_raises Exception do
      tweets = TwitterScour.search_term('Ruby', 1)
    end

  end

end

