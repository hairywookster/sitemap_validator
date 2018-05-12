#!/usr/bin/env ruby
#Run   rake -T   to see what is available
require 'rubygems'
require 'rake'
require 'active_support/all'
require 'fileutils'
require 'json'
require 'mechanize'
require 'methodize'
require 'logger'
require 'rexml/document'
require 'nokogiri'
require 'erb'
require 'colorize'

def auto_require(path)
  Dir["#{File.dirname(__FILE__)}#{path}/*.rb"].each do |file|
    require(file)
  end
end

auto_require '/lib'
auto_require '/tasks'


desc 'Emits help and summary of commands'
task :help do
  print <<EOF
--------------------------------------------------------------
Sitemap Validator
--------------------------------------------------------------
Run    rake -T    for more information about available tasks
EOF
end

task :default => 'help'

desc 'runs the sitemap validator using the config specified. Usage: run_validator["<path to the config file>", "<path to output folder>"]'
task :run_validator, [:config_file, :result_folder] do |t, args|
  SitemapValidator.run_validator( ConfigValidator.init_config( args[:config_file] ), args[:result_folder] )
end

desc 'validates the config file is valid. Usage: validate_config["<path to the config file>"]'
task :validate_config, :config_file do |t, args|
  ConfigValidator.validate_config_file( args[:config_file] )
end