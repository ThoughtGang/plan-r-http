#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::Ace
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JqueryAce
        extend TG::Plugin
        name 'Jquery Ace'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'ACE syntax-highlighting text editor'
        help 'Webapp plugin for ACE javascript text editor.'

        def generate_viewer(css_ident, opts={})
          { :name => 'text editor',
            :i18n_label => :text,
            :css_ident => css_ident,
            :css => [],
            :js => ['/js/ace/ace.js'],
            :node_types => [], # all
            :mime_types => [], # N/A

            :init => "",

            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<div id=\"ace-doc-viewer\"></div>');
              $('#ace-doc-viewer').width('#{opts[:width] || 800}');
              $('#ace-doc-viewer').height('#{opts[:height] || 600}');
              var editor = ace.edit('ace-doc-viewer');
              editor.setTheme('ace/theme/monokai');
              //FIXME: button for syntax
              //editor.getSession().setMode('ace/mode/javascript');
              editor.setValue(contents_ascii);
              editor.resize();
            }
            "
          }
        end
        spec :js_doc_viewer, :generate_viewer, 70

      end

    end
  end
end
