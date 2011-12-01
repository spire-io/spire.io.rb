task :doc do
	`yard`
end

task :test do
	`rspec #{Dir["test/*.rb"]}`
end

task :package => :doc do
	`gem build spire_io.gemspec`
end