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
  def self.scrape(state = nil)
    new(state).scrape
  end

  attr_reader :chosen_state

  def initialize(state)
    if state.present?
      raise "Invalid state. Pick one of the following:\n#{Constants::STATES.join ', '}" unless state.in?(Constants::STATES)
      @chosen_state = state
    end
  end

  def scrape
    load_colleges
  end

  def states
    chosen_state.present? ? [chosen_state] : Constants::STATES
  end

  def load_colleges
    states.each_with_index do |state, index|
      puts "[#{index}] Loading data for #{state}..."
      response = RestClient.get colleges_url(state)
      md5 = Digest::MD5.digest response.body

      if cache_expired?(state, md5)
        update_colleges_cache(index, md5, response, state)
        update_university_info_in_cache(index, state)
      else
        puts "[#{index}] Cache is up-to-date. Not modifying."
      end
    end
  end

  def update_colleges_cache(state_index, md5, response, state)
    puts "[#{state_index}] Cache expired. Updating basic info."
    JSON.parse(response.body).each do |college_data|
      cache_to_yml state, college_data[0], {
        'name' => fix_text(college_data[1]),
        'address' => fix_text(college_data[2]),
        'district' => fix_text(college_data[3]),
        'institution_type' => fix_text(college_data[4]),
      }
    end

    update_timestamp(state, md5)
  end

  def update_university_info_in_cache(state_index, state)
    puts "[#{state_index}] Updating university info..."
    print '['

    cache = YAML.load(File.read(cache_file_path))

    cache[state]['colleges'].keys.each do |aicte_id|
      response = RestClient.get course_details_url(aicte_id)
      doc = Nokogiri::HTML response.body
      universities = doc.css('tbody > tr').map { |tr| tr.xpath('./td')[1].text }.uniq

      cache_to_yml state, aicte_id, {
        'universities' => universities
      }

      print '.'
    end

    print "]\n"
  end

  # "DR. B.R. AMBEDKAR INSTITUTE OF TECHNOLOGY" => "Dr. B.R. Ambedkar Institute Of Technology"
  def fix_text(original_text)
    original_text.downcase.split('.').map(&:capitalize).join('.').split(' ').map { |w| w.sub(/\S/, &:upcase) }.join(' ')
  end

  def cache_file_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'output', 'colleges.yml'))
  end

  def cache_to_yml(state, id, data)
    cache ||= YAML.load(File.read(cache_file_path)) || {}
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

  def update_timestamp(state, md5)
    cache = YAML.load(File.read(cache_file_path))
    cache[state]['updated_at'] = Time.now.iso8601
    cache[state]['md5'] = md5
    File.write(cache_file_path, cache.to_yaml)
  end

  def colleges_url(state)
    Constants::COLLEGES_URL % { state: URI.escape(state) }
  end

  def course_details_url(aicte_id)
    Constants::COURSE_DETAILS_URL % { aicte_id: aicte_id }
  end
end
