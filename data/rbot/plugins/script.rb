# Plugin for the Ruby IRC bot (http://linuxbrit.co.uk/rbot/)
#
# Create mini plugins on IRC.
#
# Scripts are little Ruby programs that run in the context of the script plugin. You 
# can create them directly in an IRC channel, and invoke them just like normal rbot plugins. 
#
# (c) 2006 Mark Kretschmann <markey@web.de>
# Licensed under GPL V2.


Command = Struct.new( "Command", :code, :nick, :created, :channel )


class ScriptPlugin < Plugin

  def initialize
    super
    if @registry.has_key?(:commands)
      @commands = @registry[:commands]
    else
      @commands = Hash.new
    end

    # Migrate old Hash to new:
    @commands.each_pair do |name, cmd|
      unless cmd.instance_of?( Command )
        @commands[name] = Command.new( cmd, 'unknown hacker', 'somedate', '#somechan' )
      end
    end
  end


  def save
    @registry[:commands] = @commands
  end


  def help( plugin, topic="" )
    if topic == "add"
      "Scripts are little Ruby programs that run in the context of the script plugin. You can access @bot (class IrcBot), m (class PrivMessage), user (class String, either the first argument, or if missing the sourcenick), and args (class Array, an array of arguments). Example: 'script add greet m.reply( 'Hello ' + user )'. Invoke the script just like a plugin: '<botnick>: greet'."
    else  
      "Create mini plugins on IRC. 'script add <name> <code>' => Create script named <name> with the code <source>. 'script list' => Show a list of all known scripts. 'script show <name>' => Show the source code for <name>. 'script del <name>' => Delete the script <name>."
    end
  end


  def listen( m )
    name = m.message.split.first

    if m.address? and @commands.has_key?( name )
      code = @commands[name].code.dup.untaint

      # Convenience variables, can be accessed by scripts:
      args = m.message.split
      args.delete_at( 0 ) 
      user = args.empty? ? m.sourcenick : args.first  

      Thread.start {
        $SAFE = 3

        begin
          eval( code )
        rescue => e
          m.reply( "Script '#{name}' crapped out :(" )
          m.reply( e.inspect )
        end
      }
    end
  end


  def handle_add( m, params, force = false )
    name    = params[:name]
    if !force and @commands.has_key?( name )
      m.reply( "#{m.sourcenick}: #{name} already exists. Use 'add -f' if you really want to overwrite it." )
      return
    end

    code    = params[:code].join( " " )
    nick    = m.sourcenick
    created = Time.new.strftime '%Y/%m/%d %H:%m'
    channel = m.target

    command = Command.new( code, nick, created, channel )
    @commands[name] = command

    m.reply( "done" )
  end


  def handle_add_force( m, params )
    handle_add( m, params, true )
  end
    

  def handle_del( m, params )
    name = params[:name]
    unless @commands.has_key?( name )
      m.reply( "Script does not exist." ); return
    end

    @commands.delete( name )
    m.reply( "done" )
  end


  def handle_list( m, params )
    if @commands.length == 0
      m.reply( "No scripts available." ); return
    end

    cmds_per_page = 30
    cmds = @commands.keys.sort
    num_pages = cmds.length / cmds_per_page + 1
    page = params[:page].to_i
    page = [page, 1].max
    page = [page, num_pages].min
    str = cmds[(page-1)*cmds_per_page, cmds_per_page].join(', ') 

    m.reply "Available scripts (page #{page}/#{num_pages}): #{str}" 
  end


  def handle_show( m, params )
    name = params[:name]
    unless @commands.has_key?( name )
      m.reply( "Script does not exist." ); return
    end

    cmd = @commands[name]
    m.reply( "#{cmd.code} [#{cmd.nick}, #{cmd.created} in #{cmd.channel}]" )
 end

end


plugin = ScriptPlugin.new
plugin.register( "script" )

plugin.map 'script add -f :name *code', :action => 'handle_add_force', :auth => 'scriptedit'
plugin.map 'script add :name *code',    :action => 'handle_add',       :auth => 'scriptedit'
plugin.map 'script del :name',          :action => 'handle_del',       :auth => 'scriptedit'
plugin.map 'script list :page',         :action => 'handle_list',      :defaults => { :page => '1' }
plugin.map 'script show :name',         :action => 'handle_show'

