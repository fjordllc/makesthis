require './app.rb'

task :default => :test

task :test do
end

desc 'Create database'
task 'db:migrate' do
  Profile.auto_migrate!
end

desc 'Execute seed script'
task 'db:seed' do
end
