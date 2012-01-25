require "rake/clean"

CLEAN << FileList["*.gem"]
CLEAN << FileList["doc/*"]
CLEAN << ".yardoc"

task :doc do
	sh "yard"
end

task :test do
	sh "rspec #{Dir["test/*.rb"]}"
end

task :package => :doc do
	sh "gem build spire_io.gemspec"
end

task :install => :package do
	sh "gem install spire_io-*.gem"
end
