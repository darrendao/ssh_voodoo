require 'thread_pool'
require 'rubygems'
require 'net/ssh'
require 'thread'

require 'etc'

class SshVoodoo
  
  def initialize(options = nil)
    @sudo_pw = nil
    @pw_prompts = {}
    @mutex = Mutex.new
    @max_worker = 4
    @abort_on_failure = false
    @use_ssh_key = false
    @user = Etc.getlogin
    @password = nil
    @connectiontimeout = options["connectiontimeout"]
    @debug = false
    unless options.nil? or options.empty?
      @user = options["username"] unless options["username"].nil?
      @password = options["deploy-password"] unless options["deploy-password"].nil?
      @max_worker = options["max-worker"] unless options["max-worker"].nil?
      @abort_on_failure = options["abort-on-failure"] unless options["abort-on-failure"].nil?
      @use_ssh_key = options["use-ssh-key"] unless options["use-ssh-key"].nil?
      @ssh_key = options["ssh-key"] unless options["ssh-key"].nil?
      @debug = options["debug"] unless options["debug"].nil?
    end
  end

  def prompt_username
    ask("Username: ")
  end     
         
  def prompt_password
    ask("SSH Password (leave blank if using ssh key): ", true) 
  end

  def ask(str,mask=false)
    begin
      print str
      system 'stty -echo;' if mask
      input = STDIN.gets.chomp
    ensure
      system 'stty echo; echo ""'
    end  
    return input
  end

  def get_sudo_pw
    @mutex.synchronize {
      if @sudo_pw.nil?
        @sudo_pw = ask("Sudo password: ", true)
      else
        return @sudo_pw
      end    
    }
  end

  # Prompt user for input and cache it. If in the future, we see
  # the same prompt again, we can reuse the existing inputs. This saves
  # the users from having to type in a bunch of inputs (such as password)
  def get_input_for_pw_prompt(prompt)
    @mutex.synchronize {
      if @pw_prompts[prompt].nil?
        @pw_prompts[prompt] = ask(prompt, true)
      end
      return @pw_prompts[prompt]
    }
  end

  # Return a block that can be used for executing a cmd on the remote server
  def ssh_execute(server, username, password, key, cmd)
    return lambda { 
      exit_status = 0
      result = []

      params = {}
      params[:password] = password if password
      params[:keys] = [key] if key
      params[:timeout] = @connectiontimeout if @connectiontimeout

      begin
        Net::SSH.start(server, username, params) do |ssh|
          puts "Connecting to #{server}"
          ch = ssh.open_channel do |channel|
            # now we request a "pty" (i.e. interactive) session so we can send data
            # back and forth if needed. it WILL NOT WORK without this, and it has to
            # be done before any call to exec.
  
            channel.request_pty do |ch, success|
              raise "Could not obtain pty (i.e. an interactive ssh session)" if !success
            end
  
            channel.exec(cmd) do |ch, success|
              puts "Executing #{cmd} on #{server}" if @debug
              # 'success' isn't related to bash exit codes or anything, but more
              # about ssh internals (i think... not bash related anyways).
              # not sure why it would fail at such a basic level, but it seems smart
              # to do something about it.
              abort "could not execute command" unless success
  
              # on_data is a hook that fires when the loop that this block is fired
              # in (see below) returns data. This is what we've been doing all this
              # for; now we can check to see if it's a password prompt, and
              # interactively return data if so (see request_pty above).
              channel.on_data do |ch, data|
                if data =~ /Password:/
                  password = get_sudo_pw unless !password.nil? && password != ""
                  channel.send_data "#{password}\n"
                elsif data =~ /password/i or data  =~ /passphrase/i or 
                      data =~ /pass phrase/i or data =~ /incorrect passphrase/i
                  input = get_input_for_pw_prompt(data)
                  channel.send_data "#{input}\n"
                else
                  result << data unless data.nil? or data.empty?
                end
              end
  
              channel.on_extended_data do |ch, type, data|
                print "SSH command returned on stderr: #{data}"
              end
  
              channel.on_request "exit-status" do |ch, data| 
                exit_status = data.read_long
              end
            end
          end
          ch.wait
          ssh.loop
        end  
        puts "==================================================\nResult from #{server}:" 
        puts result.join 
        puts "=================================================="

      rescue Net::SSH::AuthenticationFailed
        exit_status = 1
        puts "Bad username/password combination for host #{server}"
      rescue Exception => e
        exit_status = 1
        puts e.inspect if @debug
        puts e.backtrace if @debug
        puts "Can't connect to #{server}"
      end

      return exit_status
    }
  end

  # servers is an array, a filename or a callback that list the remote servers where we want to ssh to
  def perform_magic(cmd, servers)
    user = @user

    if @user.nil?  && !@use_ssh_key
      @user = prompt_username
    end

    if @password.nil? && !@use_ssh_key
      @password = prompt_password
    end

    tp = ThreadPool.new(@max_worker)
    statuses = {}
    ssh_to = []
    if servers.kind_of?(Proc)
      ssh_to = servers.call
    elsif servers.size == 1 && File.exists?(servers[0])
      puts "Reading server list from file #{servers[0]}"
      File.open(servers[0], 'r') do |f|
        while line = f.gets
          ssh_to << line.chomp.split(",")
        end
      end
      ssh_to.flatten!
    else
      ssh_to = servers
    end

    ssh_to.each do | server |
      tp.process(server) do
        status = ssh_execute(server, @user, @password, @ssh_key, cmd).call
        statuses[server] = status
      end
    end
    tp.shutdown
  
    failed =  statuses.reject{|k,v| v == 0}.keys
    if failed.empty?
      puts "Command ran successfully on all hosts."
    else
      puts "Command failed to run on the following hosts:\n"
      puts failed
    end

    return statuses
  end
end
