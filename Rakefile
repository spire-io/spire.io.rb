require "rake/clean"

CLEAN << FileList["*.gem"]
CLEAN << FileList["doc/*"]
CLEAN << ".yardoc"

$version = File.read("VERSION").chomp

desc "run yardoc"
task :doc do
	sh "yard"
end

desc "run tests"
task :test do
	sh "rspec #{FileList["test/*.rb"]}"
end

task :gem => :update do
	sh "gem build spire_io.gemspec"
end

task :update do
  sh "bundle install"
end

desc "generate docs and build a gem"
task :package => [:doc, :gem]

desc "build and install the gem"
task :install => :package do
	sh "gem install spire_io-#{$version}.gem"
end
