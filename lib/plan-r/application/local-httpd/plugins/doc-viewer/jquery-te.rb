#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::TE
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JqueryTE
        extend TG::Plugin
        name 'Jquery TE'
        author 'dev@thoughtgang.org'
        version '1.0'
        description 'JQuery-TE Rich Text editor'
        help 'Webapp document viewer plugin for Text and Rich Text editing. 
This is also used for editing Plan R note content nodes.'

        def generate_viewer(css_ident, opts={})
          { :name => 'rich text',
            :i18n_label => :richtext,
            :css_ident => css_ident,
            :css => ['/css/jquery-te.css'],
            :js => ['/js/jquery-te.min.js'],
            :node_types => [], # all
            :mime_types => [], # N/A

            :init => "",

            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<textarea></textarea>');
              $('#{css_ident} > textarea').val(contents_ascii);
              $('#{css_ident} > textarea').jqte({
                placeholder: 'Document is not plaintext'
              });
            }
            "
          }
        end
        spec :js_doc_viewer, :generate_viewer, 70

      end

    end
  end
end
