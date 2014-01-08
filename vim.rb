#!/usr/bin/env ruby
require 'FileUtils'
require 'optparse'
require 'yaml'

def usage(message = nil)
  $stderr.printf("%s\n", message) unless message.nil?
  $stderr.printf('%s', @option_parser.to_s)
  Kernel.exit(1)
end

class Command
  attr_reader :name
  attr_reader :options
  attr_reader :dot_vim
  attr_reader :dot_vimrc

  def initialize(name = nil, options = {})
    @bin = {}
    @dot_vim = File.expand_path(File.join(ENV['HOME'], '.vim'))
    @dot_vimrc = File.expand_path(File.join(ENV['HOME'], '.vimrc'))
    @github = {} # path => [true,false]
    @install_dir = File.expand_path(File.dirname(__FILE__))
    @name = name
    @options = options
  end

  def run
    $stdout.printf("[vim] [%s] [run] [options=%s]\n", name(), options().inspect.to_s())
  end

  def github_clone(owner = nil, repository = nil, path = nil)
    FileUtils.mkdir_p(path) unless File.exists?(path)

    repository_url = github_build_repository_url(owner, repository)
    github_clone_command = %Q[/usr/bin/git clone #{repository_url} #{path} 2>&1]
    $stdout.printf("[vim] [%s] [%s]\n", name(), github_clone_command)
    out = %x[#{github_clone_command}]
    rc = $?
    raise out unless rc == 0
    @github[path] = true
  end
  def github_pull(path = nil, repository = nil, branch = nil)
    # prevent reaching out multiple times per path
    if @github[path] == true
      $stdout.printf("[vim] [%s] [%s] [using repository cache]\n", name(), path)
      return
    end
    Dir.chdir(path) { 
      out = %x[/usr/bin/git pull #{repository} #{branch}]
      rc = $?
      raise out unless rc == 0
    }
    @github[path] = true
  end
  def github_build_install_path(owner = nil, repository = nil)
    "#{@install_dir}/repositories/com.github/#{owner}/#{repository}"
  end
  def github_build_repository_url(owner = nil, repository = nil)
    "git@github.com:#{owner}/#{repository}"
  end
end

class Install < Command

  def initialize(options = {})
    super('install', options)
  end
  def run
    super
    raise 'Invalid directory.' if @install_dir == @dot_vim
    raise 'File exists:' + @dot_vim if File.exists?(@dot_vim)
    raise 'File exists:' + @dot_vimrc if File.exists?(@dot_vimrc)
    # symlink [.vim,.vimrc] in the user's home dir
    File.symlink("#{@install_dir}/dot-vim", @dot_vim)
    File.symlink("#{@install_dir}/dot-vimrc", @dot_vimrc)
    # update
    Update.new(options).run
    $stdout.printf("[vim] [%s] [installed]\n", name())
  end
end

class Remove < Command
  def initialize(options = {})
    super('remove', options)
  end
  def run
    super
    File.unlink(@dot_vim) if File.symlink?(@dot_vim)
    File.unlink(@dot_vimrc) if File.symlink?(@dot_vimrc)
    FileUtils.rm_rf(File.join(@install_dir, 'repositories'))
    FileUtils.rm_rf(File.join(@install_dir, 'dot-vim'))
    $stdout.printf("[vim] [%s] [removed]\n", name())
  end
end

class Update < Command
  def initialize(options = {})
    super('update', options)
  end
  def run
    config = YAML.load_file(File.join(File.expand_path(File.dirname(__FILE__)), 'vim.yaml'))
    $stdout.printf("[vim] [%s] [config=%s]\n", name(), config.inspect.to_s())
    config.each_key { |plugin|
      hash = config[plugin]
      $stdout.printf("[vim] [%s] [%s] [%s]\n", name(), plugin, hash.inspect.to_s())
      github(hash) if hash['source'].eql?('github')
      pathogen(hash) if hash['source'].eql?('pathogen')
    }
  end

  def github_update(hash = {})
    github_owner = hash['github_owner']
    github_repository = hash['github_repository']
    install_path = github_build_install_path(github_owner, github_repository)
    # repositories/com.github/vim-scripts/xoria256
    if File.exists?(install_path)
      github_pull(install_path, 'origin', 'master')
    else
      github_clone(github_owner, github_repository, install_path)
    end
  end

  def github(hash = {})
    github_update(hash)
    github_owner = hash['github_owner']
    github_repository = hash['github_repository']
    links = hash['links']
    links.each { |link|
      link_path = link.split('/')
      # link parent is the parent dir within which the symlink to the vim script
      # resides; ie colors, syntax
      link_parent = File.join(@install_dir, 'dot-vim')
      link_path.each_index { |i|
        break if i == link_path.length - 1
        link_parent << '/'
        link_parent << link_path[i]
      }
      FileUtils.mkdir_p(link_parent) unless File.exists?(link_parent)
      # link file is the filename
      link_file = link_path[-1]
      # link source is the relative path to the file in the git repo
      link_source = File.join('..', '..', 'repositories', 'com.github', github_owner, github_repository, link)
      Dir.chdir(link_parent) {
        next if File.symlink?(link_file)
        File.symlink(link_source, link_file)
      }
    }
  end

  def pathogen(hash = {})
    github_update(hash)
    github_owner = hash['github_owner']
    github_repository = hash['github_repository']
    pathogen_root = File.join(@install_dir, 'bundle')
    FileUtils.mkdir_p(pathogen_root) unless File.exists?(pathogen_root)
    link_file = File.join(pathogen_root, github_repository)
    return if File.symlink?(link_file)
    link_source = File.join('..', '..', 'repositories', 'com.github', github_owner, github_repository)
    File.symlink(link_source, link_file)
  end
end

@options = {}
@options[:directory] = ENV['HOME']
@options[:force]     = false
@options[:noop]      = false
@option_parser = OptionParser.new() { |option|
  option.on('-d', '--directory [DIRECTORY]') { |value|
    @options[:directory] = value unless value.nil? and File.exists?(value)
  }
  option.on('-f', '--force') { |value|
    @options[:force] = true
  }
  option.on('--noop') { |value|
    @options[:noop] = true
  }
}
@option_parser.parse!
# arguments contain command
@arguments = []
ARGV.each { |argument|
  @arguments << argument
}
@commands = {
  'install' => Install.new(@options),
  'remove'  => Remove.new(@options),
  'update'  => Update.new(@options)
}
@command = @arguments[0] unless @arguments.empty?
usage('No command specified:  ' + @commands.keys.inspect.to_s) if @command.nil?
usage('no such command:' + @command) if not @commands.include?(@command)
@commands[@command].run

