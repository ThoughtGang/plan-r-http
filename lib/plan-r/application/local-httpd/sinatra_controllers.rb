#!/usr/bin/env ruby
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Controllers for Sinatra Plan-R webapp

module PlanR
  module Application
    module LocalHttpd

      class WebApp < Sinatra::Base
        Doc = PlanR::Document
        DocMgr = PlanR::Application::DocumentManager

        # website icon
        get "/favicon.ico" do
          redirect PLAN_R_LOGO
        end

        # welcome screen
        get "/" do
          haml :root
        end

=begin rdoc
Open a repository.
=end
        get '/app/open' do
          @page_title = t.app.open_title
          haml :select_repo
        end

        post '/app/open' do
          @page_title = t.app.open_title
          
          dir = params['repo_path']
          if (! File.exist? dir) or (! File.directory? dir)
            raise "Not a Repo directory: #{dir}"
          end

          if (! PlanR::Repo.is_repo? dir)
            # user may have selected file-in-repo by accident
            pdir = File.dirname(dir)
            if (PlanR::Repo.is_repo? File.dirname(dir))
              dir = pdir
            else
              raise "Not a Plan-R Repo: #{dir}"
            end
          end

          self.repo=(dir)

          # FIXME: if ! exist: flash error and return to open

          #redirect(session[:return_to]) if session[:return_to]
          redirect '/repo'
        end

=begin rdoc
Create a repository.
=end
        get '/app/create' do
          @page_title = t.app.create_title
          haml :create_repo
        end

        post '/app/create' do
          @page_title = t.app.create_title
          dir = params['repo_loc']
          if (! File.exist? dir) or (! File.directory? dir)
            raise "Not a directory: #{dir}"
          end
          repo_dir = params['repo_dir']
          if (! repo_dir) or (repo_dir.empty?)
            raise "No repo name specified!"
          end
          repo_path = File.join(dir, repo_dir)
          name = (params.include? 'name' ) ? params['name'] : 'Untitled'
          descr = (params.include? 'descr' ) ? params['descr'] : 'Untitled Repo'
          git = (params['version_control'] == 'on')
          # TODO: author, license

          props = { :description => descr,
                    :create_app => 'HTTPD /app/create' }
          repo = PlanR::Application::RepoManager.create(name, repo_path, props, git)
          self.repo=(repo_path)

          redirect '/repo'
        end

=begin rdoc
Generate a .desktop file for the current instance and repository. This allows
the app to be run with a fixed port on a per-repository basis.
=end
        get '/app/desktop-file' do
          # FIXME: use a real error
          return 'No repo open' if (! @repo)
          # FIXME: ensure UTF-8 encoding
          content_type 'application/x-desktop'
          # FIXME: $0 is broken if path is relative
          # FIXME: send proposed filename!
          # FIXME: handle other commandline options (browser, RO, autosave)
          "[Desktop Entry]
Encoding=UTF-8
Name=#{t.plan_r} (#{@repo.name})
Comment=#{@repo.description}
Exec=#{$0} -h #{request.host} -p #{request.port} #{@repo.base_path}
Icon=#{File.join(STATIC_DIR, PLAN_R_LOGO)}
Type=Application
Terminal=false
Categories=Office;
"
        end

=begin rdoc
Show PluginManager page.
=end
        get '/app/plugins' do
          @page_title = t.plugins_title
          haml :plugin_manager
        end

=begin rdoc
Show Settings page.
=end
        get '/app/settings' do
          @page_title = t.settings_title
          haml :settings_main
        end

=begin rdoc
Show Help page.
=end
        get '/app/help' do
          @page_title = t.help_title
          haml :help_main
        end

=begin rdoc
Quit the application.
=end
        get '/app/quit' do
          # FIXME: this should be a single controller which shows a dialog
          #        to confirm and invoked quit! if confirmed.
          @page_title = t.quit_title
          haml :quit
        end
        post '/app/quit' do
          quit!
          haml :goodbye
        end

        # ----------------------------------------------------------------------
        # REPO BROWSER
        
        get '/repo' do
          # FIXME: repo management page? properties, refresh, re-index, stats
          redirect '/repo/browse/all/'
        end

        get '/repo/browse' do
          redirect '/repo/browse/all/'
        end

