# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rubyscholar/version'

Gem::Specification.new do |gem|
  gem.name          = "rubyscholar"
  gem.version       = Rubyscholar::VERSION
  gem.authors       = ["Yannick Wurm","Gaurav Koley"]
  gem.email         = ["y.wurm@qmul.ac.uk","arkokoley@live.in"]
  gem.description   = %q{Scrape Google Scholar}
  gem.summary       = %q{Rubyscholar scrapes google scholar and formats it into a scholar.html file.}
  gem.homepage      = ""

  gem.add_dependency "nokogiri", "~>1.6.0"
  gem.add_dependency "commander", "~>4.1.5"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
