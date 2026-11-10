require 'rake/testtask'

Rake::TestTask.new do |t|
  # absolute paths: the tests chdir into a sandbox while they load
  t.test_files = FileList['test/*_test.rb'].map { |f| File.expand_path(f) }
  t.warning = false
end

task default: :test
