require './lib/rubyscholar-version.rb'

Gem::Specification.new do |gem|
  gem.name          = 'rubyscholar'
  gem.version       = Rubyscholar::VERSION
  gem.authors       = ['Yannick Wurm','Gaurav Koley']
  gem.email         = ['y.wurm@qmul.ac.uk','arkokoley@live.in']
  gem.description   = %q{Scrape Google Scholar Profile page}
  gem.summary       = %q{Rubyscholar scrapes one google scholar and formats it into a scholar.html file listing publications.}
  gem.homepage      = 'http://yannick.poulet.org/'
  gem.license       = 'MIT'


  gem.add_runtime_dependency 'nokogiri',  '~> 1.6', '>= 1.6.0'
  gem.add_runtime_dependency 'commander', '~> 4.1', '>= 4.1.5'

  gem.files         = Dir['lib/**/*'] + Dir['views/**/*'] + Dir['public/**/*'] + Dir['tests/**/*']
  gem.files         = gem.files + ['example.config.yml']
  gem.files         = gem.files + ['LICENSE.txt', 'README.md']
  gem.files         = gem.files + ['Gemfile',     'rubyscholar.gemspec']

  gem.executables   = ['rubyscholar']
  gem.require_paths = ['lib']

  gem.post_install_message = <<INFO

-----
Thanks for installing rubyscholar. 
If something isn't working, this may be due to Google's changing the format of Scholar pages
(they do this regularly with no warning). 

If you can have a shot at fixing it, please go ahead - pull requests are most welcome.

All the best,  

Yannick  -  http://yannick.poulet.org
----

INFO
end
