require 'mechanize'
require 'nokogiri'
require 'feedjira'
require 'uri'
require 'bloomfilter-rb'
require 'logger'

class RSSCrawler

  @agent = Mechanize.new
  @agent.read_timeout = 8
  @agent.open_timeout = 8

  @crawl_queue = Array.new # using an array to prevent special threading features of actual queues in ruby
  # m = 150,000, k = 11, seed = 666
  @bf = BloomFilter::Native.new(size: 150000,hashes: 11,seed: 1)

  @root_url = ARGV[0] ? ARGV[0] : "http://www.williams.edu" # command line input or default of williams website
  @root_uri = URI.parse(@root_url)
  root_page = @agent.get(@root_url)
  @crawl_queue.insert(0,root_page)

  @pages_crawled = 0

  @rss_feeds = []

  def self.crawl_loop

    logger = Logger.new('logfile.log')
    logger.level = Logger::DEBUG

    logger.debug("Created logger")
    logger.info("Program started")
    logger.warn("Nothing to do!")

    path = "a_non_existent_file"

    while ! @crawl_queue.empty? do
      page = @crawl_queue.pop

      if page.kind_of? Mechanize::Image
        puts "Image in crawl queue for uri: #{page.uri}"
      end

      next unless page.kind_of? Mechanize::Page

      @pages_crawled += 1

      logger.info "\n\n||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||"
      logger.info "queue contains: #{@crawl_queue.count.to_s} with #{@pages_crawled} scraped so far"
      logger.info "Starting page: " + page.title.to_s
      logger.info "||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||\n\n"


      page.links.each do |l|

        # utilizes a bloom filter to keep track of links that have already been traversed
        if @bf.include?(l.href.to_s) then
          # puts "HREF: #{l.href} already added to queue"
          next
        end
        @bf.insert(l.href.to_s)
        logger.info "HREF: ~#{l.href}~"

        next unless self.acceptable_link_format?(l)

        uri = l.uri
        logger.info "LINK ^^^^^^^^^^^^^^^^^^^"

        if self.rss?(uri)
          logger.info "********************************"
          logger.info "RSS: " + uri.to_s
          logger.info "********************************"
          @rss_feeds << uri
          # spawn a new thread to parse the rss feed site
          rss_scrape = Thread.new {
            self.scrape_uri(uri.to_s)
          }
        end

        next unless self.within_domain?(uri)

        new_page = l.click
        @crawl_queue.insert(0,new_page)

        sleep 2.0 + (2.0 * rand)

      end
    end
    logger.close
  end

  # scrapes a given rss feed indicated by the string passed in of its uri
  def self.scrape_uri(uri)
    feed = Feedjira::Feed.fetch_and_parse(uri)

    feed.entries.each { |entry|
      entry_h = {}
      entry_h[:title] = entry.title
      entry_h[:url] = entry.url
      html = Nokogiri::HTML(entry.summary)
      entry_h[:summary] = {}
      html.xpath("//b").each { |t|
        val = t.next.text.match(/[[:alnum:]]/) ? t.next : t.next.next
        entry_h[:summary][t.text] = val.text
      }
      # replace this with a write to a seperate file
      puts "\n#{entry_h}"
    }
  end

  def self.acceptable_link_format?(link)
    begin
      if link.uri.to_s.match(/#/) || link.uri.to_s.empty? then return false end # handles anchor links within the page
      if (link.uri.scheme != "http") && (link.uri.scheme != "http") then return false end # handles other protocols like tel: and ftp:
      # prevents download of media files, should be a better way to do this than by explicit checks for each type for all URIs
      if link.uri.to_s.match(/.pdf|.jgp|.jgp2|.png|.gif/) then return false end
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

  if __FILE__ == $0

    # starts the loop crawling the website
    begin
      puts 'running RSS crawler'
      self.crawl_loop
    rescue Interrupt
      puts "\nended crawl"
    ensure
      puts "#{@rss_feeds.count} RSS feeds found"
      @rss_feeds.each { |feed| puts feed.to_s }
    end
  end
end
