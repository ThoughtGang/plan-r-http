#!/usr/bin/env ruby                                                             
# (c) Copyright 2016 Thoughtgang <http://www.thoughtgang.org>
# Unit tests for PlanR LocalWebApplication Browser open

require 'test/unit'

require 'plan-r/application/local-httpd/browser'

# ----------------------------------------------------------------------
class TC_BrowserOpenTest < Test::Unit::TestCase
  # PlanR::Application::LocalHttpd::Browser::URL_OPEN_COMMAND
  def test_1
    $stderr.puts PlanR::Application::LocalHttpd::Browser::URL_OPEN_COMMAND
  end

  def test_2
    PlanR::Application::LocalHttpd::Browser.open('https://www.w3.org', nil, 
                                                  true)
  end
end
