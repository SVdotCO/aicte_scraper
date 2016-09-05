require 'yaml'

# This is an example that'll scan the output YML-s and count the number of colleges.
class ExampleOutputReader
  def perform
    college_count = Dir.glob('output/*.yml').map do |data_file_path|
      colleges = YAML.load(open(data_file_path).read)
      scan colleges
    end.inject(&:+)

    puts "Total number of colleges: #{college_count}"
  end

  def scan(colleges)
    state = colleges.keys.first
    count = colleges[state]['colleges'].count
    puts "#{state}: #{count}"
    count
  end
end

ExampleOutputReader.new.perform
