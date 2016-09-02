# Standard libraries
require 'digest'
require 'yaml'
require 'fileutils'

# Gems
require 'parallel'
require 'active_support/all'
require 'rest-client'
require 'nokogiri'

# Local
require_relative 'aicte_scraper/constants'

# Scrapes college data from http://www.aicte-india.org.
class AicteScraper
  attr_reader :state
  attr_reader :processes

  def self.scrape(state: nil, processes: nil)
    new(state, processes).scrape
  end

  def initialize(state, processes)
    if state.present?
      raise "Invalid state. Pick one of the following:\n#{Constants::STATES.join ', '}" unless state.in?(Constants::STATES)
      @state = state
    end

    @processes = processes.to_i
  end

  def rescued_get(url)
    begin
      RestClient.get url
    rescue RestClient::Exception => e
      log "RestClient::Exception => #{e.class}"
      log 'Encountered an issue while attempting to load URL. Sleeping for 20 seconds before retrying...'
      sleep 20
      retry
    end
  end

  def scrape
    Parallel.each(states, in_processes: processes) do |current_state|
      @state = current_state

      log 'Loading index of colleges from AICTE...'

      response = rescued_get colleges_url
      md5 = Digest::MD5.digest response.body

      if cache_expired?(state, md5)
        update_colleges_cache(md5, response)
        update_university_info_in_cache
        update_timestamp(md5)
        log 'Done!'
      else
        log 'Cached data is up-to-date. Not modifying.'
      end
    end
  end

  def states
    state.present? ? [state] : Constants::STATES
  end

  def log_index
    begin
      if state.split.count > 1
        first = state.split[0].upcase
        rest = state.split[1..-1].map(&:first).join('-').upcase
        "#{first}-#{rest}"
      else
        state.upcase
      end.ljust(13)
    end
  end

  def log(message)
    puts "[#{log_index}] #{message}"
  end

  def update_colleges_cache(md5, response)
    log 'Cache expired. Storing index of colleges...'

    JSON.parse(response.body).each do |college_data|
      cache_to_yml college_data[0], {
        'name' => fix_text(college_data[1]),
        'address' => fix_text(college_data[2]),
        'district' => fix_text(college_data[3]),
        'institution_type' => fix_text(college_data[4]),
      }
    end
  end

  def update_university_info_in_cache
    cache = YAML.load(File.read(cache_file_path))

    total_colleges = cache[state]['colleges'].count
    log "Adding university info for #{total_colleges} colleges..."

    cache[state]['colleges'].keys.each_with_index do |aicte_id, index|
      if ((index + 1) % 10) == 0
        log "Progress of adding university info: #{index + 1} / #{total_colleges}"
      end

      response = rescued_get course_details_url(aicte_id)
      doc = Nokogiri::HTML response.body
      universities = doc.css('tbody > tr').map { |tr| tr.xpath('./td')[1].text }.uniq

      cache_to_yml aicte_id, {
        'universities' => universities
      }
    end
  end

  # "DR. B.R. AMBEDKAR INSTITUTE OF TECHNOLOGY" => "Dr. B.R. Ambedkar Institute Of Technology"
  # TODO: Remove trailing comma, if any.
  def fix_text(original_text)
    return if original_text.nil?
    original_text.downcase.split('.').map(&:capitalize).join('.').split(' ').map { |w| w.sub(/\S/, &:upcase) }.join(' ')
  end

  def state_cache_name
    state.split.map(&:capitalize).join.underscore
  end

  def cache_file_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'output', "#{state_cache_name}.yml"))
  end

  def cache_to_yml(id, data)
    cache = YAML.load(File.read(cache_file_path)) || {}
    cache[state] ||= {}
    cache[state]['colleges'] ||= {}
    cache[state]['colleges'][id] ||= {}
    cache[state]['colleges'][id].merge! data
    File.write(cache_file_path, cache.to_yaml)
  end

  def cache_expired?(state, md5)
    create_cache_if_missing
    cache = YAML.load(File.read(cache_file_path)) || {}
    return true if cache[state].nil?
    return true if cache[state]['md5'] != md5
    false
  end

  def create_cache_if_missing
    return if File.exists?(cache_file_path)
    FileUtils.touch cache_file_path
  end

  def update_timestamp(md5)
    cache = YAML.load(File.read(cache_file_path))
    cache[state]['updated_at'] = Time.now.iso8601
    cache[state]['md5'] = md5
    File.write(cache_file_path, cache.to_yaml)
  end

  def colleges_url
    Constants::COLLEGES_URL % { state: URI.escape(state) }
  end

  def course_details_url(aicte_id)
    Constants::COURSE_DETAILS_URL % { aicte_id: aicte_id }
  end
end
