# Overview

I've been looking around for a tool to help me keep up with builds of many
different projects.  I'm a [buildbot](http://buildbot.net/) fan, but it isn't
appropriate when you've got to deal with a large number of different projects.

[cruisecontrol.rb](http://cruisecontrolrb.thoughtworks.com/) is nice, but is
simultaneously overkill (why is this thing written in rails?) and not a
perfect match.  It's extensible, though, so I've modified it to suit my needs.
In particular, polling is just not an appropriate way to run a CI system.

So now I'm making use of github's
[post-receive hooks](http://github.com/guides/post-receive-hooks) to trigger
events indicating a new build should run.  However, there wasn't an easy way
to get this into cc.rb, so I created a new scheduler in
[my fork at github](http://github.com/dustin/cruisecontrolrb) that uses
[beanstalkd](http://xph.us/software/beanstalkd/) as a simple queue to
communicate between a dedicated mongrel web-hook receiver and the rest of
the world.

# Dependencies

## Servers:
* [beanstalkd](http://xph.us/software/beanstalkd/) v 0.11 or greater
* And this project's cchook.rb

## gems
* [dustin-beanstalk-client](http://github.com/dustin/beanstalk-client-ruby)
* mongrel
* json

# Configuring

## The receiver

Once your beanstalk server is running, you'll need to edit config.yml to point
to it.  config.yml.example should make it obvious how this works.  Note that
you can have more than one beanstalkd running if for some reason you have so
much build traffic coming through as to necessitate it.

Then, run it and configure your project's
[web hook](http://github.com/guides/post-receive-hooks) to point to
the URL of this server.

If a project is sending requests to cchook, but cchook isn't configured to
know of the project, it'll be ignored (well, logged then ignored), so make
them match.

## CruiseControl.rb

On the cc.rb side, edit your project's cruise\_config.rb (as found in
~/.cruise/projects/_project\_name_/cruise\_config.rb) to require the client
gem and point to your tube.

For example, assume your beanstalk server is _beanstalk-server_ and the queue
you want to use for this project is called _myproj-build_, your config may
look like this:

    require 'beanstalk-client'
    
    Project.configure do |project|
    
      project.scheduler.close if project.scheduler.is_a?(BeanstalkScheduler)
      queue = Beanstalk::Pool.new ['beanstalk-server:11300'], 'myproj-build'
      project.scheduler = BeanstalkScheduler.new(project, queue)
    
    end
    
