#!/usr/bin/env ruby
require 'FileUtils'
require 'optparse'

def usage(message = nil)
  $stderr.printf("%s\n", message) unless message.nil?
  $stderr.printf('%s', @option_parser.to_s)
  Kernel.exit(1)
end

def get_install_root
  if @install_root.nil?
    @install_root = File.expand_path(File.dirname(__FILE__))
  end
  @install_root
end

class Command
  attr_reader :bin
  attr_reader :name
  attr_reader :options

  def initialize(name = nil, options = {})
    @bin = {}
    @bin[:git] = '/usr/bin/git'
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
    @install_dir = options()[:directory]
  end
  def run
    super
    raise 'Install directory exists.' if File.exists?(@install_dir)
    # clone into install dir
    out = %x[#{@bin[:git]} clone git@github.com:raykroeker/vim #{@install_dir} 2>&1]
    rc = $?
    raise 'Cannot clone repository.' unless rc == 0
    # symlink .vimrc in the install dir's parent to dot-vimrc
    vimrc = File.expand_path(File.join(@install_dir, '..', '.vimrc'))
    File.symlink("#{@install_dir}/dot-vimrc", vimrc)
    $stdout.printf("[vim] [%s] [installed]\n", name())
  end
end

class Remove < Command
  def initialize(options = {})
    super('remove', options)
    @install_dir = options()[:directory]
  end
  def run
    super
    raise 'Install directory does not exist:' + @install_dir unless File.exists?(@install_dir)
    vimrc = File.expand_path(File.join(@install_dir, '..', '.vimrc'))
    raise 'File does not exist:' + vimrc unless File.exists?(vimrc)
    File.unlink(vimrc)
    FileUtils.rm_rf(@install_dir)
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

