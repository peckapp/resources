require 'mechanize'
require 'nokogiri'
require 'uri'
require 'bloomfilter-rb'

class RSSCrawler

  def self.acceptable_link_format?(link)
    begin
      if link.uri.to_s.match(/#/) || link.uri.to_s.empty? then return false end # handles anchor links within the page
      if (link.uri.scheme != "http") && (link.uri.scheme != "http") then return false end # handles other protocols like tel: and ftp:
      # prevents download of media files, should be a better way to do this than by explicit checks for each type for all URIs
      if link.uri.to_s.match(/.pdf/) ||
         link.uri.to_s.match(/.jgp/) ||
         link.uri.to_s.match(/.jgp2/) ||
         link.uri.to_s.match(/.png/) ||
         link.uri.to_s.match(/.gif/)
      then
        return false
      end
    rescue
      return false
    end
    true
  end

  def self.within_domain?(link)
    if link.relative? then return true end # handles relative links within the site
    @root_uri.route_to(link).host ? false : true
  end

  def self.rss?(link)
    link.to_s.match(/rss/)
  end

  puts 'running RSS crawler'

  @agent = Mechanize.new
  @crawl_queue = Array.new # using an array to prevent special threading features of actual queues in ruby
  # m = 150,000, k = 11, seed = 666
  @bf = BloomFilter::Native.new(size: 150000,hashes: 11,seed: 1)

  @root_url = ARGV[0] ? ARGV[0] : "http://www.williams.edu" # command line input or default of williams website
  @root_uri = URI.parse(@root_url)
  root_page = @agent.get(@root_url)
  @crawl_queue.insert(0,root_page)

  @rss_feeds = []

  def self.crawl_loop
    while ! @crawl_queue.empty? do
      page = @crawl_queue.pop

      next unless page.kind_of? Mechanize::Page

      puts "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
      puts "queue contains: " + @crawl_queue.count.to_s
      puts "Starting page: " + page.title.to_s
      puts "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"

      page.links.each do |l|

        # utilizes a bloom filter to keep track of links that have already been traversed
        if @bf.include?(l.href.to_s) then
          # puts "HREF: #{l.href} already added to queue"
          next
        end
        @bf.insert(l.href.to_s)
        print "HREF: ~#{l.href}~"

        next unless self.acceptable_link_format?(l)

        uri = l.uri
        puts " <<<< LINK"

        if self.rss?(uri)
          puts "********************************"
          puts "RSS: " + uri.to_s
          puts "********************************"
          @rss_feeds << uri
        end

        next unless self.within_domain?(uri)

        new_page = l.click
        @crawl_queue.insert(0,new_page)

      end
    end
  end

  if __FILE__ == $0

    # starts the loop crawling the website
    begin
      self.crawl_loop
    rescue Interrupt
      puts "\nended crawl"
    ensure
      puts "#{@rss_feeds.count} RSS feeds found"
      @rss_feeds.each { |feed| puts feed.to_s }
    end
  end
end
