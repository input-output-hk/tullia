#!/usr/bin/env ruby

require 'json'
require 'date'
require 'open3'

pkg = '.#defaultPackage.x86_64-linux'
attrs = `nix eval --json "#{pkg}" --apply \
'p: { inherit (builtins.unsafeGetAttrPos "pname" p) file; inherit (p) vendorSha256 version; }'`
file, old_sha, version = JSON.parse(attrs).values_at('file', 'vendorSha256', 'version')
file = File.join(file.split('/')[4..-1])

puts 'Checking vendorSha256...'

new_sha = nil

Open3.popen3('nix', 'build', "#{pkg}.invalidHash") do |_si, _so, se|
  se.each_line do |line|
    new_sha = $~[:sha] if line =~ /^\s+got:\s+(?<sha>sha256-\S+)$/
  end
end

if old_sha == new_sha
  puts 'Skipping vendorSha256 update'
  exit
else
  puts "Updating vendorSha256 #{old_sha} => #{new_sha}"
  updated = File.read(file).gsub(old_sha, new_sha)
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
