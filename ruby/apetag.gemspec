spec = Gem::Specification.new do |s| 
  s.name = "apetag"
  s.version = "1.1.5"
  s.author = "Jeremy Evans"
  s.email = "code@jeremyevans.net"
  s.platform = Gem::Platform::RUBY
  s.summary = "APEv2 Tag Reader/Writer"
  s.files = %w'MIT-LICENSE apetag.rb'
  s.require_path = "."
  s.add_dependency('cicphash', [">= 1.0.0"])
  s.homepage = 'https://ruby-apetag.jeremyevans.net'
  s.metadata = {
    'bug_tracker_uri'   => 'https://github.com/jeremyevans/ape_tag_libs/issues',
    'mailing_list_uri'  => 'https://github.com/jeremyevans/ape_tag_libs/discussions',
    'source_code_uri'   => 'https://github.com/jeremyevans/ape_tag_libs/tree/master/ruby',
  }
end
