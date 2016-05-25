#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::HexDump
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class HexDump
        extend TG::Plugin
        name 'JS Hex Dump'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'Displays a read-only hex dump of any repo document'
        help 'Webapp vieer plugin that displays a hexdump of any Document.
Note: This is a catch-all viewer: it can display documents that are not
specifically supported by any document viewer plugin.'

        def generate_viewer(css_ident, opts={})
          { :name => 'hex dump',
            :i18n_label => :hex,
            :css_ident => css_ident,
            :css => [],
            :js => ['/js/hexdump.js'],
            :node_types => [], # all
            :mime_types => [], # all

            :init => "",

            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<pre class=\"text-fixed\"></pre>');
              $('#{css_ident} > pre').text($.fn.hexdump(contents_raw));
            }
            "
          }
        end
        spec :js_doc_viewer, :generate_viewer, 70

      end

    end
  end
end
