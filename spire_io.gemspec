$version = File.read("VERSION").chomp
$authors = []
$emails = []
File.open "AUTHORS","r" do |file|
	authors = file.read
	authors.split("\n").map do |author|
		name, email = author.split("\t")
		$authors << name ; $emails << email
	end
end

Gem::Specification.new do |s|
  s.name        = 'spire_io'
  s.version     = $version
  s.summary     = "Ruby client for spire.io"
  s.description = <<-EOF
		The spire_io gem allows you to quickly and easily use the spire.io service
		using Ruby. See http://www.spire.io/ for more.
		EOF
  s.authors     = $authors
  s.email       = $emails
  s.require_path = "lib"
  s.files       = Dir["lib/spire/**/*.rb"] + %w[lib/spire_io.rb]
  s.homepage    =
    'https://github.com/spire-io/spire.io.rb'
	s.add_runtime_dependency "json", ["~> 1.6"]
	s.add_runtime_dependency "excon", ["~> 0.7"]
	s.add_development_dependency "rspec", ["~> 2.7"]
	s.add_development_dependency "yard", ["~> 0.7"]
	s.add_development_dependency "redcarpet", ["~> 2.1.0"]
end