=begin rdoc
This is the main application page.
It has two columns. The leftmost column contains the RepoTree (used to navigate
the Repo) and the Document Info pane. The main (center/rightmost) column 
contains the RepoTable (the contents of the current directory) and the 
Document Viewer (a tab widget of doc_viewer plugins which display the contents
of the current document). The current document is selected in the RepoTable
or, if the RepoTable is empty (i.e. user has navigated to a document not a
directory), in the RepoTree.
Note: 
=end
        get '/repo/browse/:ctype/*' do
          ctype, doc_path = doc_ident_from_params(params, 'all')
          @current_doc = nil
          if (doc_mgr.doc_exist? @repo, doc_path, ctype)
            @current_doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          end
          @current_repo_path = doc_path
          @page_title = doc_path # FIXME: better title
          # NOTE: These ensure that properties and tags for directories 
          #       can be viewed
          @current_tags = @repo.tags(doc_path, ctype) || []
          @current_props = @repo.properties(doc_path, ctype) || {}

          haml :browser
        end

=begin rdoc
Ajax callback for RepoTree generation.

JSTree node format:
{
  id          : "string" // will be autogenerated if omitted
  text        : "string" // node text
  icon        : "string" // string for custom
  state       : {
    opened    : boolean  // is the node open
    disabled  : boolean  // is the node disabled
    selected  : boolean  // is the node selected
  },
  children    : []  // array of strings or objects
  li_attr     : {}  // attributes for the generated LI node
  a_attr      : {}  // attributes for the generated A node
}
=end
        get '/api/repo/browser/tree' do
          if request.xhr? 
            ident = params['id']
            type = nil
            dir = nil
            if ident == '#'
              type = :all
              dir = '/'
            else
              type = params['type'].to_sym
              jnk, dir = ident.split('/', 2)
            end
            dir = '/' + dir if (! dir.start_with? '/')
            arr = []
            doc_mgr.lookup(@repo, dir, false, true, true).each do |t,p|
              has_children = (t == :folder)
              props = {}
              title = p
              data = {
                'origin' => nil,
                'mime_type' => 'application/octet-stream'
              }

              if (t != :folder )
                doc = doc_mgr.doc_factory(@repo, p, t)
                has_children = doc.has_children?
                title = doc.title
                title = "[#{t}] #{p}" if (! title) or (title.empty?)
                mtype = doc.mime_type
                data['mime_type'] = mtype if mtype and (! mtype.empty?)
                data['origin'] = props['origin']
              end

              # TODO: override icon based on mime-type?
              arr << { 'id' => p, 'text' => File.basename(p),
                       'data' => data, 'children' => has_children, 
                       # A-elem attributes. used to override tooltip.
                       'a_attr' => { 'title' => title }, 'type' => t.to_s }
            end
            json arr
          else
            # FIXME: ERROR
            ''
          end
        end

=begin rdoc
List of all tags for auto-completion.
=end
        get '/api/repo/available-tags' do
          json doc_mgr.known_tags(@repo)
        end

=begin rdoc
Return JSON-serialized metadata (e.g. Properties, Tags, etc) of a document in 
the Repo.
=end
        get '/api/doc/metadata/:ctype/*' do
          if request.xhr? 
            ctype, doc_path = doc_ident_from_params(params, 'document')
            props = @repo.properties(doc_path, ctype) || {}
            tags = @repo.tags(doc_path, ctype) || []
            rv = { 'properties' => props, 'tags' => tags }
            json rv
          else
            # FIXME: ERROR
            ''
          end
        end

