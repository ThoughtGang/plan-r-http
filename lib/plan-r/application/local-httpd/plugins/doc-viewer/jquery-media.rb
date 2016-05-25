#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::media
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JqueryMedia
        extend TG::Plugin
        name 'Jquery Media'
        author 'dev@thoughtgang.org'
        version '0.5'
        description 'JQuery-Media Viewer for images, videos, PDFs, HTML'
        help 'Webapp document viewer plugin for the Jquery Media widget.'

        def generate_viewer(css_ident, opts={})
          { :name => 'media viewer',
            :i18n_label => :media,
            :css_ident => css_ident,
            :css => [],
            :js => ['/js/jquery.media.js'],
            :node_types => [:document],
            :mime_types => [],

            :init => "",
            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              var url = '/api/doc/contents/' + doc_type + doc_path;
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<a class=\"media\" href=\"' + url + '\"></a>');
              $('#{css_ident} > a').media({
                width: '#{opts[:width] || '100%'}',
                height: '#{opts[:height] || '100%'}'
              });
            }
            "
          }
         
          # jquery-media options
          # autoplay:  true,
          # src:       'myBetterMovie.mov',
          # attrs:     { attr1:  'attrValue1',  attr2:  'attrValue2' },  // object embed attrs
          # params:    { param1: 'paramValue1', param2: 'paramValue2' }, // object params/embed attrs
          #caption:   false // supress caption text
        end
        spec :js_doc_viewer, :generate_viewer, 70

      end

    end
  end
end
