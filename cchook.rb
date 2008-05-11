#!/usr/bin/env ruby -w

require 'rubygems'
require 'json'
require 'beanstalk-client'

require 'mongrel'

unless defined? CONF
  CONF = YAML.load_file('config.yml')
  puts "Configuring for #{CONF['queue']['servers'].inspect}"
end

class CCHook

  def go(payload)
    payload = JSON.parse(payload)
    log_error(nil) and return unless payload.keys.include?("repository")
    @repo = payload['repository']['name']
    log_error(payload) and return unless CONF['repos'][@repo]

    queue = Beanstalk::Pool.new CONF['queue']['servers'], CONF['repos'][@repo]
    begin
      puts "Building #{@repo} on #{payload['after']}"
      queue.put(payload['after'])
    ensure
      queue.close
    end
  end

  def log_error(payload)
    if @repo
      puts "Unhandled repo:  #{@repo}"
    else
      puts "Didn't understand my input:  #{payload}"
    end
  end

end

class SimpleHandler < Mongrel::HttpHandler
  def process(request, response)
    cgi = Mongrel::CGIWrapper.new(request, response)
    CCHook.new.go(cgi['payload'])
    response.start(200) do |head,out|
      head["Content-Type"] = "text/plain"
      out.write("Thanks!\n")
    end
  end
end

h = Mongrel::HttpServer.new("0.0.0.0", "4567")
h.register("/", SimpleHandler.new)
h.run.join
