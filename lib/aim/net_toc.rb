# A small library that connects to AOL Instant Messenger using the TOC v2.0 protocol.
#
# Author::    Ian Henderson (mailto:ian@ianhenderson.org)
# Copyright:: Copyright (c) 2006 Ian Henderson
# License::   revised BSD license (http://www.opensource.org/licenses/bsd-license.php)
# Version::   0.2
# 
# See Net::TOC for documentation.

require 'socket'

module Net

  # == Overview
  # === Opening a Connection
  # Pass Net::Toc.new your screenname and password to create a new connection.
  # It will return a Client object, which is used to communicate with the server.
  #
  #  client = Net::TOC.new("screenname", "p455w0rd")
  #
  # To actually connect, use Client#connect.
  #
  #  client.connect
  #
  # If your program uses an input loop (e.g., reading from stdin), you can start it here.
  # Otherwise, you must use Client#wait to prevent the program from exiting immediately.
  #
  #  client.wait
  #
  # === Opening a Connection - The Shortcut
  # If your program only sends IMs in response to received IMs, you can save yourself some code.
  # Net::TOC.new takes an optional block argument, to be called each time a message arrives (it is passed to Client#on_im).
  # Client#connect and Client#wait are automatically called.
  #
  #  Net::TOC.new("screenname", "p455w0rd") do | message, buddy |
  #    # handle the im
  #  end
  #
  # === Receiving Events
  # Client supports two kinds of event handlers: Client#on_im and Client#on_error.
  #
  # The given block will be called every time the event occurs.
  #  client.on_im do | message, buddy |
  #    puts "#{buddy.screen_name}: #{message}"
  #  end
  #  client.on_error do | error |
  #    puts "!! #{error}"
  #  end
  #
  # You can also receive events using Buddy#on_status.
  # Pass it any number of statuses (e.g., :away, :offline, :available, :idle) and a block;
  # the block will be called each time the buddy's status changes to one of the statuses.
  #
  #  friend = client.buddy_list.buddy_named("friend")
  #  friend.on_status(:available) do
  #    friend.send_im "Hi!"
  #  end
  #  friend.on_status(:idle, :away) do
  #    friend.send_im "Bye!"
  #  end
  #
  # === Sending IMs
  # To send an instant message, call Buddy#send_im.
  #
  #  friend.send_im "Hello, #{friend.screen_name}!"
  #
  # === Status Changes
  # You can modify your state using these Client methods: Client#go_away, Client#come_back, and Client#idle_time=.
  #
  #  client.go_away "Away"
  #  client.idle_time = 600 # ten minutes
  #  client.come_back
  #  client.idle_time = 0 # stop being idle
  #
  # It is not necessary to call Client#idle_time= continuously; the server will automatically keep track.
  #
  # == Examples
  # === Simple Bot
  # This bot lets you run ruby commands remotely, but only if your screenname is in the authorized list.
  #
  #  require 'net/toc'
  #  authorized = ["admin_screenname"]
  #  Net::TOC.new("screenname", "p455w0rd") do | message, buddy |
  #    if authorized.member? buddy.screen_name
  #      begin
  #        result = eval(message.chomp.gsub(/<[^>]+>/,"")) # remove html formatting
  #        buddy.send_im result.to_s if result.respond_to? :to_s
  #      rescue Exception => e
  #        buddy.send_im "#{e.class}: #{e}"
  #      end
  #    end
  #  end
  # === (Slightly) More Complicated and Contrived Bot
  # If you message this bot when you're available, you get a greeting and the date you logged in.
  # If you message it when you're away, you get scolded, and then pestered each time you become available.
  #
  #  require 'net/toc'
  #  client = Net::TOC.new("screenname", "p455w0rd")
  #  client.on_error do | error |
  #    admin = client.buddy_list.buddy_named("admin_screenname")
  #    admin.send_im("Error: #{error}")
  #  end
  #  client.on_im do | message, buddy, auto_response |
  #    return if auto_response
  #    if buddy.available?
  #      buddy.send_im("Hello, #{buddy.screen_name}. You have been logged in since #{buddy.last_signon}.")
  #    else
  #      buddy.send_im("Liar!")
  #      buddy.on_status(:available) { buddy.send_im("Welcome back, liar.") }
  #    end
  #  end
  #  client.connect
  #  client.wait
  # === Simple Interactive Client
  # Use screenname<<message to send message.
  # <<message sends message to the last buddy you messaged.
  # When somebody sends you a message, it is displayed as screenname>>message.
  #
  #  require 'net/toc'
  #  print "screen name: "
  #  screen_name = gets.chomp
  #  print "password: "
  #  password = gets.chomp
  #  
  #  client = Net::TOC.new(screen_name, password)
  #  
  #  client.on_im do | message, buddy |
  #    puts "#{buddy}>>#{message}"
  #  end
  #  
  #  client.connect
  #  
  #  puts "connected"
  #  
  #  last_buddy = ""
  #  loop do
  #    buddy_name, message = *gets.chomp.split("<<",2)
  #
  #    buddy_name = last_buddy if buddy_name == ""
  #
  #    unless buddy_name.nil? or message.nil?
  #      last_buddy = buddy_name 
  #      client.buddy_list.buddy_named(buddy_name).send_im(message)
  #    end
  #  end
  module TOC
    class CommunicationError < RuntimeError # :nodoc:
    end
    
    # Converts a screen name into its canonical form - lowercase, with no spaces.
    def format_screen_name(screen_name)
      screen_name.downcase.gsub(/\s+/, '')
    end
    
    # Escapes a message so it doesn't confuse the server. You should never have to call this directly.
    def format_message(message) # :nodoc:
      msg = message.gsub(/(\r|\n|\r\n)/, '<br>')
      msg.gsub(/[{}\\"]/, "\\\\\\0") # oh dear
    end

    # Creates a new Client. See the Client.new method for details.
    def self.new(screen_name, password, &optional_block) # :yields: message, buddy, auto_response, client
      Client.new(screen_name, password, &optional_block)
    end
    
    Debug = false # :nodoc:
    
    ErrorCode = {
      901 => "<param> is not available.",
      902 => "Warning <param> is not allowed.",
      903 => "Message dropped; you are exceeding the server speed limit",
      980 => "Incorrect screen name or password.",
      981 => "The service is temporarily unavailable.",
      982 => "Your warning level is too high to sign on.",
      983 => "You have been connecting and disconnecting too frequently. Wait 10 minutes and try again.",
      989 => "An unknown error has occurred in the signon process."
    }

    # The Connection class handles low-level communication using the TOC protocol. You shouldn't use it directly.
    class Connection # :nodoc:
      include TOC

      def initialize(screen_name)
        @user = format_screen_name screen_name
        @msgseq = rand(100000)
      end

      def open(server="toc.oscar.aol.com", port=9898)
        close
        @sock = TCPSocket.new(server, port)

        @sock.send "FLAPON\r\n\r\n", 0

        toc_version = *recv.unpack("N")

        send [1, 1, @user.length, @user].pack("Nnna*"), :sign_on
      end

      def close
        @sock.close unless @sock.nil?
      end

      FrameType = {
        :sign_on => 1,
        :data    => 2
      }

      def send(message, type=:data)
        message << "\0"
        puts "  send: #{message}" if Debug
        @msgseq = @msgseq.next
        header = ['*', FrameType[type], @msgseq, message.length].pack("aCnn")
        packet = header + message
        @sock.send packet, 0
      end

      def recv
        header = @sock.recv 6
        raise CommunicationError, "Server didn't send full header." if header.length < 6

        asterisk, type, serverseq, length = header.unpack "aCnn"

        response = @sock.recv length
        puts "  recv: #{response}" if Debug
        unless type == FrameType[:sign_on]
          message, value = response.split(":", 2)
          unless message.nil? or value.nil?
            msg_sym = message.downcase.to_sym
            yield msg_sym, value if block_given?
          end
        end
        response
      end
      
      private
      
      # Any unknown methods are assumed to be messages for the server.
      def method_missing(command, *args)
        puts ([command] + args).join(" ").inspect
        send(([command] + args).join(" "))
      end
    end
    
    class Buddy
      include TOC
      include Comparable
      
      attr_reader :screen_name, :status, :warning_level, :last_signon, :idle_time
      
      def initialize(screen_name, conn) # :nodoc:
        @screen_name = screen_name
        @conn = conn
        @status = :offline
        @warning_level = 0
        @on_status = {}
        @last_signon = :never
        @idle_time = 0
      end
      
      def <=>(other) # :nodoc:
        format_screen_name(@screen_name) <=> format_screen_name(other.screen_name)
      end
      
      # Pass a block to be called when status changes to any of +statuses+. This replaces any previously set on_status block for these statuses.
      def on_status(*statuses, &callback) #:yields:
        statuses.each { | status | @on_status[status] = callback }
      end
      
      # Returns +true+ unless status == :offline.
      def online?
        status != :offline
      end
      
      # Returns +true+ if status == :available.
      def available?
        status == :available
      end
      
      # Returns +true+ if status == :away.
      def away?
        status == :away
      end
      
      # Returns +true+ if buddy is idle.
      def idle?
        @idle_time > 0
      end
      
      # Sends the instant message +message+ to the buddy. If +auto_response+ is true, the message is marked as an automated response.
      def send_im(message, auto_response=false)
        puts "send_im: #{ message }" # remi
        args = [format_screen_name(@screen_name), "\"" + format_message(message) + "\""]
        args << "auto" if auto_response
        puts "@conn.toc_send_im #{args.inspect}" # remi
        @conn.toc_send_im *args
      end
      
      # Warns the buddy. If the argument is :anonymous, the buddy is warned anonymously. Otherwise, your name is sent with the warning.
      # You may only warn buddies who have recently IMed you.
      def warn(anon=:named)
        @conn.toc_evil(format_screen_name(@screen_name), anon == :anonymous ? "anon" : "norm")
      end
      
      # The string representation of a buddy; equivalent to Buddy#screen_name.
      def to_s
        screen_name
      end
      
      def raw_update(val) # :nodoc:
        # TODO: Support user types properly.
        name, online, warning, signon_time, idle, user_type = *val.split(":")
        @warning_level = warning.to_i
        @last_signon = Time.at(signon_time.to_i)
        @idle_time = idle.to_i
        if online == "F"
          update_status :offline
        elsif user_type[2...3] and user_type[2...3] == "U"
          update_status :away
        elsif @idle_time > 0
          update_status :idle
        else
          update_status :available
        end
      end
      
      private
      
      def update_status(status)
        if @on_status[status] and status != @status
          @status = status
          @on_status[status].call
        else
          @status = status
        end
      end
    end
    
    # Manages groups and buddies. Don't create one yourself - get one using Client#buddy_list.
    class BuddyList
      include TOC
      
      def initialize(conn) # :nodoc:
        @conn = conn
        @buddies = {}
        @groups = {}
        @group_order = []
      end

      # Constructs a printable string representation of the buddy list.
      def to_s
        s = ""
        each_group do | group, buddies |
          s << "== #{group} ==\n"
          buddies.each do | buddy |
            s << " * #{buddy}\n"
          end
        end
        s
      end
      
      # Calls the passed block once for each group, passing the group name and the list of buddies as parameters.
      def each_group
        @group_order.each do | group |
          buddies = @groups[group]
          yield group, buddies
        end
      end
      
      # Adds a new group named +group_name+.
      # Setting +sync+ to :dont_sync will prevent this change from being sent to the server.
      def add_group(group_name, sync=:sync)
        if @groups[group_name].nil?
          @groups[group_name] = []
          @group_order << group_name
          @conn.toc2_new_group group_name if sync == :sync
        end
      end
      
      # Adds the buddy named +buddy_name+ to the group named +group+. If this group does not exist, it is created.
      # Setting +sync+ to :dont_sync will prevent this change from being sent to the server.
      def add_buddy(group, buddy_name, sync=:sync)
        add_group(group, sync) if @groups[group].nil?
        @groups[group] << buddy_named(buddy_name)
        @conn.toc2_new_buddies("{g:#{group}\nb:#{format_screen_name(buddy_name)}\n}") if sync == :sync
      end
      
      # Removes the buddy named +buddy_name+ from the group named +group+.
      # Setting +sync+ to :dont_sync will prevent this change from being sent to the server.
      def remove_buddy(group, buddy_name, sync=:sync)
        unless @groups[group].nil?
          buddy = buddy_named(buddy_name)
          @groups[group].reject! { | b | b == buddy }
          @conn.toc2_remove_buddy(format_screen_name(buddy_name), group) if sync == :sync
        end
      end

      # Returns the buddy named +name+. If the buddy does not exist, it is created. +name+ is not case- or whitespace-sensitive.
      def buddy_named(name)
        formatted_name = format_screen_name(name)
        buddy = @buddies[formatted_name]
        if buddy.nil?
          buddy = Buddy.new(name, @conn)
          @buddies[formatted_name] = buddy
        end
        buddy
      end
      
      # Decodes the buddy list from raw CONFIG data.
      def decode_toc(val) # :nodoc:
        current_group = nil
        val.each_line do | line |
          letter, name = *line.split(":")
          name = name.chomp
          case letter
          when "g"
            add_group(name, :dont_sync)
            current_group = name
          when "b"
            add_buddy(current_group, name, :dont_sync)
          end
        end
      end
    end

    # A high-level interface to TOC. It supports asynchronous message handling through the use of threads, and maintains a list of buddies.
    class Client
      include TOC
      
      attr_reader :buddy_list, :screen_name
      
      # You must initialize the client with your screen name and password.
      # If a block is given, Client#listen will be invoked with the block after initialization.
      def initialize(screen_name, password, &optional_block) # :yields: message, buddy, auto_response, client
        @conn = Connection.new(screen_name)
        @screen_name = format_screen_name(screen_name)
        @password = password
        @callbacks = {}
        @buddy_list = BuddyList.new(@conn)
        add_callback(:config, :config2) { |v| @buddy_list.decode_toc v }
        add_callback(:update_buddy, :update_buddy2) { |v| update_buddy v }
        on_error do | error |
          $stderr.puts "Error: #{error}"
        end
        listen(&optional_block) if block_given?
      end
      
      # Connects to the server and starts an event-handling thread.
      def connect(server="toc.oscar.aol.com", port=9898, oscar_server="login.oscar.aol.com", oscar_port=5190)
        @conn.open(server, port)
        code = 7696 * @screen_name[0] * @password[0]
        @conn.toc2_signon(oscar_server, oscar_port, @screen_name, roasted_pass, "english", "\"TIC:toc.rb\"", 160, code)

        @conn.recv do |msg, val|
          if msg == :sign_on
            @conn.toc_add_buddy(@screen_name)
            @conn.toc_init_done
            capabilities.each do |capability|
              @conn.toc_set_caps(capability)
            end
          end
        end
        @thread.kill unless @thread.nil? # ha
        @thread = Thread.new { loop { event_loop } }
      end
      
      # Disconnects and kills the event-handling thread.  You may still add callbacks while disconnected.
      def disconnect
        @thread.kill unless @thread.nil?
        @thread = nil
        @conn.close
      end
      
      # Connects to the server and forwards received IMs to the given block. See Client#connect for the arguments.
      def listen(*args) # :yields: message, buddy, auto_response, client
        on_im do | message, buddy, auto_response |
          yield message, buddy, auto_response, self
        end
        connect(*args)
        wait
      end
      
      # Pass a block to be called every time an IM is received. This will replace any previous on_im handler.
      def on_im
        raise ArgumentException, "on_im requires a block argument" unless block_given?
        add_callback(:im_in, :im_in2) do |val|
          screen_name, auto, f2, *message = *val.split(":")
          message = message.join(":")
          buddy = @buddy_list.buddy_named(screen_name)
          auto_response = auto == "T"
          yield message, buddy, auto_response
        end
      end
      # received event: :im_in2 => "remitaylor:F:F:hi"
      
      # remi
      def keep_track_of_rooms_joined
        @keeping_track_of_rooms_joined = true
        add_callback(:chat_join) do |val|
          room_id, room_name = *val.split(":")
          puts "joined chat room #{ room_name } [#{ room_id }]"
          @rooms ||= { }
          @rooms[room_id] = room_name # not an object for now, just strings!
        end
      end
      def keeping_track_of_rooms_joined?
        @keeping_track_of_rooms_joined
      end

      # JOIN & SEND should be on a Room object ... maybe

      # remi
      def join_chat room_name
        @conn.toc_chat_join 4, room_name if room_name
      end

      # remi
      def send_chat room_name, message
        room = @rooms.find {|id,name| name == room_name } # end up with nil or [ '1234', 'the_name' ]
        room_id = room.first || room_name
        puts "i wanna send #{ message } to room with name #{ room_name } and therefore, id #{ room_id }"
        message = "\"" + format_message(message) + "\""
        @conn.toc_chat_send room_id, message
      end

      # remi
      # Pass a block to be called every time an IM is received. This will replace any previous on_im handler.
      def on_chat
        raise ArgumentException, "on_chat requires a block argument" unless block_given?
        keep_track_of_rooms_joined unless keeping_track_of_rooms_joined?
        add_callback(:chat_in) do |val|
          puts "chat_in val => #{ val.inspect }"
          room_id, screen_name, auto, *message = *val.split(":")
          message = message.join(":")
          message = message.chomp.gsub(/<[^>]+>/,"") # get rid of html
          buddy = @buddy_list.buddy_named(screen_name)
          room = @rooms[room_id] || room_id
          auto_response = auto == "T"
          yield message, buddy, room, auto_response
        end
      end
      # received event: :chat_in => "820142221:remitaylor:F:<HTML>w00t</HTML>"
      
      # Pass a block to be called every time an error occurs. This will replace any previous on_error handler, including the default exception-raising behavior.
      def on_error
        raise ArgumentException, "on_error requires a block argument" unless block_given?
        add_callback(:error) do |val|
          code, param = *val.split(":")
          error = ErrorCode[code.to_i]
          error = "An unknown error occurred." if error.nil?
          error.gsub!("<param>", param) unless param.nil?
          yield error
        end
      end
      
      # Sets your status to away and +away_message+ as your away message.
      def go_away(away_message)
        @conn.toc_set_away "\"#{away_message.gsub("\"","\\\"")}\""
      end
      
      # Sets your status to available.
      def come_back
        @conn.toc_set_away
      end
      
      # Sets your idle time in seconds. You only need to set this once; afterwards, the server will keep track itself.
      # Set to 0 to stop being idle.
      def idle_time=(seconds)
        @conn.toc_set_idle seconds
      end

      def clear_callbacks!
        @callbacks = { }
      end
      
      # Waits for the event-handling thread for +limit+ seconds, or indefinitely if no argument is given. Use this to prevent your program from exiting prematurely.
      # For example, the following script will exit right after connecting:
      #   client = Net::TOC.new("screenname", "p455w0rd")
      #   client.connect
      # To prevent this, use wait:
      #   client = Net::TOC.new("screenname", "p455w0rd")
      #   client.connect
      #   client.wait
      # Now the program will wait until the client has disconnected before exiting.
      def wait(limit=nil)
        @thread.join limit
      end
      
      # Returns a list of this client's capabilities.  Not yet implemented.
      def capabilities
        [] # TODO
      end
      
      private
      
      # Returns an "encrypted" version of the password to be sent across the internet.
      # Decrypting it is trivial, though.
      def roasted_pass
        tictoc = "Tic/Toc".unpack "c*"
        pass = @password.unpack "c*"
        roasted = "0x"
        pass.each_index do |i|
          roasted << sprintf("%02x", pass[i] ^ tictoc[i % tictoc.length])
        end
        roasted
      end
      
      def update_buddy(val)
        screen_name = val.split(":").first.chomp
        buddy = @buddy_list.buddy_named(screen_name)
        buddy.raw_update(val)
      end
      
      def add_callback(*callbacks, &block)
        callbacks.each do |callback|
          @callbacks[callback] = block;
        end
      end
      
      def event_loop
        @conn.recv do |msg, val|
          puts "received event: #{ msg.inspect } => #{ val.inspect }" # remi
          @callbacks[msg].call(val) unless @callbacks[msg].nil?
        end
      end
    end
  end
end
