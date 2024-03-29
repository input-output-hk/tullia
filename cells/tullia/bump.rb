#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'date'
require 'open3'
require 'English'

pkg = 'path:.#packages.x86_64-linux.default'
old_sha, version = []

Open3.popen3(
  'nix', 'eval', '--json', pkg,
  '--extra-experimental-features', 'nix-command flakes',
  '--apply', 'p: { inherit (p) vendorSha256 version; }'
) do |_si, so, se|
  se.each_line do |line|
    puts line
  end

  so.each_line do |line|
    puts line
    old_sha, version = JSON.parse(line).values_at('vendorSha256', 'version')
  end
end

# Open3 doesn't set $? when things go smooth
raise "couldn't get package data" if $CHILD_STATUS && !$CHILD_STATUS.success?

needle = /#{Regexp.escape(old_sha)}/
file = Dir.glob('**/*.nix').find { |path| File.open(path) { |fd| fd.grep(needle).any? } }

raise "couldn't find file containing #{old_sha}" unless file

file_mtime = File.mtime(file)
mod_mtime = File.mtime('go.mod')
if file_mtime >= mod_mtime
  puts "#{file} is newer than go.mod - skip bump"
  exit
else
  puts "#{file} is older than go.mod - #{file_mtime} < #{mod_mtime}"
end

puts "#{file} is at #{old_sha} #{version}"

puts 'Checking vendorSha256...'

new_sha = nil

Open3.popen3(
  'nix', '-L',
  '--extra-experimental-features', 'nix-command flakes',
  'build', "#{pkg}.invalidHash"
) do |_si, so, se|
  so.each_line do |line|
    puts line
  end

  se.each_line do |line|
    puts line
    new_sha = $LAST_MATCH_INFO[:sha] if line =~ /^\s+got:\s+(?<sha>sha256-\S+)$/
  end
end

raise "couldn't build package" if $CHILD_STATUS && !$CHILD_STATUS.success?

if old_sha == new_sha
  puts 'Skipping vendorSha256 update'
  exit
else
  puts "Updating vendorSha256 #{old_sha} => #{new_sha}"
  updated = File.read(file).gsub(/#{Regexp.escape(old_sha)}/, new_sha)
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
