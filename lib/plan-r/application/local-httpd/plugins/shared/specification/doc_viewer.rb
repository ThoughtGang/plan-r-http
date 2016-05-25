#!/usr/bin/env ruby
# :title: PlanR::Plugin::Specification::DocViewer
=begin rdoc
Specifications for JS Document Viewer plugins

(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'


module PlanR
  module Plugin
    module Spec

      # ----------------------------------------------------------------------
      # DOCUMENT VIEWER
      # Input: A string containing the CSS ID of the element which will
      # become the viewer, and a Hash of options.
      # Output: A Hash containing the following keys:
      #   :css        : Array of required CSS filenames
      #   :js         : Array of required JS filenames
      #   :node_types : Supported Plan-R content node types
      #   :mime_types : Supported MIME-types
      #   :init       : Javascript code to instantiate the viewer
      #   :load_doc   : Javascript code defining a function of the type
      #                 fn(doc_type, doc_path, contents_ascii, contents_raw)
      # Possible input options:
      #   height
      #   weight
      #   on_edit     : Javascript function to call on edit
      TG::Plugin::Specification.new( :js_doc_viewer, 'fn(String ident, Hash)',
                                     [String, Hash], [Hash] 
                                   )

      # TODO: search result viewer (table, graph)
    end
  end
end
