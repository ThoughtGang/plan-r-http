#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::HTMLArea
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JqueryHtmlArea
        extend TG::Plugin
        name 'Jquery HtmlArea'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'JQuery-HtmlArea HTML editor'
        help 'Webapp document viewer plugin for editing HTML and plaintext.'

        def generate_viewer(css_ident, opts={})
          { :name => 'html editor',
            :i18n_label => :html,
            :css_ident => css_ident,
            :css => ['/css/jHtmlArea.css'],
            :js => ['/js/jHtmlArea.min.js'],
            :node_types => [:document],
            # TODO: XML? XHTML?
            :mime_types => ['text/html'],

            :init => "",

            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<textarea></textarea>');
              $('#{css_ident} > textarea').val(contents_ascii);
              $('#{css_ident} > textarea').width('#{opts[:width] || 800}');
              $('#{css_ident} > textarea').height('#{opts[:height] || 600}');
              $('#{css_ident} > textarea').htmlarea({
                /* FIXME: more complete toolbar */
                toolbar: ['html', '|', 'forecolor', '|', 
                          'bold', 'italic', 'underline', '|', 
                          'h1', 'h2', 'h3', '|', 'link', 'unlink'] 
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
