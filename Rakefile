require "rake/clean"

CLEAN << FileList["*.gem"]
CLEAN << FileList["docs/*"]
CLEAN << ".yardoc"

$version = File.read("VERSION").chomp

desc "run yardoc"
task :docs do
	sh "yard --output docs"
end

# Alias for doc task
task :doc => :docs

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

# Updates GITHUB PAGES
desc 'Update gh-pages branch'
task 'docs:pages' => ['docs/.git', :docs] do
  rev = `git rev-parse --short HEAD`.strip
  Dir.chdir 'docs' do
    last_commit = `git log -n1 --pretty=oneline`.strip
    message = "rebuild pages from #{rev}"
    result = last_commit =~ /#{message}/
    # generating yardocs causes updates/modifications in all the docs
    # even when there are changes in the docs (it updates the date/time)
    # So we check if the last commit message if the hash is the same do NOT update the docs
    if result
      verbose { puts "nothing to commit" }
    else
      sh "git add ."
      sh "git commit -m 'rebuild pages from #{rev}'" do |ok,res|
        if ok
          verbose { puts "gh-pages updated" }
          sh "git push -q origin HEAD:gh-pages"
        end
      end
    end
  end
end

# Update the pages/ directory clone
file 'docs/.git' => ['docs/', '.git/refs/heads/gh-pages'] do |f|
    sh "cd docs && git init -q && git remote add origin git@github.com:spire-io/spire.io.rb.git" if !File.exist?(f.name)
    sh "cd docs && git fetch -q origin && git reset -q --hard origin/gh-pages && touch ."
end
