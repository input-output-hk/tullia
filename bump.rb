#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'date'
require 'open3'
require 'English'

pkg = '.#defaultPackage.x86_64-linux'
attrs = `nix eval --json "#{pkg}" --apply 'p: { inherit (p) vendorSha256 version; }'`
raise "couldn't get package info" unless $CHILD_STATUS.success?

old_sha, version = JSON.parse(attrs).values_at('vendorSha256', 'version')

needle = /#{Regexp.escape(old_sha)}/
file = Dir.glob('**/*.nix').find { |path| File.open(path) { |fd| fd.grep(needle).any? } }

raise "couldn't find file containing #{old_sha}" unless file

puts "#{file} is at #{old_sha} #{version}"

puts 'Checking vendorSha256...'

new_sha = nil

Open3.popen3('nix', 'build', "#{pkg}.invalidHash") do |_si, _so, se|
  se.each_line do |line|
    new_sha = $LAST_MATCH_INFO[:sha] if line =~ /^\s+got:\s+(?<sha>sha256-\S+)$/
  end
end

if old_sha == new_sha
  puts 'Skipping vendorSha256 update'
  exit
else
  puts "Updating vendorSha256 #{old_sha} => #{new_sha}"
  updated = File.read(file).gsub(/#{Regexp.escape(old_sha)}/, new_sha)
  puts updated
  File.write(file, updated)
end

puts 'Checking version...'

today = Date.today

md = version.match(/(?<y>\d+)\.(?<m>\d+)\.(?<d>\d+)\.(?<s>\d+)/)
version_date = Date.new(md[:y].to_i, md[:m].to_i, md[:d].to_i)
old_version = version

new_version =
  if today == version_date
    old_version.succ
  else
    today.strftime('%Y.%m.%d.001')
  end

if new_version != old_version
  puts "Updating version #{old_version} => #{new_version}"
  updated = File.read(file).gsub(old_version, new_version)
  File.write(file, updated)
else
  puts 'Skipping version update'
end
