#!/usr/bin/env ruby
require 'FileUtils'
require 'optparse'

options = {}
options[:directory] = ENV['HOME']
options[:force] = false
option_parser = OptionParser.new() { |option|
  option.on('-d', '--directory [DIRECTORY]') { |value|
    options[:directory] = value unless value.nil? and File.exists?(value)
  }
  option.on('-f', '--force') { |value|
    options[:force] = true
  }
}
option_parser.parse!

$stdout.printf("[vim] [%s] [options=%s]\n", options.inspect.to_s)
$stdout.printf("[vim] [%s] [%s]\n", File.dirname(__FILE__))
Dir.entries(File.dirname(__FILE__)) { |entry|
  $stdout.printf("[vim] [%s] [entry=%s]\n", entry)
}

