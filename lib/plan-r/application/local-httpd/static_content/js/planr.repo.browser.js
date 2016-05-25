/* needed because tags are added/removed programmatically */
var ignore_tag_events = false;
/* tab management -- could be handled better */
var viewer_index = { };
var viewer_nodetype = { };
var viewer_mimetype = { };
var viewer_idents = { };
var viewer_cb = { };
/* global variables for callbacks -- either that or each widget stores these. */
// NEEDED BY property, tab callback 
var active_doc_ctype;
var active_doc_path;

/* ---------------------------------------------------------------------- */
/* JQUERY document.ready() */
$(function(){

  /* ---------------------------------------------------------------------- */
  /* Widget Initialization */
  /* make toolbars resizable */
  $('.repo-header .left').resizable({
	  handles: "e",
	  autoHide: false,
	  containment: 'parent',
	  minWidth: '10%',
	  maxWidth: '70%'
  });
  $('.repo-header .center').resizable({
	  handles: "e,w",
	  autoHide: false,
	  containment: 'parent',
	  minWidth: '10%',
	  maxWidth: '70%'
  });
  $('.repo-header .right').resizable({
	  handles: "w",
	  autoHide: false,
	  containment: 'parent',
	  minWidth: '10%',
	  maxWidth: '70%'
  });
  // FIXME: gripper
  /* this doesn't work right (gripper is always outside of handle div): */
  // FIXME: hmm, this could be due to jquery's negative x-value for handle */
  //$('.repo-header .ui-resizable-e').append('<span class="ui-icon ui-icon-grip-dotted-vertical"></span>');
  /* ...so use a 1-px hack to make gripper visible: */
  $('.repo-header .ui-resizable-e').css('cssText', 'right: 1px; width: 1px;');
  $('.repo-header .ui-resizable-w').css('cssText', 'left: 1px; width: 1px;');
  /* make sidebar resizable */
  $('#content-sidebar-left').resizable({
	  handles: "e",
	  autoHide: false,
	  containment: 'parent',
	  minWidth: '5%',
	  maxWidth: '40%'
  });
  // FIXME: gripper
  $('#content-sidebar-left .ui-resizable-e').css('cssText', 'right: 1px; width: 2px;');

  /* Create Repo Tree widget (JSTree) used to navigate repo.
  /* This widget downloads tree elements as-needed via AJAX */
  var repo_tree = $('#browser-repo-tree-widget').jstree({
    /* DEBUG NOTE: the following gets tree instance and last error (object):
         var inst = $.jstree.reference(data.reference),
         obj = inst.get_node(data.reference);
         console.log(inst._data.core.last_error); */

    core: {
      /* AJAX handler to download additional tree nodes */
      data: {
            'url': '/api/repo/browser/tree',
            /* data passed to URL handler to identify node */
            'data' : function (node) { return { 'id' : node.id, 
		                                'type' : node.type }; 
	    }
        },

      /* called to determine if a modification can take place */
      /* 'create_node' 'rename_node' 'delete_node' 'move_node' 'copy_node' */
      check_callback: function (op, node, par_node, position, more) {
        if (node.id === '#') {
          return false;
        }
        if (op === 'copy_node' || op === 'move_node' || op === 'rename_node') {
          return true;
	}
        return false;
      }
    },

    // unused: 'checkbox', 'unique' -- unique be useful if checks type and id
    'plugins' : [ 'wholerow', 'ui', 'state', 'contextmenu', 'dnd', 'sort',
                  'types' ],

    'contextmenu' : { 
      select_node: false, // context-menu does not cause node to be selected
      /* items: a Dict or a function returning a Dict of actions:
      separator_before - boolean
      separator_after - boolean
      _disabled - boolean indicating if this action should be disabled
      label - name of the action (string or  function returning a string)
      action - a function to be executed if this item is chosen
      icon - a string, can be a path to an icon or a className
      shortcut - keyCode which will trigger action if menu is open 
                 (for example 113 for rename, which equals F2)
      shortcut_label - shortcut label (like for example F2 for rename)
      submenu - an object with the same structure as 'items' which can be used 
                to create a submenu - each key will be rendered as a separate 
		option in a submenu that will appear if current item is hovered
      */
      items: function (node) { 
        /* menu items : returns list of context menu items */
        // FIXME: icons
        var items = {
          /* New -> ______________________________ */
          cmd_new_menu: {
            separator_after: true,
            label: 'New',
            submenu: {
              cmd_new_folder: {
                label: "Folder",
                action: function (data) { 
                  $.fn.planrRepoBrowserCreateFolderDialog(node.id);
                }
              },
              cmd_new_doc: {
	        separator_before: true,
                label: "Document",
                action: function (data) { 
                  var inst = $.jstree.reference(data.reference),
                  obj = inst.get_node(data.reference);
                  $.fn.planrRepoBrowserCreateDocumentDialog(node.id);
                }
              },
              cmd_new_note: {
                label: "Note",
                action: function (data) { 
                  $.fn.planrRepoBrowserCreateNoteDialog(node.id);
                }
              },
              cmd_new_table: {
                label: "Table",
                action: function (data) { 
                  $.fn.planrRepoBrowserCreateTableDialog(node.id);
                }
              },
              cmd_new_dict: {
                label: "Dict",
                action: function (data) { 
                  $.fn.planrRepoBrowserCreateDictDialog(node.id);
                }
              }
            }
          },
          /* Rename ______________________________ */
          cmd_rename: {
              label: "Rename",
              action: function (data) { 
                var inst = $.jstree.reference(data.reference),
                obj = inst.get_node(data.reference);
                inst.edit(obj); // rename handler will be called
              }
          },
          /* Duplicate ___________________________ */
          cmd_dup: {
              label: "Duplicate",
              action: function (data) { 
                $.fn.planrRepoDupNode(node.type, node.id);
              }
          },
          /* Delete ______________________________ */
          cmd_delete: {
              label: "Delete",
              action: function (data) { 
                var inst = $.jstree.reference(data.reference);
                var nodes = inst.get_selected();

                if ( nodes.length <= 0 ) {
                  /* no selection: use node that was clicked on */
                  $.fn.planrConfirmDialog('Delete repo item',
                    'Delete "' + node.id  + '"?', function() {
                    $.fn.planrRepoDelNode(node.type, node.id);
                  });

                } else {
                  /* use nodes in selection */
                  $.fn.planrConfirmDialog('Delete repo item(s)',
                    'Delete "' + nodes[0] + '..."?', function() {
                    for (var i=0; i < nodes.length; i++) {
                      var del_node = inst.get_node(nodes[i]);
                      $.fn.planrRepoDelNode(del_node.type, del_node.id);
                    }
                  });
                }
              }
          },
          /* Select All __________________________ */
          cmd_sel_all: { 
	      separator_before: true,
              label: "Select All",
              action: function (data) { 
                $('#browser-repo-tree-widget').jstree().select_all(false);
              }
          },
          /* Deselect All ________________________ */
          cmd_desel_all: { 
              label: "Clear Selection",
              action: function (data) { 
                $('#browser-repo-tree-widget').jstree().deselect_all(false);
              }
          },
          /* Tools -> ____________________________ */
          cmd_tools: {
            label: "Tools",
            submenu: {
              /* Tools -> Transform -> ___________ */
              cmd_transform: {
                label: "Transform",
                submenu: {
                  // FIXME: CONTEXT MENU IMPLEMENT
                  // FIXME: filled by plugin
                }
              },
              /* Tools -> Analyze -> _____________ */
              cmd_analyze: {
                label: "Analyze",
                submenu: {
                  // FIXME: CONTEXT MENU IMPLEMENT
                  // FIXME: filled by plugin
                }
              },
              /* Tools -> Refresh ________________ */
              cmd_refresh: {
	        separator_before: true,
                label: "Refresh",
                action: function (data) { 
                  var inst = $.jstree.reference(data.reference),
                  obj = inst.get_node(data.reference);
		  // FIXME: IMPLEMENT (fore and backend)
                  console.log("TREE CTX REFRESH:" + node.type + '|' + node.id);
                }
              },
              /* Tools -> Reindex ________________ */
              cmd_reindex: {
                label: "Re-index",
                action: function (data) { 
                  var inst = $.jstree.reference(data.reference),
                  obj = inst.get_node(data.reference);
		  // FIXME: IMPLEMENT (fore and backend)
                  console.log("TREE CTX RE-IDX:" + node.type + '|' + node.id);
                }
              },

              /* Tools -> Browse Origin __________ */
              cmd_browse_origin: {
	        separator_before: true,
                label: "Browse to Origin",
                action: function (data) { 
                  var inst = $.jstree.reference(data.reference),
                  obj = inst.get_node(data.reference);
		  // FIXME: IMPLEMENT (fore and backend)
                  console.log("TREE CTX BROWSE " + node.type + '|' + node.id);
                }
              }
            }
          }
	  // TODO: download (if dir, make a tarball)
        };

        /* node-specific context menu changes */
	if (node.type === 'folder') {
          items.cmd_tools._disabled = true;
        }

        return items;
      }
    },

    dnd: {
      // open_timeout, is_draggable, always_copy, inside_pos, 
      // drag_selection, touch, large_drag_target, large_drop_target
      copy: true,	// copying when Ctrl is pressed while DnD
      always_copy: false,
      check_while_dragging: false,
      inside_pos: 'last',
      large_grop_target: true,
      touch: 'selected'
    },

    types : {
      '#' : { icon: '/images/PlanR.png' },
      // ui-icon-folder-collapsed
      'default' : { icon: '/images/folder_closed.png' }, 
      'document' : { icon: '/images/doc.png'},   // ui-icon-document
      'folder' : { icon: '/images/folder_closed.png' },
      'note' : { icon: '/images/txt.png' },      // ui-icon-note
      'table' : { icon: '/images/xls.png' },     // ui-icon-calculator
      'dict' : { icon: '/images/db.png' },       // ui-icon-calendar
      'query' : { icon: '/images/html.png' },    // ui-icon-link
      'script' : { iconm: '/images/script.png' } // ui-icon-gear
    },
    state: {
      /* do not retain node selection in tree state */
      filter: function (state) {
        state.core.selected = [];
        return(state);
      }
    },

    // FIXME: SORT ORDER
    // sort: function(node_a, node_b) -> 1, -1

    themes: {
      stripe: true,
      dots: true,
      responsive: true,
    }
  }).on('activate_node.jstree', 
    /* user clicked on a node: set repo_path to that node by reloading */
    function (event, data) {
      /* NOTE: shift or ctrl key means user is doing multiple-select */
      if ((data.event.ctrlKey) || (data.event.shiftKey)) return;

      var loc = '/repo/browse/' + data.node.type + data.node.id;
      /* prevent spurious reloading */
      if (loc !== window.location.pathname) {
        window.location = loc;
      }

  }).on("rename_node.jstree", 
    function (event, data) {
      $.fn.planrRepoRenameNode(data.node.type, data.node.id, data.text);

  }).on("move_node.jstree", 
    function (event, data) {
      var dest_dir = data.new_instance.get_node(data.parent).id;
      if (dest_dir === '#') dest_dir = '/';
      var dest = dest_dir + '/' + $.fn.planrBasename(data.node.id);
      $.fn.planrRepoMoveNode(data.node.type, data.node.id, dest);

  }).on("copy_node.jstree", 
    function (event, data) {
      var dest_dir = data.new_instance.get_node(data.parent).id;
      if (dest_dir === '#') dest_dir = '/';
      var dest = dest_dir + '/' + $.fn.planrBasename(data.original.id);
      $.fn.planrRepoCopyNode(data.original.type, data.original.id, dest);
  });

  /* make repo-tree resizable */
  $('.repo-tree').resizable({
	  handles: "s"
  });
  // FIXME: gripper
  $('.repo-tree .ui-resizable-s').css('cssText', 'bottom: 1px; height: 2px;');

  /* ========================================= */
  /* create Repo Dir Table widget (DataTables) */
  /* NOTE: DataTable() returns an API object; dataTable() returns a
          JQuery object. To access API with the latter, use dataTable().api(). 
          See https://datatables.net/reference/type/DataTables.Api */
  /* repo_table is modified once, on page load */
  var repo_table = $('#browser-repo-table-widget').DataTable({
    /* NOTE: table classes: .stripe .hover .compat .row-border .nowrap */
    'paging': false,
    'scrollX': true,
    'scrollY': '150px',
    'bFilter': false,
    'bInfo': false,
    'bAutoWidth': false,

    'columnDefs': [
      /* NOTE: checkbox is hidden; it seems superfluous */
      { 'targets': [0], 'orderable': false,
        'className': 'select-checkbox' },
      { 'targets': [0, 1, 2], 'visible': false},
      { 'targets': [3], 'className': 'title'},
      { 'targets': [4], 'className': 'node-type'},
      { 'targets': '_all', 'className': 'text-fixed'},
      { 'targets': [3, 4], 'className': 'dt-body-left'},
    ],

    'fnDrawCallback': function ( oSettings ) { 
      /* FIXME: don't hide header once columns are added */
      $(oSettings.nTHead).hide(); 
      $(oSettings.nTableWrapper.firstChild).hide();
      $(oSettings.nTableWrapper.lastChild).hide();
    },

    "createdRow": function( row, data, idx ) {
      /* make repo-dir DataTable title column editable */
      $(row).find('.title').editable(function(value, s) {
          var ctype = data[1]; // Ctype
          var path = data[2];  // Path
          $.fn.planrRepoRenameNode(ctype, path, value);
          return(value);
        }, {
         type: 'text',
         event: 'dblclick',
         indicator : "<img src='/images/indicator.gif'>",
         //tooltip   : "Doubleclick to edit...",
        });
    },

    //'select': { 'style': 'os', 'selector': 'td:first-child' },
    'select': {
      'style': 'os'
      //'items': 'rows'
    },
    'responsive': true,
    // FIXME: SORT ORDER
    'order': [[3, 'asc']], // FIXME: order by type as well
    'language': { 'emptyTable': '', 'zeroRecords': '' }
  });

  /* on-select: */
  repo_table.on( 'select', function ( e, dt, type, indexes ) {
    /* NOTE: the == 1 means ignore-multiselect */
    if ( indexes.length == 1 ) {
      var row = repo_table.row(indexes[0]).data();
      var ctype = row[1];
      var path = row[2];
      $.fn.planrRepoBrowserSetDocument(path, ctype);
    }
  } );

  /* add general command dispatcher */
  $.fn.planrRepoBrowserCommand = function(cmd, target) {
    /* these ignore selection, so do them first */
    if (cmd === 'sel-all') {
      return repo_table.rows().select(true);
    } else if (cmd === 'sel-none') {
      return repo_table.rows().select(false);
    } else if (cmd === 'add-doc') {
      return $.fn.planrRepoBrowserCreateDocumentDialog(null); 
    } else if (cmd === 'add-note') {
      return $.fn.planrRepoBrowserCreateNoteDialog(null);
    } else if (cmd === 'add-table') {
      return $.fn.planrRepoBrowserCreateTableDialog(null);
    } else if (cmd === 'add-dict') {
      return $.fn.planrRepoBrowserCreateDictDialog(null);
    } else if (cmd === 'add-script') {
      return $.fn.planrRepoBrowserCreateScriptDialog(null);
    } else if (cmd === 'add-query') {
      return $.fn.planrRepoBrowserCreateQueryDialog(null);
    } else if (cmd === 'add-folder') {
      return $.fn.planrRepoBrowserCreateFolderDialog(null);
    }

    var selected = repo_table.rows({ selected: true });
    var rows = selected.data();

    var paths = [], ctypes=[];
    for (var i=0; i < rows.length; i++) {
      ctypes.push( rows[i][1] ); // Ctype
      paths.push( rows[i][2] ); // Path
    }

    /* if selection is empty, use click target */
    if (paths.length <= 0) {
      if (target === null) {
        /* nothing selected: nothing to do */
        return;
      }
      var row = target.parent();
      var cells = repo_table.row(row).data();
      ctypes.push( cells[1] ); // Ctype
      paths.push( cells[2] ); // Path
    }

    /* REFACTOR: use tables of functions and a single for loop */
    if (cmd === 'del') {
      $.fn.planrConfirmDialog('Delete Repo item(s)',                  
        'Delete "' + paths[0]  + '..."?', function() {
          for (var i=0; i < paths.length; i++) {
            $.fn.planrRepoDelNode(ctypes[i], paths[i]);
            row.remove();
          }
      });
      
    } else if (ui.cmd === 'dup') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserDupNode(ctypes[i], paths[i]);

    } else if (ui.cmd === 'download') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoDownloadNode(ctypes[i], paths[i]);

    } else if (ui.cmd === 'add-child-note') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateNoteDialog(paths[i]);

    } else if (ui.cmd === 'add-child-doc') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateDocumentDialog(paths[i]);

    } else if (ui.cmd === 'add-child-table') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateTableDialog(paths[i]);

    } else if (ui.cmd === 'add-child-dict') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateDicteDialog(paths[i]);

    } else if (ui.cmd === 'add-child-script') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateScriptDialog(paths[i]);

    } else if (ui.cmd === 'add-child-query') {
      for (var i=0; i < paths.length(); i++)
        $.fn.planrRepoBrowserCreateQueryDialog(paths[i]);
    }
  };

  /* add context menu */
  $('#browser-repo-table-widget tbody').contextmenu({
    delegate: 'tr',
    menu: [
      {title: 'Add Child', children: [
        {title: 'Note', cmd: 'add-child-note', uiIcon: 'ui-icon-note'},
        {title: '----'},
        {title: 'Document', cmd: 'add-child-doc', uiIcon: 'ui-icon-document'},
        {title: 'Table', cmd: 'add-child-table', uiIcon: 'ui-icon-calculator'},
        {title: 'Dict', cmd: 'add-child-dict', uiIcon: 'ui-icon-calendar'},
        {title: 'Script', cmd: 'add-child-script', uiIcon: 'ui-icon-script'},
        {title: 'Query', cmd: 'add-child-query', uiIcon: 'ui-icon-link'}
       ]},
      {title: 'Delete...', cmd: 'del', uiIcon: 'ui-icon-circle-close'},
      {title: '----'},
      {title: 'Select All', cmd: 'sel-all', uiIcon: 'ui-icon-bullet'},
      {title: 'Deselect All', cmd: 'sel-none', uiIcon: 'ui-icon-radio-off'} 
    ],
    select: function(e, ui) { $.fn.planrRepoBrowserCommand(ui.cmd, ui.target); }
  });
  /* make repo-table resizable */
  $('.repo-dir').resizable({
	  handles: "s"
  });
  // FIXME: gripper
  $('.repo-dir .ui-resizable-s').css('cssText', 'bottom: 1px; height: 2px;');


  /* ========================================= */
  /* create Doc Properties Table widget (DataTables) */
  /* property table is modified every time a document is selected */
  var prop_table = $.fn.dictEditor('#browser-doc-properties-widget', {
    'scrollY': '300px',
    'dictEdit_roName': true,
    /* property-name change : disabled */
    /* property-value change */
    'dictEdit_editValue': function (name, value, s) { 
      var url = '/api/doc/set_property/' + active_doc_ctype + active_doc_path; 
      $.post(url, { name: name, value: value } );
    },
    /* property-row add */
    'dictEdit_rowAdd': function (name, value, row) {
      var url = '/api/doc/set_property/' + active_doc_ctype + active_doc_path; 
      $.post(url, { name: name, value: value } );
    },
    /* property-row del */
    'dictEdit_rowDel': function (name, row) { 
      var url = '/api/doc/set_property/' + active_doc_ctype + active_doc_path; 
      /* NOTE: not sending value means 'delete' */
      $.post(url, { name: name } );
    },
  });
  
  /* ========================================= */
  /* create Doc Tag List widget (TagIt) */
  /* NOTE: this now happens in SetDocument */

  /* ========================================= */
  /* Create Tab widget and instantiate viewers */
  $('#browser-doc-viewer').tabs( {
    collapsible: true,
    heightStyle: "fill" 	// was : "auto"
  });
  /* disable all tabs by default - they will be enabled when doc is selected */
  $("#browser-doc-viewer").tabs( "disable" );

  /* ---------------------------------------------------------------------- */
  /* Event Handlers */
 
  $.fn.planrRepoUpdateView = function(path) {
    var dir = $.fn.planrRepoCurrentPath();

    /* refresh Tree view */
    //$('#browser-repo-tree-widget').tree.jstree("refresh");
    repo_tree.refresh();

    /* refresh Table view */
    var dir = $.fn.planrRepoCurrentPath();
    /* only refresh if changed data was a child of this directory */
    if (path.substring(0, dir.length) === dir) {
      // FIXME: get selection
      // FIXME: this will not work until repo is filled dynamically!
      //        could just reload page? but that loses selection.
      // repo_table.ajax.reload();
      //$('#browser-repo-table-widget').DataTable().ajax.reload();
      // FIXME: restore selection
    }
  };

  /* ========================================= */
  /* FILL PROPERTIES */
  $.fn.planrRepoBrowserFillProperties = function(props, path, ctype) {
    /* fill properties DataTable widget */
    prop_table.clear();

    var keys = Object.keys(props).sort();
    for( var i=0; i < keys.length; i++ ){
      var key = keys[i];
      var val = props[key];
      var vtype = typeof val;
      if ((! vtype === 'string') && (! vtype == 'number') && 
          (! vtype == 'boolean')) {
        val = JSON.stringify(val)
      }
      /* FIXME: I18N translate Name, Value */
      var p_row = { 'Name': key, 'Value': props[keys[i]], 'Type': vtype };
      prop_table.row.add( p_row ).draw();
    }

    /* display datatable */
    prop_table.draw();
  };

  /* ========================================= */
  /* FILL TAGS */
  $.fn.planrRepoBrowserFillTags = function(tags, path, ctype) {
    var tag_list = $('#browser-doc-tags-widget').tagit({
      autocomplete: { 
        /* NOTE: This is a JQuery-UI Autocomplete object */
	source: function( req, response ) {
	  // FIXME: do we really want 'i' (case-insensitive) for tags?
          var exp = new RegExp('^' + 
			       $.ui.autocomplete.escapeRegex(req.term), 'i');
          $.getJSON( '/api/repo/available-tags', function( data ) {
	    var matches = $.grep(data, function(x, i) { return exp.test(x); })
	    response(matches);
          });
        },
      },
      caseSensitive: false,
      singleField: true,
      allowSpaces: true,

      afterTagAdded: function(evt, ui) {
        if ((! ui.duringInitialization) && (! ignore_tag_events)) {
          var url = '/api/doc/add_tag/' + ctype + path; 
          $.post(url, { tag: ui.tag } );
        }
      },

      afterTagRemoved: function(evt, ui) {
        if (! ignore_tag_events) {
          var url = '/api/doc/remove_tag/' + ctype + path;
          $.post(url, { tag: ui.tag } );
        }
      },

      /* open search results in pop-up */
      onTagClicked: function(evt, ui) {
	$.post( { url: '/app/search/results', data: { search_engine: 'tag',
		  query: ui.tagLabel, sep: ',' }, success: function (data) {
          with(window.open('about:blank').document) {
            open();
            write(data);
            close();
          }
        } });
      }
    });

    /* fill Tag-It! widget */
    ignore_tag_events = true;
    $('#browser-doc-tags-widget').tagit("removeAll");
    for( var i=0; i < tags.length; i++ ){
      $('#browser-doc-tags-widget').tagit("createTag", tags[i]);
    }
    ignore_tag_events = false;
  };

  /* ========================================= */
  /* SET DOCUMENT */
  $.fn.planrRepoBrowserSetDocument = function(path, ctype) {
    if (path == '' || ctype == '') {
      return;
    }
    var meta_url = '/api/doc/metadata/' + ctype + path;

    /* fetch metadata */
    $.getJSON( meta_url, function( data ) { 
      var tags = data['tags'];
      if (tags == null) {
        tags = [];
      }
      var props = data['properties'];
      if (props == null) {
        props = {};
      }
      var title = props['title'];
      if (title == null || title === '') {
        title = data['path'];
      }

      /* set path and ctype on DocInfo widget */
      $('#browser-doc-info-path').text($.fn.planrBasename(path));
      $('#browser-doc-info-type').text(ctype);

      $.fn.planrRepoBrowserFillProperties(props, path, ctype);
      $.fn.planrRepoBrowserFillTags(tags, path, ctype);
      // FIXME: IMPLEMENT (needs backend Plan-R support)
      //$.fn.planrRepoBrowserFillRelatedDocs(tags, path, ctype);

      /* fill document viewer title */
      $('#browser-doc-viewer-title').html(title);

      if (ctype !== 'folder') {
        /* notify viewers that document has changed */
        $.fn.planrRepoBrowserNotifyViewers(props, path, ctype);
      }

      /* unfortunately, these gobals are needed for callbacks - refactor! */
      active_doc_ctype = ctype;
      active_doc_path = path;
    });

  };

  /* ========================================= */
  /* NOTIFY VIEWERS */
  $.fn.planrRepoBrowserNotifyViewers = function(props, path, ctype) {
    /* helper routine to determine if tab at CSS ident supports new document */
    function tab_supports_doc(ident) {
      var nodetypes = viewer_nodetype[ident];
      var mimetypes = viewer_mimetype[ident];
      var mime_type = props['mime_type'];

      /* FALSE if node types are specified and do not match */
      if ((typeof nodetypes !== 'undefined') && nodetypes.length > 0) {
        if ($.inArray(ctype, nodetypes) < 0) return(false);
      }
      /* FALSE if mime-types are specified and do not match */
      if ((typeof mimetypes !== 'undefined') && mimetypes.length > 0) {
        if ( (typeof mime_type === 'undefined') || mime_type.length < 1 ||
             ($.inArray(mime_type, mimetypes) < 0) ) {
          return(false);
        }
      }
      return(true);
    }

    /* helper routine to download doc contents *sychronously* */
    function fetch_content(mime_type, path, ctype) {
      var url = '/api/doc/ascii_contents/' + ctype + path;
      var buf_ascii = null;
      var buf_raw = null;

      /* get ASCII contents */
      $.get( { url: url, async: false, success: function(data) {
        buf_ascii = data;
      } });

      /* if not an ASCII document, get raw contents */
      /* NOTE: internal node types are all ASCII (i.e. JSON) */
      if ((typeof mime_type == 'undefined') || mime_type === '') {
        mime_type = 'application/octet-stream'
      }
      if ((ctype === 'document') && (mime_type.split('/')[0] !== 'text')) {
        url = '/api/doc/contents/' + ctype + path;
        $.get( { url: url, async: false, success: function(data) {
          buf_raw = data;
        } });
      } else {
        /* for ASCII documents, set raw contents to ascii contents */
        buf_raw = buf_ascii;
      }
      return( { ascii: buf_ascii, raw: buf_raw } )
    }

    /* download document contents */
    var contents = { ascii: '', raw: '' };
    if (ctype !== 'folder') {
      contents = fetch_content(props['mime_type'], path, ctype);
    }

    /* iterate through tabs, disabling those that do not support document.
     * those that support document have their load() method called. */
    var keys = Object.keys(viewer_index).sort();
    for( var i=0; i < keys.length; i++ ){
      var ident = keys[i];
      var fn = viewer_cb[ident];

      /* note that 'folder' is never supported by doc-viewer plugins */
      if (ctype !== 'folder' && tab_supports_doc(ident)) {
        $("#browser-doc-viewer").tabs( "enable", ident );
	/* load document contents via function provided by plugin */
        if (fn) fn(ctype, path, contents.ascii, contents.raw);
      } else {
        $("#browser-doc-viewer").tabs( "disable", ident );
      }
    }
  };

  /* ========================================= */
  /* CREATE DOCUMENT */

  /* synchronously connect to a node creation URL. if successful, 
   * re-fill repo-tree and repo-table. */
  $.fn.planrRepoNewNode = function(ctype, path, content, props) {
    var params = { 'merge_properties' : true };
    if (props !== null) {
      params['properties'] = JSON.stringify(props);
    }
    if (content !== null) {
      params['contents'] = content;
    }
    var url = '/api/doc/new/' + ctype + path; 
    console.log(url);
    $.post( { url: url, data: params, async: false, success: function(data) {
      // FIXME: is set-document appropriate in all cases?
      // $.fn.planrRepoBrowserSetDocument(path, ctype)
      $.fn.planrRepoUpdateView(path);
    } });
  };

  /* open a Create Document dialog */
  $.fn.planrRepoBrowserCreateNodeDialog = function(loc, ctype, dlg_title) {
    /* pre-fill (or clear) text entry elements */
    $('#new-node-type').val(ctype);

    if (typeof loc === 'string' && loc !== '') {
      $('#new-node-loc-entry').val(loc);
    }
    $('#new-node-name-entry').val('');
    $('#new-node-title-entry').val('');
    $('#new-node-content-entry').val('');

    /* only show contents textentry if ctype is Document or Note */
    if (ctype === 'document' || ctype === 'note') {
      $('#new-node-content-label').css('display', '');
      $('#new-node-content-entry').css('display', '');
    } else {
      $('#new-node-content-label').css('display', 'none');
      $('#new-node-content-entry').css('display', 'none');
    }
    $('#new-node-dialog').dialog({ title: dlg_title });
    $('#new-node-dialog').dialog('open'); 
  };

  /* called from CreateNode Dialog. This creates the actual document from
   * dialog parameters. The main work performed here is to fill path from 
   * title or title from path, and to create a properties file if title
   * is provided (or if ctype is document). The rest of the work is performed 
   * by $.fn.planrRepoNewNode . */
  $.fn.planrRepoBrowserCreateNode = function(loc, name, ctype, title, txt) {

    if (loc === null || loc === '') {
      loc = '/';
    // FIXME: } else if (! loc.start_with? '/')
    }

    if ( name === null || name === '' ) {
      if (title === null || title === '') {
        console.log('path or title required.');
        return;
      } else {
        name = title.replace(/[^a-zA-Z0-9]/, '_');
      }
    }
    var path = loc + '/' + name;

    if (ctype === 'document' && (title === null || title === '')) {
      title = name.replace('_', ' ');
    }

    var props = null;
    if (title !== null && title !== '') {
      props = { 'title': title };
    }

    if (txt === '') {
      txt = null;
    }
    $.fn.planrRepoNewNode(ctype, path, txt, props);
  };

  /* ========================================= */
  /* Other Document Helpers */

  /* This retains the document name and title, moving it to a new parent. */
  $.fn.planrRepoMoveNode = function(ctype, path, dest) {
    var url = '/api/doc/move/' + ctype + path; 
    var data = { 'dest' : dest, 'overwrite' : true };
    $.post( { url: url, data: data, async: false, success: function(data) {
      $.fn.planrRepoUpdateView(path);
    } });
  };

  /* This retains the document name and title, duplicating it to a new parent */
  $.fn.planrRepoCopyNode = function(ctype, path, dest) {
    var url = '/api/doc/copy/' + ctype + path; 
    var data = { 'dest' : dest, 'overwrite' : true };
    $.post( { url: url, data: data, async: false, success: function(data) {
      $.fn.planrRepoUpdateView(path);
    } });
  };

  /* This changes the title of a Document *or* moves a Folder */
  $.fn.planrRepoRenameNode = function(ctype, path, new_name) {
    var url = '/api/doc/set_property/' + ctype + path; 
    var data = { 'name' : 'title', 'value' : new_name };

    if (ctype === 'folder') {
      /* folders do not use 'title' property, so they are moved */
      var url = '/api/doc/move/' + ctype + path;
      var dest_path = '';
      var data = { 'dest' : dest_path, 'overwrite': false };
    }
    $.post( { url: url, data: data, async: false, success: function(data) {
      $.fn.planrRepoUpdateView(path);
    } });

  };

  /* This duplicates the document or folder in its current location. A new 
   * name is auto-generated. */
  $.fn.planrRepoDupNode = function(ctype, path) {
    var url = '/api/doc/dup/' + ctype + path;
    $.post( { url: url, data: {}, async: false, success: function(data) {
      $.fn.planrRepoUpdateView(path);
    } });
  };

  /* This deletes the document or folder and all children. */
  $.fn.planrRepoDelNode = function(ctype, path) {
    var url = '/api/doc/delete/' + ctype + path;
    $.post( { url: url, data: {}, async: false, success: function(data) {
      $.fn.planrRepoUpdateView(path);
    } });
  };

  /* Download the specified node as a file */
  $.fn.planrRepoDownloadNode = function(ctype, path) {
    var url = '/api/doc/download/' + ctype + path;
    $.get( url );
  };

  /* Same as download, only do not set content-disposition to 'file' */
  $.fn.planrRepoViewNode = function(ctype, path) {
    var url = '/api/doc/view/' + ctype + path;
    $.get( url );
  };

  /* Update the contents of a Node. Folders are ignored. */
  $.fn.planrRepoUpdateNodeContents = function(ctype, path, data, props) {
    // FIXME: implement
    // FIXME: are props even necessary? obviously they'll merge over old-props
    return;
  }

  /* ========================================= */
  /* Misc dialogs */

  $.fn.planrInputPromptDialog = function(title, message, on_success) {
    $('#input-prompt-label').text(message);
    $('#input-prompt-entry').val('');
    $('#input-prompt-dialog').dialog({
      title: title,
      buttons: [
        { text: 'Cancel', click: function() {
          $(this).dialog('close');
        }, icons: { primary: 'ui-icon-cancel' } },
        { text: 'Add', click: function() {
          on_success();
          $(this).dialog('close');
        }, icons: { primary: 'ui-icon-check' } }
      ]} );
    $('#input-prompt-dialog').dialog('open'); 
  };

  $.fn.planrMessageDialog = function(title, message) {
    $('#message-dialog-label').text(message);
    $('#message-dialog').dialog({ title: title } );
    $('#message-dialog').dialog('open');
  };

  $.fn.planrConfirmDialog = function(title, message, on_success) {
    $('#confirm-dialog-label').text(message);
    $('#confirm-dialog').dialog({
      title: title,
      buttons: [
        { text: 'Cancel', click: function() {
          $(this).dialog('close');
        }, icons: { primary: 'ui-icon-cancel' } },
        { text: 'Confirm', click: function() {
          on_success();
          $(this).dialog('close');
        }, icons: { primary: 'ui-icon-check' } }
      ]} );
    $('#confirm-dialog').dialog('open');
  };

  /* FIXME: move into generic .js */
  $.fn.planrBasename = function(path) {
      var path_elem = path.split('/');
      return(path_elem[path_elem.length - 1]);
  };
});
