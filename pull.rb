#!/usr/bin/env ruby
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('Gemfile', __dir__)
require 'bundler/setup'

require_relative 'lib/github'
require_relative 'lib/store'

class IssuePuller
  def self.start(repo)
    issues = Github.fetch_all(repo)
    Store.to_file(repo, issues)
  end
end

if ARGV.length < 1
  puts "Specify repo"
  exit
end

IssuePuller.start(ARGV[0])
