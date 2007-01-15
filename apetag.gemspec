spec = Gem::Specification.new do |s| 
  s.name = "apetag"
  s.version = "1.0.0"
  s.author = "Jeremy Evans"
  s.email = "jeremyevans0@gmail.com"
  s.platform = Gem::Platform::RUBY
  s.summary = "APEv2 Tag Parser/Generator"
  s.files = Dir['apetag.rb']
  s.autorequire = "apetag"
  s.require_path = "."
  s.test_files = Dir["test/test_apetag.rb"]
  s.has_rdoc = true
end