=begin rdoc
Return raw contents of a document in the Repo.
This will set the content type based on document properties.
=end
        get '/api/doc/contents/:ctype/*' do
          ctype, doc_path = doc_ident_from_params(params, 'document')
          # FIXME: docs with resources are considered children?
          return ('') if ctype == 'folder'

          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return '' if (! doc) # FIXME: better error handling

          mime_type = doc.mime_type
          if (! mime_type) or (mime_type.empty?)
            if doc.ascii?
              mime_type = 'text/plain'
            else
              mime_type = 'application/octet-stream'
            end
          end
          send_file doc.abs_path, :filename => File.basename(doc.path), 
                    :type => mime_type, :disposition => :inline
        end

=begin rdoc
Return ASCII contents of a document in the Repo. If document is not ASCII,
this will return an empty string. This basically makes it safe to display
a non-ASCII document in an ASCII-only viewer.
=end
        get '/api/doc/ascii_contents/:ctype/*' do
          ctype, doc_path = doc_ident_from_params(params, 'document')
          return ('') if ctype == 'folder'
          ctype = :document if (ctype.empty?)
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          txt = (doc and doc.ascii?) ? doc.raw_contents : ''
          content_type :text
          txt
        end

=begin rdoc
Returns a URI for the absolute path to the document contents.
=end
        get '/api/doc/content_uri/:ctype/*' do
          if request.xhr? 
            ctype, doc_path = doc_ident_from_params(params, 'document')
            return ('') if ctype == 'folder'

            # FIXME: better error handling
            ctype = :document if (ctype.empty?)
            doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
            return '' if (! doc)

            'file://' + doc.abs_path
          else
            # FIXME: ERROR
            ''
          end
        end

=begin rdoc
Add specified tag to Document.
=end
        post '/api/doc/add_tag/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR
          tag = params['tag']
          doc.tag(tag) if tag and (! tag.empty?)
        end

=begin rdoc
Remove specified tag from Document.
=end
        post '/api/doc/remove_tag/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR
          tag = params['tag']
          doc.untag(tag) if tag and (! tag.empty?)
        end

=begin rdoc
Add, modify, or remove specified property from document.
If params does not include 'value', property will be deleted.
=end
        post '/api/doc/set_property/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR
          props = doc.properties
          name = params['name']
          return if (! name) or (name.empty?)

          if (! params.include? 'value')  # delete item if value is not provided
            return if (! props.include? name)
            props.delete name
          else
            props[name] = params['value']
          end

          doc.properties = props
        end

=begin rdoc
Move document to specified location in Repo.
=end
        post '/api/doc/move/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          dest = params['dest']
          overwrite = params['overwrite']
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR
          doc_mgr.move(doc, dest, true, overwrite)
        end

=begin rdoc
Copy document to specified location in Repo.
=end
        post '/api/doc/copy/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          dest = params['dest']
          overwrite = params['overwrite']
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR
          doc_mgr.copy(doc, dest, true, overwrite)
        end

=begin rdoc
Duplicate document in repo. This autogenerates a filename, e.g. 
"Copy of $DOCUMENT 1". The duplicate will be in the same directory as the
original.
=end
        post '/api/doc/dup/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR

          new_name = t.repo.copy_of + ' ' + File.basename(doc_path)
          loc = File.dirname(doc_path)
          counter = 1
          new_name = "#{new_name} (#{counter})"
          while (@repo.exist?(File.join(loc, new_name), ctype)) do
            counter += 1
            new_name = "#{new_name} (#{counter})"
          end
        end

=begin rdoc
Create a new document of the appropriate type at specified location in Repo.
=end
        post '/api/doc/new/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          if (ctype == 'folder')
            @repo.mkdir(doc_path)
            return
          end

          content = (params.include? 'content') ? params['content'] : ''
          props = doc_mgr.default_properties(ctype)
          if (params.include? 'properties')
            begin
              param_props = JSON.parse(params['properties'])
              raise "Not a Hash!" if (! param_props.kind_of? Hash)
              if (params['merge_properties'])
                props.merge! param_props
              else
                props = param_props
              end
            rescue Exception => e
              param_props = {}
            end
          end

          doc_mgr.new_file(@repo, ctype, doc_path, contents, props)
        end

