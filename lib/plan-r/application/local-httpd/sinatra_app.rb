#!/usr/bin/env ruby
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'sass'
require 'haml'

require 'sinatra/base'
require 'sinatra/r18n'
require 'sinatra/flash'
require "sinatra/json"

require 'plan-r/version'
require 'plan-r/application'

module PlanR
  module Application
    module LocalHttpd

=begin rdoc
Sinatra-based web application for Plan-R.
=end
      class WebApp < Sinatra::Base

        attr_reader :repo             # PlanR::Repo in use by app 
        # configuration options:
        attr_reader :readonly         # repo is read-only
        attr_reader :autosave         # automatically save Repo on close
        attr_reader :repo_root        # sort of a chroot for repo open/create

        NAME = 'Plan-R Browser App'
        CONFIG_DOMAIN = 'plan-r-local-httpd'
        HAML_DIR = File.join(File.dirname(__FILE__), 'views')
        STATIC_DIR = File.join(File.dirname(__FILE__), 'static_content')
        PLAN_R_LOGO = File.join('images', 'PlanR.png')
        OPEN_REPO_PATH = '/app/open'
        # Default location of repositiories
        OPEN_REPO_ROOT = Dir.home
        # HTTPD-specific plugins
        PLUGIN_BASE_DIR = File.join(File.dirname(__FILE__), 'plugins')
        PLUGIN_SPEC_DIR = File.join(File.dirname(__FILE__), 'plugins',
                                    'shared', 'specification')

        def initialize(args={})
          @app = nil # disable downstream apps
          @repo = self.class.repo
          read_options args
          super 
        end

        # Set options for main webapp instance
        def self.create_instance(args={})
          read_options args
          start_planr_services(args)
          @prototype_args = args.dup
        end

        def self.webrick=(server)
          @webrick = server
        end

        def self.repo=(repo)
          @repo = repo
        end

        def self.repo
          @repo
        end

        def route_missing
          raise ::Sinatra::NotFound
        end

        # ----------------------------------------------------------------------
        # PLAN-R SERVICES
        def self.start_planr_services(opts={})
          return if @planr_services_started
          $stderr.puts '[PLAN-R-WEBAPP] Starting Plan-R services'

          # NOTE: This just enables plugins, it does not acutally start them
          # FIXME: this should use syms instead of names
          start_planr_service(PlanR::Application::ConfigManager)
          start_planr_service(PlanR::Application::JRuby, @disable_java)
          start_planr_service(PlanR::Application::RevisionControl, @disable_vcs)
          start_planr_service(PlanR::Application::DatabaseManager, @disable_db)
          start_planr_service(PlanR::Application::PluginManager, 
                              @disable_plugins)

          add_plugin_dirs unless @disable_plugins

          $stderr.puts '[PLAN-R-WEBAPP] Sending init msg to Plan-R services'
          PlanR::Application::Service.init_services

          $stderr.puts '[PLAN-R-WEBAPP] Sending startup msg to Plan-R services'
          PlanR::Application::Service.startup_services(self)

          @config = PlanR::Application::ConfigManager.read_config(CONFIG_DOMAIN)

          $stderr.puts '[PLAN-R-WEBAPP] Plan-R services started'
          @planr_services_started = true
        end

        def self.start_planr_service(sym, disabled=false)
          return if (disabled)
          $stderr.puts "[PLAN-R-WEBAPP] Starting service #{sym.to_s}"
          PlanR::Application::Service.enable(sym)
        end

        def self.stop_planr_services
          return if (! @planr_services_started)
          $stderr.puts '[PLAN-R-WEBAPP] Stopping Plan-R services'
          PlanR::Application::Service.shutdown_services(self)
        end

        def self.add_plugin_dirs
          PlanR::Application::PluginManager.add_plugin_dir(PLUGIN_BASE_DIR)
          PlanR::Application::PluginManager.add_spec_dir(PLUGIN_SPEC_DIR)
        end

        # override sinatra::Base#Prototype so we can pass options
        def self.prototype
          @prototype ||= self.new @prototype_args
        end

        def self.prototype_exist?
          @prototype != nil
        end

