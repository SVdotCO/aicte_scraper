# Standard libraries
require 'digest'
require 'yaml'
require 'fileutils'

# Gems
require 'parallel'
require 'rest-client'
require 'nokogiri'
require 'titleize'

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
    unless state.nil?
      raise "Invalid state. Pick one of the following:\n#{Constants::STATES.join ', '}" unless Constants::STATES.include?(state)
      @state = state
    end

    @processes = processes.to_i
  end

  # Attempts to call a URL, rescues any sort of RestClient exception, and retries after 20 seconds.
  def rescued_get(url)
    RestClient.get url
  rescue RestClient::Exception => e
    log "RestClient::Exception => #{e.class}"
    log 'Encountered an issue while attempting to load URL. Sleeping for 20 seconds before retrying...'
    sleep 20
    retry
  end

  # The entry point. Starts by checking whether cached data is up-to-date using an MD5 hash. If expired or missing,
  # it'll first load the colleges index, and then call the course end-point for each college to populate university
  # information.
  def scrape
    Parallel.each(states, in_processes: processes) do |current_state|
      @state = current_state
      start_time = Time.now.to_i

      log 'Loading index of colleges from AICTE...'

      response = rescued_get colleges_url
      md5 = Digest::MD5.digest response.body

      if cache_expired?(state, md5)
        update_colleges_cache(response)
        update_university_info_in_cache
        update_timestamp(md5)
        log "Done! Completed in #{Time.now.to_i - start_time} seconds."
      else
        log 'Cached data is up-to-date. Not modifying.'
      end
    end
  end

  def states
    state.nil? ? Constants::STATES : [state]
  end

  # The bit to the left of each log line, indicating which state the log is for. Super useful when running with
  # multiple processes.
  def log_index
    if state.split.count > 1
      first = state.split[0].upcase
      rest = state.split[1..-1].map(&:first).join('-').upcase
      "#{first}-#{rest}"
    else
      state.upcase
    end.ljust(13)
  end

  # Print the message with an explicit line-break, instead of puts to avoid issues when running with multiple processes.
  def log(message)
    print "[#{log_index}] #{message}\n"
  end

  # Store basic information about collegs to YAML.
  # TODO: Try optimizing. It's probably not necessary to write to disk after each iteration over the loop.
  def update_colleges_cache(response)
    log 'Cache expired. Storing index of colleges...'

    JSON.parse(response.body).each do |college_data|
      cache_to_yml(
        college_data[0],
        'name' => fix_text(college_data[1]),
        'address' => fix_text(college_data[2]),
        'district' => fix_text(college_data[3]),
        'institution_type' => fix_text(college_data[4])
      )
    end
  end

  # Load and store universities associated with colleges.
  def update_university_info_in_cache
    cache = YAML.load(File.read(cache_file_path))

    total_colleges = cache[state]['colleges'].count
    log "Adding university info for #{total_colleges} colleges..."

    cache[state]['colleges'].keys.each_with_index do |aicte_id, index|
      if ((index + 1) % 10).zero?
        log "Progress of adding university info: #{index + 1} / #{total_colleges}"
      end

      response = rescued_get course_details_url(aicte_id)
      universities = extract_universitied_from_course_details(response)

      cache_to_yml aicte_id, 'universities' => universities
    end
  end

  # A college can be associated to multiple universities through the courses that it offers. So we need to fetch all
  # courses and get unique university name from each entry.
  def extract_universitied_from_course_details(response)
    doc = Nokogiri::HTML response.body
    universities = doc.css('tbody > tr').map { |tr| fix_text(tr.xpath('./td')[1].text) }.uniq
    universities - %w(None)
  end

  # ' DR. B.R. AMBEDKAR INSTITUTE OF   TECHNOLOGY , SOMEWHERE,  ' => "Dr. B.R. Ambedkar Institute of Technology, Somewhere"
  def fix_text(original_text)
    return if original_text.nil?
    case_fixed = downcase_all_caps(original_text)
    line_breaks_removed = remove_line_breaks(case_fixed)
    space_before_comma_removed = remove_space_before_comma(line_breaks_removed)
    space_added_after_comma = add_space_after_comma(space_before_comma_removed)
    capitalized_after_space = capitalize_after_spaces(space_added_after_comma)
    squish_text = capitalized_after_space.titleize
    capitalized_after_periods = capitalize_after_periods(squish_text)
    remove_trailing_comma(capitalized_after_periods)
  end

  # The reasoning behind this conversion is that all-caps text doesn't have any real casing information. So we can
  # attempt to reconstruct it, even if the output isn't perfect (contains abbreviations), it's better than all-caps.
  # 'HELLO' => 'hello'
  # 'HellO' => 'HellO'
  # "vavanoor,(via) koottanad,palakkad dist. \r\n679 533"
  def downcase_all_caps(text)
    text.upcase == text ? text.downcase : text
  end

  # "Hello\r\nWorld" => "Hello World"
  def remove_line_breaks(text)
    text.gsub(/\r\n?/, ' ')
  end

  # 'Street ,City' => 'Street,City'
  def remove_space_before_comma(text)
    text.gsub(/\s,/, ',')
  end

  # 'Street,City, State,' => 'Street, City, State,'
  def add_space_after_comma(text)
    text.gsub(/,([\w()])/, ', \1')
  end

  def capitalize_after_spaces(text)
    text.split(' ').map { |w| w.sub(/\S/, &:upcase) }.join(' ')
  end

  # 'b.r. ambedkar' => 'B.R. Ambedkar'
  def capitalize_after_periods(text)
    text.split('.').map { |w| w.sub(/\S/, &:upcase) }.join('.')
  end

  # 'B.R. Ambedkar of ,' => 'B.R. Ambedkar of'
  def remove_trailing_comma(text)
    text[-1] == ',' ? text[0..-2] : text
  end

  # The name of the cache file to which output is written.
  def state_cache_name
    state.split.map(&:downcase).join('_')
  end

  # The path to the output file.
  def cache_file_path
    File.expand_path(File.join(File.dirname(__FILE__), '..', 'output', "#{state_cache_name}.yml"))
  end

  # Method that actually updates contents of the cache file.
  def cache_to_yml(id, data)
    cache = YAML.load(File.read(cache_file_path)) || {}
    cache[state] ||= {}
    cache[state]['colleges'] ||= {}
    cache[state]['colleges'][id] ||= {}
    cache[state]['colleges'][id].merge! data
    File.write(cache_file_path, cache.to_yaml)
  end

  # Returns true if the stored MD5 value equals the supplied (precomputed) one.
  def cache_expired?(state, md5)
    create_cache_if_missing
    cache = YAML.load(File.read(cache_file_path)) || {}
    return true if cache[state].nil?
    return true if cache[state]['md5'] != md5
    false
  end

  # Creates a cache file it it doesn't exist.
  def create_cache_if_missing
    return if File.exist?(cache_file_path)
    FileUtils.touch cache_file_path
  end

  # Updates the timestamp and md5 in cache file.
  def update_timestamp(md5)
    cache = YAML.load(File.read(cache_file_path))
    cache[state]['updated_at'] = Time.now.iso8601
    cache[state]['md5'] = md5
    File.write(cache_file_path, cache.to_yaml)
  end

  # URL from which index of colleges is retrieved.
  def colleges_url
    Constants::COLLEGES_URL % { state: URI.escape(state) }
  end

  # URL from which course details are retrieved.
  def course_details_url(aicte_id)
    Constants::COURSE_DETAILS_URL % { aicte_id: aicte_id }
  end
end
