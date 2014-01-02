#!/usr/bin/env ruby
require 'FileUtils'
require 'optparse'

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
    #@install_dir = options[:directory]
    @install_dir = File.expand_path(File.dirname(__FILE__))
    @name = name
    @options = options
  end

  def run
    $stdout.printf("[vim] [%s] [run] [options=%s]\n", name(), options().inspect.to_s())
  end
end

class Install < Command

  def initialize(options = {})
    super('install', options)
  end
  def run
    super
#    raise 'File exists:' + @install_dir if File.exists?(@install_dir)
    raise 'Invalid directory.' if @install_dir == @dot_vim
    raise 'File exists:' + @dot_vim if File.exists?(@dot_vim)
    raise 'File exists:' + @dot_vimrc if File.exists?(@dot_vimrc)

    # clone into install dir
#    out = %x[/usr/bin/git clone git@github.com:raykroeker/vim #{@install_dir} 2>&1]
#    rc = $?
#    raise 'Cannot clone repository.' unless rc == 0

    Dir.mkdir(File.join(@install_dir, 'repositories'))
    Dir.mkdir(File.join(@install_dir, 'repositories', 'com.github'))
    Dir.mkdir(File.join(@install_dir, 'dot-vim'))
    Dir.mkdir(File.join(@install_dir, 'dot-vim', 'autoload'))
    Dir.mkdir(File.join(@install_dir, 'dot-vim', 'colors'))

    # pathogen
    github_clone('tpope', 'vim-pathogen')
    File.symlink(File.join(@install_dir, 'repositories', 'com.github', 'tpope', 'vim-pathogen', 'autoload', 'pathogen.vim'),
      File.join(@install_dir, 'dot-vim', 'autoload', 'pathogen.vim'))

    # navajo-night
    github_clone('vim-scripts', 'navajo-night')
    File.symlink(File.join(@install_dir, 'repositories', 'com.github', 'vim-scripts', 'navajo-night', 'colors', 'navajo-night.vim'),
      File.join(@install_dir, 'dot-vim', 'colors', 'navajo-night.vim'))

    # symlink [.vim,.vimrc] in the user's home dir
    File.symlink("#{@install_dir}/dot-vim", @dot_vim)
    File.symlink("#{@install_dir}/dot-vimrc", @dot_vimrc)
    $stdout.printf("[vim] [%s] [installed]\n", name())
  end

  def github_clone(owner = nil, repository = nil)
    Dir.mkdir(File.join(@install_dir, 'repositories', 'com.github', owner))   
    out = %x[/usr/bin/git clone git@github.com:#{owner}/#{repository} #{@install_dir}/repositories/com.github/#{owner}/#{repository} 2>&1]
    rc = $?
    raise 'Cannot clone repository:' + owner + '/' + repository unless rc == 0
  end
end

class Remove < Command
  def initialize(options = {})
    super('remove', options)
  end
  def run
    super
    File.unlink(@dot_vim) if File.exists?(@dot_vim) and File.symlink?(@dot_vim)
    File.unlink(@dot_vimrc) if File.exists?(@dot_vimrc) and File.symlink?(@dot_vimrc)
    FileUtils.rm_rf(File.join(@install_dir, 'repositories'))
    FileUtils.rm_rf(File.join(@install_dir, 'dot-vim'))
#    FileUtils.rm_rf(@install_dir) if File.exists?(@install_dir)
    $stdout.printf("[vim] [%s] [removed]\n", name())
  end
end

class Update < Command
  def initialize(options = {})
    super('update', options)
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

