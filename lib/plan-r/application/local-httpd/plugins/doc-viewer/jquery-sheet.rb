#!/usr/bin/env ruby
# :title: PlanR::Plugins::JsDocViewer::sheet
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'tg/plugin'

module PlanR
  module Pluginsspec_dir
    module JsDocViewer

      class JquerySheet
        extend TG::Plugin
        name 'Jquery Sheet'
        author 'dev@thoughtgang.org'
        version '0.1'
        description 'Spreadsheet editor'
        help 'Webapp document viewer plugin for Plan R table content nodes, 
using the JQuery SHeet widget.'

        def generate_viewer(css_ident, opts={})
          { :name => 'table editor',
            :i18n_label => :table,
            :css_ident => css_ident,
            :css => ['/css/jquery.sheet.css'],
            :js => ['/js/globalize.js', 
                    '/js/jquery.sheet.min.js',
                    '/js/jquery.sheet.advancedfn.js',  
                    '/js/jquery.sheet.financefn.js', 
                    '/js/jquery.sheet.dts.js' ],
            # TODO: dependencies.plugins: (possibly include in main app)
            # 'parser/formula/formula.js'
            # 'parser/tsv/tsv.js'
            # 'jquery-nearest/src/jquery.nearest.min.js'
            # 'MouseWheel/MouseWheel.js'
            # 'plugins/jquery.sheet.advancedfn.js'
            # 'plugins/jquery.sheet.dts.js'
            # 'plugins/jquery.sheet.financefn.js'
            # 'really-simple-color-picker/jquery.colorPicker.min.js',
            # 'jquery-elastic/jquery.elastic.source.js'
            # 'globalize/lib/cultures/globalize.cultures.js'
            # 'raphael/raphael-min.js'
            # 'graphael/g.raphael.js'
            # 'graphael/g.bar.js'
            # 'graphael/g.dot.js'
            # 'graphael/g.line.js'
            # 'graphael/g.pie.js'
            # 'Javascript-Undo-Manager/js/undomanager.js'
            # 'zeroclipboard/dist/ZeroClipboard.min.js'
            :node_types => [:table], 
            # TODO: CSV support
            :mime_types => [],

            :init => [], 

=begin FIXME
jQuery.Sheet JSON schema:
 [{ // sheet 1, can repeat
  "title": "Title of spreadsheet",
  "metadata": {
      "widths": [
          120, //widths for each column, required
          80
      ]
  },
  "rows": [
      { // row 1, repeats for each column of the spreadsheet
          "height": 18, //optional
          "columns": [
              { //column A
                  "cellType":"", //optional
                  "class": "css classes", //optional
                  "formula": "=cell formula", //optional
                  "value": "value", //optional
                  "style": "css cell style" //optional
              },
              {} //column B
          ]
      },
      { // row 2
          "height": 18, //optional
          "columns": [
              { // column A
                  "cellType":"", //optional
                  "class": "css classes", //optional
                  "formula": "=cell formula", //optional
                  "value": "value", //optional
                  "style": "css cell style" //optional
              },
              {} // column B
          ]
      }
  ]
 }]
=end
            :load_doc => "
            function(doc_type, doc_path, contents_ascii, contents_raw) {
              $('#{css_ident}').children().remove();
              $('#{css_ident}').append('<div id=\"sheet-doc-viewer\"></div>');
              $('#sheet-doc-viewer-sheet').width('#{opts[:width] || 800}');
              $('#sheet-doc-viewer').height('#{opts[:height] || 600}');
              var sheet_data = $.parseJSON(contents_ascii);
              /* \"[{'title':'simple table 1','rows':[{'columns':[{'formula':'100 + SHEET2!A70','cellType':'currency','value':100,'style':'height: 50px; background-color: red; color: blue;','class':'styleBold styleCenter'}],'metadata':{'widths':['120','120','120','120','120','120'],'frozenAt':{'row':0,'col':0}}}] }]\"; */
        $.sheet.preLoad('../');

              $('#sheet-doc-viewer').sheet({
                /* FIXME: this won't actually work : */
                loader: new Sheet.JSONLoader( contents_ascii ),
                minSize: {rows: 3, cols: 3},
                title: 'Spreadsheet-Untitled',
                buildSheet: '3x3',
                editable: true
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
