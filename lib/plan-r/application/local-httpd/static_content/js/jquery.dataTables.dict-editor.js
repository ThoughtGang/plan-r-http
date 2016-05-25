$(function() {                                                                  
  $.fn.dictEditor = function(selector, opts_override) {
    /* default settings */
    var opts = {
      'paging': false,
      'scrollX': true,
      'scrollY': '300px',
      'bFilter': false,
      'bInfo': false,
      'bAutoWidth': false,

      /* NOTE: Caller must translate by overriding this property */
      'columns': [ { 'data': 'Name' },
                   { 'data': 'Value' },
                   { 'data': 'Type' } ],

      'columnDefs': [
	{ 'targets': [2], 'visible': false},
        // This breaks name/value tags! multiple classes not allowed?
        //{ 'targets': '_all', 'className': 'dt-body-left'},
        { 'targets': [0], 'className': 'name'},
        { 'targets': [1], 'className': 'value'} 
      ],

      /* callback when table is redrawn */
      'fnDrawCallback': function ( oSettings ) {
        /* FIXME: don't hide header once columns are added */
        $(oSettings.nTHead).hide();
        $(oSettings.nTableWrapper.firstChild).hide();
        $(oSettings.nTableWrapper.lastChild).hide();
      },
      /* callback when a TR element is added */
      "createdRow": function( row, data, idx ) {
        /* make value column editable */
        $(row).find('.value').editable(function(value, s) {
          /* at this point, 'data' has the original row data as a Dict */
            if (typeof opts.dictEdit_editValue == 'function')
              opts.dictEdit_editValue(data['Name'], value, s)
            return(value);
          }, {
           // FIXME: type-specific value editing
           type: 'text',
           event: 'dblclick',
           indicator : "<img src='/images/indicator.gif'>",
           tooltip   : "(empty) Doubleclick to edit...",
        });

        if (! 'dictEdit_roName' ) {
          /* make name column editable */
          $(selector + ' .name').editable(function(value, s) {
              if (typeof opts.dictEdit_editName == 'function')
                opts.dictEdit_editName(data['Name'], value, data['Value'], s)
              return(value);
            }, {
             type: 'text',
             event: 'dblclick',
             indicator : "<img src='/images/indicator.gif'>",
             tooltip   : "(empty) Doubleclick to edit...",
          });
        }
      },

      'language': { 'emptyTable': 'No document selected', 'zeroRecords': '' },

      /* these are for dict-edit, not datatable */
      'dictEdit_roName': false,
      'dictEdit_editName': function(name, value, s) { return(true); },
      'dictEdit_editValue': function(old, name, value, s) { return(true); },
      'dictEdit_rowAdd': function(name, value, row) { return(true); },
      'dictEdit_rowSel': function(row) { return(true); },
      'dictEdit_rowDel': function(name, row) { return(true); }
    };

    $.extend(opts, opts_override);
    table = $(selector).DataTable(opts);

    /* on-select handler */
    $(selector).on( 'click', 'tr', function () {
      var row = table.row(this).data();
      if (typeof row === 'undefined') return;
      var ctype = row[0];
      var path = row[1];

      //opts.dictEdit_rowSel();
      if ( $(this).hasClass('selected') ) {
        $(this).removeClass('selected');
      } else {
        $(selector + ' tr.selected').removeClass('selected');
        $(this).addClass('selected');
      }
    });

    /* add context menu */
    $(selector).contextmenu({
      delegate: "tr",
      menu: [
        {title: "Add...", cmd: "add", uiIcon: "ui-icon-plus"},
        {title: "Delete...", cmd: "delete", uiIcon: "ui-icon-circle-close"} //,
        // TODO: show/change value type?
      ],
      select: function(e, ui) {
	var row = ui.target.parent();
	var name = $(row.children()[0]).text();
	var value = $(row.children()[1]).text();
        if (ui.cmd === 'add') {
          $.fn.planrInputPromptDialog('New element : Name', 
            'Name for new element:', function() {
              var new_name = $('#input-prompt-entry').val();
	      // FIXME: if exists?
              if (typeof opts.dictEdit_rowAdd == 'function') 
	        opts.dictEdit_rowAdd( new_name, '', row);
              table.row.add( { 'Name' : new_name, 
		               'Value' : '', 
		               'Type': 'string' } );
	      table.draw();
	    });
        } else if (ui.cmd == 'delete') {
          $.fn.planrConfirmDialog('Delete dictionary element',
            'Delete "' + name  + '"?', function() {
              if (typeof opts.dictEdit_rowDel == 'function') 
	        opts.dictEdit_rowDel(name, row);
	      row.remove();
	    });

        } else {
          console.log("DICTEDIT CTX " + ui.cmd + " on " + ui.target.text());
        }
      }
    });

    return(table);
  };

  $.fn.dictEditor_setData = function(selector, dict) {
    if (typeof dict !== 'object') return;

    var table = $(selector).DataTable();
    var keys = Object.keys(dict).sort();
    for( var i=0; i < keys.length; i++ ){
      var key = keys[i];
      var val = dict[key];
      var vtype = typeof val;
      if ((! vtype === 'string') && (! vtype == 'number') &&
          (! vtype == 'boolean')) {
        val = JSON.stringify(val)
      }
      var row = { 'Name': key, 'Value': dict[keys[i]], 'Type': vtype };
      table.row.add( row ).draw();
    }
    table.draw();
  };
});
