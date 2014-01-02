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
      github_owner = hash['github_owner']
      github_repository = hash['github_repository']
      install_path = github_build_install_path(github_owner, github_repository)
      # repositories/com.github/vim-scripts/xoria256
      if File.exists?(install_path)
        github_pull(install_path, 'origin', 'master')
      else
        github_clone(github_owner, github_repository, install_path)
      end
      links = hash['links']
      links.each { |link|
        link_source = File.join(install_path, link)
        link_target = File.join(@install_dir, 'dot-vim', link)
        FileUtils.mkdir_p(File.dirname(link_target)) unless File.exists?(File.dirname(link_target))
        next if File.exists?(link_target)
        File.symlink(link_source, link_target)
      }
    }
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

