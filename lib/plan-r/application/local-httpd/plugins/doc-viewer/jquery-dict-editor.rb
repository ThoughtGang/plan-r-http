#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::dict
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JqueryDictEditor
        extend TG::Plugin
        name 'Jquery Dict Editor'
        author 'dev@thoughtgang.org'
        version '0.9'
        description 'Editor for Plan-R Dict documents'
        help 'Webapp document viewer for Plan-R Dict content nodes.'

        # FIXME: generate a widget shared with properties editor
        def generate_viewer(css_ident, opts={})
          { :name => 'dict editor',
            :i18n_label => :dict,
            :css_ident => css_ident,
            :css => [],
            :js => [],
            :node_types => [:dict], 
            # TODO: INI support
            :mime_types => [], 

            :init => "",

            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<table></table>');
              $('#{css_ident} table').append($('#browser-doc-properties-widget thead').clone());
              /* for testing */
              //contents_ascii = '{ \"a\": 123, \"b\": \"abc\", \"c\": [4,5,6] }';

              $.fn.dictEditor('#{css_ident} table', {
                'scrollY': '300px',
                'dictEdit_roName': true,
                'dictEdit_editName': function (value, s) {
                  /* FIXME: propagate name change */
                  return(value);
                },
                'dictEdit_editValue': function (value, s) {
                  /* FIXME: propagate calue change */
                  return(value);
                },
                'dictEdit_rowAdd': function () {
                  /* FIXME: propagate row add */
                  console.log('Add Prop Row');
                },
                'dictEdit_rowDel': function () {
                  /* FIXME: propagate row del */
                  console.log('Del Prop Row');
                }
              });

              var table_data = $.parseJSON(contents_ascii);
              $.fn.dictEditor_setData('#{css_ident} table', table_data);
            }
            "
          }
        end
        spec :js_doc_viewer, :generate_viewer, 70

      end

    end
  end
end
