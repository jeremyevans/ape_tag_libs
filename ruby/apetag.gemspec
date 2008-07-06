spec = Gem::Specification.new do |s| 
  s.name = "apetag"
  s.version = "1.1.2"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.platform = Gem::Platform::RUBY
  s.summary = "APEv2 Tag Reader/Writer"
  s.files = Dir['apetag.rb']
  s.require_path = "."
  s.test_files = Dir["test/test_apetag.rb"]
  s.has_rdoc = true
  s.add_dependency('cicphash', [">= 1.0.0"])
  s.rubyforge_project = 'apetag'
  s.homepage = 'http://apetag.rubyforge.org'
end

