#!/Users/ataylor/.rvm/rubies/ruby-2.1.1/bin/ruby

require 'mechanize'
require 'nokogiri'
require 'feedjira'

#url = ARGV[0]
midd_url = "http://25livepub.collegenet.com/calendars/all-campus-events.rss"

class RSSScraper
  def self.scrape_uri(uri)
    feed = Feedjira::Feed.fetch_and_parse url

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
      puts ''
      puts entry_h
    }
  end
end
