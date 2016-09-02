require_relative 'lib/aicte_scraper'

require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = 'Usage: scrape.rb [options]'

  opts.on('-s', '--state STATE', 'Choose state') do |state|
    options[:state] = state
  end

  opts.on('-p', '--processes COUNT', 'Number of processes to run simultaneously') do |processes|
    options[:processes] = processes
  end
end.parse!

AicteScraper.scrape options
