$(function() {
  $.fn.hexdump = function(str) {
    function hexdump_block(block) {
      var hex_str = '', asc_str = '';
      for( var i = 0; i < block.length; i++ ) {
        var c = block.charAt(i);
        var n = c.charCodeAt(0);
	if ( n < 16 ) hex_str += "0";
        hex_str += n.toString(16) + ' ';
        if ( n > 0x1F && n < 0x7F ) {
          // escape HTML entities
          if (c[0] == '<') {
            c = "&lt;";
          } else if (c[0] == '>') {
            c = "&gt;";
          }
          asc_str += c;
        } else {
          asc_str += '.';
        }
      }
      return String(hex_str + " ".repeat(48)).slice(0, 48) + "| " + asc_str;
    }
    var lines = []
    var addr = 0;
    var num_blocks = (str.length / 16);
    for ( var i=0; i < num_blocks; i++) {
      lines.push( String("00000000" + addr.toString(16)).slice(-8) +
                  " : " + hexdump_block( str.slice(i*16, (i*16)+16) ) );
      addr += 16;
    }
    return(lines.join("\n") + "\n")
  }
});
