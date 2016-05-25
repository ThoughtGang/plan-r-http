#!/usr/bin/env ruby
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'uri'
require 'socket'
require 'webrick'

require 'plan-r/application/local-httpd/sinatra_app'

module PlanR
  module Application
    module LocalHttpd

=begin rdoc
A rewrite of Rack::Handler::WEBrick which allows arguments to be passed to
the webapp class constructor.

NOTE: This isn't the whole story. Sinatra::Base still needs a supporting
factory method (create_instance) and possibly a prototype() override.
=end
      class Servlet < ::WEBrick::HTTPServlet::AbstractServlet

        def self.shutdown
          @server.shutdown
          @server = nil
        end

        def initialize(server, *args)
          super server
          args = args.flatten
          @app = args.shift
          # pass hash of application arguments to application instance
          # this stores 'args' for use in creating prototypes
          @app.webrick = server
          @app.create_instance( args.shift || {} )
        end

        def service(req, res)
          env = req.meta_vars
          env.delete_if { |k, v| v.nil? }

          rack_input = StringIO.new(req.body.to_s)
          rack_input.set_encoding(Encoding::BINARY)

          # Sinatra seems to expect only rack.input and rack.errors
          env.update( { 'rack.input' => rack_input, 'rack.errors' => $stderr } )

          env['HTTP_VERSION'] ||= env['SERVER_PROTOCOL']
          env['QUERY_STRING'] ||= ""
          unless env['PATH_INFO'] == ""
            path, n = req.request_uri.path, env['SCRIPT_NAME'].length
            env['PATH_INFO'] = path[n, path.length-n]
          end
          env['REQUEST_PATH'] ||= [env['SCRIPT_NAME'], env['PATH_INFO']].join

          status, headers, body = @app.call(env)
          begin
            res.status = status.to_i
            headers.each { |k, vs|
              if k.downcase == "set-cookie"
                res.cookies.concat vs.split("\n")
              else
                res[k] = vs.split("\n").join(", ")
              end
            }

            if body.respond_to?(:to_path)
              res.body = ::File.open(body.to_path, 'rb')
            else
              body.each { |part|
                res.body << part
              }
            end
          ensure
            body.close  if body.respond_to? :close
          end
        end
      end

=begin rdoc
Object to start and manage a Webrick process.
See PlanR::HttpApplication for what the @options Hash can contain.
=end
      class Server
        attr_reader :host, :port, :pid, :webrick, :uri, :options

        def initialize(host=nil, port=nil, opts)
          @port = port || get_avail_port(host)
          @host = host || 'localhost' 
          @uri = URI::HTTP.build( {:host => @host, :port => @port} )
          @options = opts
          @debug = opts.debug
        end

=begin rdoc
Fork and start a Webrick instance running the LocalHttpd::WebApp application.
=end
        def start
          @pid = Process.fork do
            if (@options.rack) 
              # NOTE: This does not support command-line setting of repo!
              opts = { :server => :webrick, :host => @host, :port => @port}
              PlanR::Application::LocalHttpd::WebApp.run!( repo, opts ) 
            else
              # rack doesn't do the one thing we need it to: 
              # pass WebApp instantiation arguments to Webrick.mount
              opts = { :BindAddress => @host, :Port => @port}
              @webrick = ::WEBrick::HTTPServer.new(opts)
              @webrick.mount "/", Servlet,
                            [ PlanR::Application::LocalHttpd::WebApp, 
                              @options ]
              @webrick.start
            end
          end

          trap('INT') { Process.kill 'INT', @pid }
          trap('TERM') { Process.kill 'INT', @pid }

          self
        end

=begin rdoc
Stop the Server process. In the controlling process, this kills the server
PID. In the server process, this invokes Webrick#shutdown.
=end
        def stop
          # use pid in controlling process, webrick in server process
          @webrick.shutdown if @webrick
          Process.kill('INT', @pid) if @pid
        end

        private

        # return next available port for webrick to listen on
        def get_avail_port(host)
          host ||= (Socket::gethostbyname('')||['localhost'])[0]

          infos = Socket::getaddrinfo(host, nil, Socket::AF_UNSPEC,
                                      Socket::SOCK_STREAM, 0, 
                                      Socket::AI_PASSIVE)
          fam = infos.inject({}) { |h, arr| h[arr[0]]= arr[2]; h }
          sock_host = fam['AF_INET'] || fam['AF_INET6']

          sock = sock_host ? TCPServer.open(sock_host, 0) : TCPServer.open(0)
          port = sock.addr[1]
          sock.close

          port
        end
      end

    end
  end
end