=begin rdoc
Delete specified document and all of its children.
=end
        post '/api/doc/delete/:ctype/*' do
          return if @readonly
          ctype, doc_path = doc_ident_from_params(params, 'document')
          doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          return if (! doc) # FIXME: ERROR

          doc_mgr.remove( doc, true );
        end

=begin rdoc
Download specified document via browser. If document is a directory, it will
be downloaded as a tarball (*.tar.gz).
This sets the content-type based on document properties, and sets
content-disposition to file.
=end
        get '/api/doc/download/:ctype/*' do
          ctype, doc_path = doc_ident_from_params(params, 'document')
          return if (ctype == 'folder') # TODO: error
          # get contents as file or tarball
          #doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          #return '' if (! doc)
          #'file://' + doc.abs_path
          'TODO'
        end

=begin rdoc
View specified document in the browser.
This sets the content-type based on document properties.
Has no effect for folders.
=end
        get '/api/doc/view/:ctype/*' do
          ctype, doc_path = doc_ident_from_params(params, 'document')
          return if (ctype == 'folder') # TODO: error

          # get contents 
          #doc = doc_mgr.doc_factory(@repo, doc_path, ctype)
          #return '' if (! doc)
          #'file://' + doc.abs_path
          'TODO'
        end

        # ----------------------------------------------------------------------
        # REPO IMPORT

=begin rdoc
Import document from specified URL. The URL can be an internet address or a
local file ("file:///path/to/file").
This is a backend for the import_url form.
=end
        get '/app/import_url' do
          @page_title = t.app.import_url.title
          # FIXME: settings
          haml :import_url
        end
        post '/app/import_url' do
          @page_title = t.app.import_url.title

          doc_name = params['name'] || ''
          dir = params['folder'] || ''
          # FIXME: add to recent location
          path = File.join(dir, doc_name) # default will be '/'

          uri = params['uri']
          if (! uri) or (uri.empty?)
            # FIXME: real loggging
            $stderr.puts "ERROR: IMPORT URI IS EMPTY"
            next haml :import_url
          end

          index = ((params['index'] || 1).to_i > 0)
          orphan = ((params['orphan'] || 0).to_i > 0)
          sync = case params['sync']
                 when 'auto'
                   DocMgr::SYNC_AUTO
                 when 'access'
                   DocMgr::SYNC_ACCESS
                 when 'start'
                   DocMgr::SYNC_START
                 when 'manual'
                   DocMgr::SYNC_MANUAL
                 else
                   DocMgr::SYNC_AUTO
                 end
          sync_method = ((params['append'] || '0').to_i > 0) ?
                          DocMgr::SYNC_APPEND : DocMgr::SYNC_REPLACE
          cache = ((params['cache'] || '1').to_i > 0)

          # FIXME: plugins?
          imp_opts = DocMgr::SyncOptions.new(sync,
                                   sync_method, nil, nil, orphan, cache, index)
          doc = doc_mgr.import(@repo, uri, path, imp_opts)
          props = {}
          if ((params['comment'] || '').empty?)
            doc.properties[Doc::PROP_COMMENT] = params['comment']
          end

          if ((params['note'] || '0').to_i > 0)
            doc_mgr.new_file(@repo, :note, path, params['note_content'])
          end

          flash[:confirm] = t.flash_confirm(path)
          # re-display add_note page (Note creation loop)
          haml :import_url
        end

=begin rdoc
Create a Note in the repository. This is a backend for the add_note form.
=end
        get '/app/add_note' do
          @page_title = t.app.add_note.title
          # FIXME: default location (from config)
          #        default name NOTE 00001.succ
          haml :add_note
        end
        post '/app/add_note' do
          @page_title = t.app.add_note.title

          doc_name = params['name'] # || default
          dir = params['folder'] # || default
          # FIXME: add to recent location
          path = File.join(dir, doc_name)

          contents = params['contents'] || ''
          # FIXME: create_app_string(url)
          creator = params['create-app'] || 'HTTPD /app/add_note'
          props = {} # create-app ?

          doc = doc_mgr.new_file(@repo, :note, path, contents, props)

          # re-display add_note page (Note creation loop)
          # FIXME: flash message
          # FIXME: redirect to GET: /app/add_note
          haml :add_note
        end

        # ----------------------------------------------------------------------
        # REPO SEARCH

