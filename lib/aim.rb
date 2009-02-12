$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'aim/net_toc' # <--- using in the background for now
                      #      but i'll be refacting it into AIM

# TODO extract classes to separate files!

# Easily connect to AIM!
class AIM

  class << self

    # 
    # AIM.login_as_user( 'username', 'password' ) do
    #
    #   im_user :bob, 'hello bob!'
    #
    #   log_chatroom :some_chatroom, :output => 'some_chatroom.log'
    #
    #   when :im do |im|
    #     im_user im.user, "thanks for the IM, #{ im.user.name }"
    #   end
    #
    # end
    #
    # when a block is passed, we'll call everything passed in 
    # on the AIM::User created by #login_as_user, and we'll user.wait!
    #
    # without a block, we just return the AIM::User and you 
    # have to manually call user.wait! (which actually just waits)
    #
    # this auto logs in too
    #
    def login_as_user username, password, &block
      @block = block if block
      @user = get_user username, password
      @user.login!

      reload! # take the @user, clear all of the user's event subscriptions, and reload the block
      
      @user.wait!
      @user
    end

    def reload!
      @user.clear_events!
      @user.instance_eval &@block
    end

    # returns an AIM::User, but does not login
    def get_user username, password
      AIM::User.new username, password
    end

  end

  # represents an AIM User, initialized with a username and password
  class User
    attr_accessor :username, :password

    def initialize username, password
      @username, @password = username, password
    end

    def login!
      connection.connect
    end

    # undoes all event subscriptions
    def clear_events!
      connection.clear_callbacks!
    end

    # do something on an event
    #
    # user.when :im do |message, buddy|
    #   puts "message '#{message}' received from #{ buddy }"
    # end
    #
    # user.when :error do |error|
    #   ...
    # end
    #
    # user.when :chat do |message, buddy, room|
    #   ...
    # end
    #
    def when event_name, &block
      connection.send "on_#{ event_name }", &block
    end

    # user.im_user 'bob', "hi bob!"
    def im_user screenname, message
      connection.buddy_list.buddy_named(screenname).send_im(message)
    end

    # helper, will save all messages in a chatroom to a file, or in memory, or wherever
    #
    # right now, usage is simply:
    #
    #   user.log_chatroom 'roomname', :output => 'filename.log'
    #
    def log_chatroom room_name, options = { }
      options[:output] ||= "#{ room_name }.log"
      self.when :chat do |message, buddy, room|
        File.open(options[:output], 'a'){|f| f << "#{ buddy.screen_name }: #{ message }\n" }
      end

      join_chatroom room_name
    end

    # tell the user to just chill!  hang out and wait for events
    def wait!
      connection.wait
    end

    def join_chatroom room_name
      connection.join_chat room_name
    end

    private

    # the Net::TOC backend
    def connection
      @connection ||= Net::TOC.new @username, @password
    end
  end

end
