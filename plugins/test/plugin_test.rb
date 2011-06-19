#!/usr/bin/ruby

require 'plugin_stub'

plugin = load_plugin("tiny_weather")
plugin.do_tiny_weather_forecast(Msg.new, {:zip => "11375"})