=begin rdoc
Access to PlanR PluginManager Service
=end
        def self.plugin_mgr
          PlanR::Application::PluginManager
        end
        def plugin_mgr; self.class.plugin_mgr; end

=begin rdoc
Access to PlanR DocumentManager Service
=end
        def self.doc_mgr
          PlanR::Application::DocumentManager
        end
        def doc_mgr; self.class.doc_mgr; end

=begin rdoc
Access to PlanR QueryManager Service
=end
        def self.query_mgr
          PlanR::Application::QueryManager
        end
        def query_mgr; self.class.query_mgr; end

=begin rdoc
Access to PlanR ScriptManager Service
=end
        def self.script_mgr
          PlanR::Application::ScriptManager
        end
        def script_mgr; self.class.script_mgr; end

        # ----------------------------------------------------------------------
        # RUNTIME CONFIGURATION
        def read_options(opts={})
          self.repo=(opts[:repo]) if (! @repo )
          @readonly = opts[:readonly]
          @repo_root = opts[:repo_root] || OPEN_REPO_ROOT
          @autosave = opts[:autosave] || false
        end

        def self.read_options(opts={})
          @config_file = opts.config
          @disable_java = opts.disable_java
          @disable_plugins = opts.disable_plugins
          @disable_vcs = opts.disable_vcs
          @disable_db = opts.disable_db
        end

        def repo=(str)
          return if (! str) 

          begin
            @repo = PlanR::Application::RepoManager.open(str)
            # This is to get around Sinatra's prototype/Wrapper nonsense
            self.class.repo = @repo if @repo
            if (self.class.prototype_exist? and 
                self.class.prototype.__id__ != self.__id__)
              self.class.prototype.helpers.set_repo_obj(@repo)
            end
          rescue Exception => e
            # FIXME : raise Application Exception
            #         so that app can display it
            $stderr.puts "Could not open repo '#{str}':"
            $stderr.puts e.message
            $stderr.puts e.backtrace[0,4].join("\n")
          end
        end

        # hack to allow repo to be set in prototype instance
        def set_repo_obj(repo)
          @repo = repo
        end

        def self.quit!()
          stop_planr_services
          super
          @webrick.shutdown if @webrick
        end

        def quit!
          PlanR::Application::RepoManager.close(@repo, @autosave) if @repo
          self.class.quit!
        end

        # ----------------------------------------------------------------------
        # CONFIG
        # parse-time configuration of web application
        configure do
          set :app_file, __FILE__
          set :app_name, NAME
          set :root, File.dirname(__FILE__)
          set :public_folder, STATIC_DIR
          set :views, HAML_DIR
          set :domain, 'localhost'
          set :environment, :development # :production
          #enable :logging
          enable :clean_trace
          set :haml, :format => :html5
          set :default_locale, 'en-US'
          enable :lock # use mutexes

          set :version, PlanR::VERSION
          #set :json_encoder, :to_json
          #set :json_content_type, :js
          enable :sessions # required for Flash Message
        end

        configure :development do
          enable :show_exceptions
          enable :dump_errors
          set :raise_errors, true 
        end

        configure :production do
          disable :show_exceptions
          set :raise_errors, Proc.new { false }
        end

        # ----------------------------------------------------------------------
        # SINATRA ADD-ON MODULES
        register Sinatra::R18n
        register Sinatra::Flash
        #helpers do
        #end

        # ----------------------------------------------------------------------
        # ERROR HANDLING
        not_found do
          'error'
        end

        error do
          env['sinatra_error']
        end

        # ----------------------------------------------------------------------
        # BEFORE/AFTER HANDLERS

        before '/repo/*'do
          session[:return_to] = request.path
$stderr.puts "BEFORE /REPO: #{@repo.class.name}"
          redirect(OPEN_REPO_PATH) if (! @repo)
        end

        # enable locales in session:
        before do
          session[:locale] = params[:locale] if params[:locale]
        end

        # ----------------------------------------------------------------------
        # HTML GENERATION

=begin rdoc
Render a partial HAML template. This is used to include a HAML template in
another HAML template.
If 'input' is a Symbol, it will be treated as the name of a view. If 'input'
is a String, it will be parsed as HAML code.
=end
        def partial(input, opts={})
          haml(input, opts.merge(:layout => false))
        end

