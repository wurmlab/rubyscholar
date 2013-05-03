require_relative '../lib/rubyscholar'
require 'yaml'

config    = YAML.load_file('config.yml')

parsed    = RubyScholar::Parser.new(config["url"], 
                                    config["email"])
formatter = RubyScholar::Formatter.new(parsed, 
                                       config["highlight"], 
                                       config["pdfs"], 
                                       config["altmetricDOIs"], 
                                       config["minCitations"].to_i)

html = formatter.to_html
config["italicize"].each do |term|
  html.gsub!( term , '<em>' + term + '</em>')
end

puts html

