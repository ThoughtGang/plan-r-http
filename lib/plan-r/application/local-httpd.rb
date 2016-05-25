#!/usr/bin/env ruby
# :title: Plan-R Local Webapp Application
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'ostruct'
require 'optparse'

require 'plan-r/application/local-httpd/server'
require 'plan-r/application/local-httpd/browser'

module PlanR

=begin rdoc
CLI application for launching Webapp.
Note that this is not a PlanR::Application, and does not start any
services. That is the responsiblity of the WebApp, as it runs in its own
Process.
=end
  class HttpApplication
    PID_FILE = 'local-httpd.pid'
    attr_reader :options
    attr_reader :debug
    attr_reader :server

    def initialize(args)
      @options = OpenStruct.new
      handle_options(args)
    end

=begin rdoc
Use OptionParser to handle command-line arguments. This fills @options with
values obtained from the arguments.
=end
    def handle_options(args)
      @options.start_uri = '/repo/browse/all/'
      @options.browser = nil
      @options.config = nil
      @options.headless = false
      @options.host = nil
      @options.port = nil
      @options.debug = false
      @options.disable_java =false 
      @options.disable_plugins = false
      @options.disable_vcs = false
      @options.disable_db = false
      @options.no_services = false
      @options.autosave = true
      @options.readonly = false
      @options.repo_root = nil
      @options.repo = nil


      opts = OptionParser.new do |opts|
        opts.banner = "Usage: #{File.basename $0} [REPO]"
        opts.on( '-b', '--browser cmd', 'Browser to use for UI',
                 'This can be a path to an executable or a command') do |path|
          @options.browser = path
        end

        opts.on( '-c', '--config file', 'YAML config file') do |path|
          @options.config_file = path
        end

        opts.on( '', '--headless', 'Do not start browser UI instance') do
          @options.headless = true
        end  

        opts.on( '-h', '--host ip', 'Host name/IP for Httpd') do |str|
          @options.host = str
        end

        opts.on( '-p', '--port num', 'Port number for Httpd') do |num|
          @options.port = Integer(num)
        end

        opts.on( '-s', '--start url', 'Startup page (path)') do |url|
          @options.start_uri = url
        end

        opts.on( '', '--create', 'Create new repo',
                 'Open Create Repo page in browser',
                 'NOTE: This is incompatible with --start') do 
          @options.start_uri = '/app/create'
        end

        opts.on( '', '--debug', 'Write debug messages to log') do
          @options.debug = true
        end

        opts.on('', '--no-java', 'Do not start JRuby process') do 
          @options.disable_java = true
        end

        opts.on('', '--no-jruby', 'Alias for --no-java') do 
          @options.disable_java = true
        end

        opts.on('', '--no-plugins', 'Do not start PluginManager') do 
          @options.disable_plugins = true
        end

        opts.on('', '--no-vcs', 'Do not use version control') do 
          @options.disable_vcs = true
        end
        opts.on('', '--no-git', 'Alias for --no-vcs') do 
          @options.disable_vcs = true
        end

        opts.on('', '--no-db', 'Do not start DatabaseManager') do 
          @options.disable_db = true
        end

        opts.on('', '--no-autosave', 'Do not save repo on exit') do
          @options.autosave = false
        end

        opts.on('', '--readonly', 'Do not write changes to repo') do
          @options.readonly = true
        end
        opts.on('', '--ro', 'Do not write changes to repo') do
          @options.readonly = true
        end

        opts.on('', '--root dir', 'Root dir containing repos',
                'Repo open/create will be limited to directories',
                'under dir. Default: User home dir.',
                'NOTE: repos specified on command line are exempt',
                'from this restriction.') do |dir|
          @options.repo_root = dir
        end

        opts.on('-1', '--single-process', 
                'Do not start worker processes like Jruby') do
          @options.disable_java = true
        end

        opts.on_tail('-?', '--help', 'Show help screen') { puts opts; exit 1 }
        opts.on_tail('-v', '--version', 'Show version info') do
          puts 'Version: ' + PlanR::VERSION
          exit 2
        end 
      end

      opts.parse!(args)
      @options.repo  = args.shift
    end

    def exec
      begin
          #start webapp in webrick server
          @server = PlanR::Application::LocalHttpd::Server.new(@options.host, 
                                                               @options.port, 
                                                               @options)
        if(! running? )
          @server.start
          write_pid_file(@server.pid)
          sleep(0.1) # sleep for a few ms to give server a chance to spin up
        end

        # open browser
        if (! @options.headless)
          PlanR::Application::LocalHttpd::Browser.open(start_uri, 
                                                       @options.browser, @debug)
        end

        if (@server and @server.pid)
          Process.waitpid(@server.pid)
          remove_pid_file
        end
      rescue Exception => e
        $stderr.puts "#{self.class.name} Caught exception: #{e.message}"
        $stderr.puts e.backtrace[0,30].join("\n")
      ensure
        self.cleanup
      end
    end

=begin rdoc
Clean up application and framework before exit.
Applications should invoke this in fatal exception handlers.
=end
    def cleanup
      # Nothing to do!
    end


    # ----------------------------------------------------------------------
=begin rdoc
Return start URL for browser. The URL is built from the server settings and 
the start_uri option.
=end
    def start_uri
      uri = @server.uri.dup
      path = @options.start_uri
      path = '/' + path if (! path.start_with? '/')
      uri.path = path
      uri
    end

=begin rdoc
Return true if runtime PID file exists, and PID is valid.
=end
    def running?
      # PID file is stored in repo, as instances are repo-specific.
      return false if (! @options.repo)
      pid = read_pid_file()
      return false if (! pid) or (pid == 0)
      process_running? pid
    end

    def read_pid_file
      pidf = pid_file()
      return nil if (! pidf) or (! File.exist? pidf)
      buf = File.read(pidf)
      Integer(buf.lines.first.strip)
    end

    def write_pid_file(pid)
      return if (! pid)
      pidf = pid_file()
      return if (! pidf)
      File.open(pidf, 'w') { |f| f.puts pid.to_s }
    end

    def remove_pid_file
      pidf = pid_file()
      return if (! pidf)
      File.unlink(pidf)
    end

    def pid_file
      return nil if (! @options.repo) or (! File.exists?(@options.repo))
      repo = PlanR::Repo.new(@options.repo)
      return nil if (! repo)
      File.join(repo.runtime_dir, PID_FILE)
    end

    def process_running?(pid)
      begin
        Process.kill(0, pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        # either doesn't exist, or not ours
        false
      rescue Exception
        # who knows?
        true
      end
    end

  end
end