=begin rdoc
Generate HAML code to link to a CSS stylesheet in static_content/css.
=end
        def include_css(filename)
          partial("%link{:rel=>'stylesheet', :href=>'/css/#{filename}'}")
        end

=begin rdoc
Generate HAML code to link to a Javascript file in static_content/js.
=end
        def include_js(filename)
          partial("%script{:type=>'text/javascript', :src=>'/js/#{filename}'}")
        end

=begin rdoc
Generate HAML code to render raw Javascript code in the document.
=end
        def raw_js( code )
          partial( ['%script{ :type => "text/javascript" }',
                    '  //<![CDATA[',
                    "  #{code}",
                    '  //]]>'].join("\n") )
        end

=begin rdoc
Convience method wrapping the html_escape HAML helper
=end
        def esc(str)
          html_escape(str)
        end

=begin rdoc
If str is not nil or '', return an HTML-escaped version.
Otherwise, return static_str (usually a translation)

NOTE: This assumes your static_str contains no HTML! Be careful!
=end
        def esc_or_static(str, static_str)
          str && (! str.strip.empty?) ? html_escape(str) : static_str
        end

        def page_title(str)
          title = @repo ? @repo.name : ''
          title = t.plan_r if (title.empty?)
          title = (title + '|' + str) if (str)
          html_escape(title)
        end

        # FIXME: obsolete
        def image_for_ctype(ctype)
          case ctype
          when :folder
            '/images/directory.png'
          when :document
            '/images/doc.png'
          when :dict
            '/images/db.png' # FIXME: need real icon
          when :note
            '/images/txt.png'
          when :script
            '/images/script.png'
          when :query
            '/images/html.png' # FIXME: need real icon
          when :table
            '/images/xls.png' # could also be db.png
          else
            '/images/file.png'
          end
        end

        def doc_type_str(doc)
          doc ? t[:doc][doc.node_type] : t.doc.folder
        end

        # search engine plugin name registry
        # FIXME: this is a total hack
        KNOWN_PLUGIN_KEYS = {
          'Tag Index' => 'tag',
          'Document Index' => 'doc'
        }

=begin rdoc
Return a plugin_name suitable for inclusion in a Hash key or a URL.
=end
        def plugin_name_to_key(str)
          key = KNOWN_PLUGIN_KEYS[str]
          if (! key)
            key = str.downcase.gsub(/[-( ]/, '_').gsub(/[^_[:alnum]]/, '')
            KNOWN_PLUGIN_KEYS[key] = str
          end
          key
        end

=begin rdoc
Return plugin name for key.
This will return nil if key is unrecognized.
=end
        def plugin_key_to_name(str)
          KNOWN_PLUGIN_KEYS.invert[str]
        end

=begin rdoc
Return a create_app property string for specified URL.
=end
        def create_app_string(url)
          'Plan-R LocalHttpd ' + url
        end

=begin rdoc
Retrieve document node_type and and path from query parameters (Hash).
=end
        def doc_ident_from_params(params, default_ctype='')
          ctype = (params['ctype'] || '').downcase.to_sym
          ctype = default_ctype if (! ctype) or (ctype.empty?)
          ctype = (ctype.empty?) ? nil : ctype.downcase.to_sym
          doc_path = ['', params['splat']].flatten.join('/')
          [ ctype, doc_path ]
        end

        VIEWER_ORDER = { :first => [ 'Jquery Media' ],
                         # don't care: 'Jquery Sheet'
                         :last => [ 'Jquery TE', 'JS Hex Dump' ] }

        def doc_viewers
          h = {}
          arr = plugin_mgr.providing(:js_doc_viewer).each {|p, r| h[p.name]=p}
          out_arr = []
          VIEWER_ORDER[:first].each { |n| out_arr << h[n] }
          h.keys.select { |n| (! VIEWER_ORDER[:first].include? n) and
                              (! VIEWER_ORDER[:last].include? n) 
                        }.sort.each { |n| out_arr << h[n] }
          VIEWER_ORDER[:last].each { |n| out_arr << h[n] }
          out_arr.compact
        end
      end

    end
  end
end

# load application controllers
require 'plan-r/application/local-httpd/sinatra_controllers'
