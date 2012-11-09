#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/plugin_stub'

plugin = load_plugin("tiny_weather")
plugin.do_tiny_weather(Msg.new, { :zip => 11375 })
