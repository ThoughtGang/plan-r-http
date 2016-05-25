#!/usr/bin/env ruby
=begin rdoc
(c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
=end

require 'shellwords'

module PlanR
  module Application
    module LocalHttpd

=begin rdoc
Object to launch a web browser.
=end
      class Browser

        # NOTE: This runs once, at parse-time
        case RUBY_PLATFORM
        when /darwin/
          URL_OPEN_COMMAND = 'open'
        when /linux/, /bsd/
          [ 'xdg-open', 'firefox', 'chromium-browser', 'opera', 
            'w3m', 'lynx', 'more' ].each do |app|
            if not `which #{app}`.chomp.empty?
              URL_OPEN_COMMAND = app
              break
            end
          end
        else
          # windows
          URL_OPEN_COMMAND = 'start'
        end

        def self.open(uri, cmd=nil, debug=false)

          pid = Process.fork do
            uri_s = Shellwords.shellescape uri.to_s
            ocmd = "#{Shellwords.shellescape(cmd || URL_OPEN_COMMAND)} #{uri_s}"
            $stderr.puts ocmd if debug
            `#{ocmd}`
          end
          Process.detach(pid)
        end
      end

    end
  end
end