=begin rdoc
Perform a search on the repository indexes. This is a backend for the search 
form.
=end

        get '/app/search' do
          @page_title = t.app.search.title
          # FIXME: for each search plugin, provide widget
          haml :search
        end
        post '/app/search/results' do
          @page_title = t.app.search_results_title
          query = params['query'] || ''
          # FIXME: real error handling
          return '' if query.strip.empty?
          sep = params['sep'] || ''
          sep = ' ' if sep.empty?

          p_key = params['search_engine']
          p_key = nil if p_key == 'all'
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          # FIXME: support quoting of query
          q = PlanR::Query.new(query.split(sep))
          q.raw_query = query
          @results = PlanR::Application::QueryManager.perform(@repo, q, p_name)
          haml :search_results
        end

=begin rdoc
Index debugging: list documents indexed by search plugin.
=end
        get '/app/search/documents/:plugin' do
          @page_title = t.search.index_docs_title
          p_key = params['plugin']
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          @results = PlanR::Application::QueryManager.index_docs(@repo, {}, 
                                                                 p_name)
          haml :search_index_docs
        end

=begin rdoc
Index debugging: show index log for search plugin.
=end
        get '/app/search/log/:plugin' do
          @page_title = t.search.index_log_title
          p_key = params['plugin']
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          @results = PlanR::Application::QueryManager.index_log(@repo, {}, 
                                                                p_name)
          haml :search_index_log
        end

=begin rdoc
Index debugging: show index report for search plugin.
=end
        get '/app/search/report/:plugin' do
          @page_title = t.search.index_report_title
          p_key = params['plugin']
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          @results = PlanR::Application::QueryManager.index_report(@repo, {}, 
                                                                   p_name)
          haml :search_index_report
        end

=begin rdoc
Index debugging: show index stats for search plugin.
=end
        get '/app/search/stats/:plugin' do
          @page_title = t.search.index_stats_title
          p_key = params['plugin']
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          @results = PlanR::Application::QueryManager.index_stats(@repo, {}, 
                                                                  p_name)
          haml :search_index_stats
        end

=begin rdoc
Index debugging: list all keywords indexed by search plugin.
=end
        get '/app/search/keywords/:plugin' do
          @page_title = t.search.index_keywords_title
          p_key = params['plugin']
          p_name = p_key ? plugin_key_to_name(p_key) : nil
          @results = PlanR::Application::QueryManager.index_keywords(@repo, {}, 
                                                                 p_name)
          haml :search_index_keywords
        end

        # ----------------------------------------------------------------------
        # REPO OPEN/CREATE

=begin rdoc
List files in specified directory. This is not constrained by a repo, but it
*is* constrained by @repo_root (which is $HOME unless overridden by the user).
=end
        get '/api/fs/tree' do
          if request.xhr? 
            dir = params['id']
            dir = @repo_root if (dir == '#' or dir.empty?)
            raise ("Invalid path #{dir}") if (! dir.start_with? @repo_root)
            dir = File.expand_path(dir)
            entries = []
            if (File.directory? dir)
              Dir.entries(dir).each do |ent|
                next if (ent == '.' or ent == '..')
                next if (ent == 'lost+found')
                next if ( ent == '.DS_Store' or ent == '._.DS_Store')
                path = File.join(dir, ent)
                next if File.socket? path
                has_children = (File.directory? path) &&
                               (Dir.entries(path).count > 0)
                entries << { 'id' => path, 'text' => ent,
                             'children' => has_children,
                             'icon' => '/images/' + 
                                       (has_children ? 'folder_closed' : 'file'
                                       ) + '.png' }
              end
            end

            json entries
          else
            # FIXME: ERROR
            ''
          end
        end

      end

    end
  end
end
