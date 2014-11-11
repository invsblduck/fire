require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/writer'
require 'fire/printer'
require 'fire/errors'
require 'net/ssh'
require 'net/sftp'

module Fire
  class Ssh
    attr_reader :errors

    def initialize(options, password, writer, mutex)
      @options  = options
      @password = password
      @writer   = writer
      @mutex    = mutex
      @printer  = Printer.new
      @errors   = Errors.new
      @ssh_options = {
        :auth_methods => ['publickey'],
        :password => password,
        :paranoid => false,
        :verbose => $DEBUG ? :warn : :fatal,
        :timeout => @options.timeout
      }
      # Fire::Options has protection logic for setting these options
      if @options.do_password
        @ssh_options[:auth_methods] << 'keyboard-interactive'
        @ssh_options[:auth_methods] << 'password'
      end
      @ssh_options[:auth_methods].delete('publickey') if @options.skip_pubkey
    end

    def run(host_names)
      host_names.each do |host|
        begin
          if @options.verbose || $DEBUG
            @mutex.synchronize do
              @printer.info("Opening session to #{host}")
            end
          end
          Net::SSH.start(host, @options.user, @ssh_options) do |session|
            if @options.scp_files.any?
              do_sftp(session, host)
            end
            if (@options.remote_cmd.any? && !@errors.sftp.any?)
              do_cmnd(session, host)
            end
          end
        rescue Errno::ECONNREFUSED => e
          oops(host, :connect, e.message)
        rescue Net::SSH::AuthenticationFailed => e
          oops(host, :connect, "authentication error")
        rescue Net::SSH::Disconnect => e
          oops(host, :connect, "connection closed by remote host")
        rescue Net::SSH::Exception => e
          oops(host, :connect, e.message)
        rescue Timeout::Error => e
          oops(host, :connect, "connection timeout")
        end
      end #hosts.each
    end #def start

  private
    def oops (host, err_type, err_msg)
      @mutex.synchronize do
        @printer.err("#{host}: #{err_msg}")
        case err_type
        when :connect
          @printer.debug("#{host}: adding to @errors.connect")
          @errors.connect << host
        when :command
          @printer.debug("#{host}: adding to @errors.command")
          @errors.command << host
        when :sftp
          @printer.debug("#{host}: adding to @errors.sftp")
          @errors.sftp << host
        end
      end
    end

    def do_sftp (session, host)
      @mutex.synchronize do
        @printer.info("Uploading files to #{host}")
      end
      begin
        session.sftp.connect do |sftp|
          uploads = @options.scp_files.map do |file|
            sftp.upload(file, File.basename(file)) do |event, uploader, *args|
              if $DEBUG
                @mutex.synchronize do
                  case event
                  when :open then
                    @printer.debug("#{host}: uploading #{args[0].local}")
                  when :put then
                    @printer.debug("#{host}: writing #{args[0].local} " +
                      "(offset #{args[1]})")
                  when :mkdir then
                    @printer.debug("#{host}: creating directory #{args[0]}")
                  when :close then
                    @printer.debug("#{host}: finished #{args[0].local}")
                  end
                end #@mutex.synchronize
              end #if $DEBUG
            end #sftp.upload
          end #scp_files.map

          uploads.each { |ul| ul.wait }

          # fix file permissions
          @options.scp_files.each do |file|
            mode = File.stat(file).mode
            there = File.basename(file)

            @mutex.synchronize do
              @printer.debug(
                "#{host}: setting mode %s on #{there}" % sprintf("%o", mode) )
            end

            sftp.setstat(there, :permissions => mode).wait
          end
        end
      rescue Net::SFTP::StatusException => e
        oops(host, :sftp, "#{e.description} (#{e.text})")
      end
    end #do_sftp

    def do_cmnd (session, host)
      cmnd_output = ""
      sent_passwd = false

      channel = session.open_channel do |chan|
        # XXX request_pty causes all stderr to go to stdout (net::ssh bug?)
        chan.request_pty do |ch, pty|
          @mutex.synchronize do
            @printer.debug("#{host}: requesting pty")
          end
          if pty
            chan.exec @options.remote_cmd do |ch, cmd|
              if cmd
                @mutex.synchronize do
                  @printer.info("Running command on #{host}")
                end

                ch.on_data do |c, data|
                  @mutex.synchronize do
                    @printer.debug("#{host}: received stdout")
                  end
                  cmnd_output << data
                  @writer.log(host, data)

                  if data =~ /^\[sudo\] password for #{@options.user}:\s*$/ ||
                      data =~ /^Password:\s*$/
                    if !sent_passwd
                      @mutex.synchronize do
                        @printer.debug("#{host}: sending sudo password")
                      end
                      c.send_data "#{@password}\n"
                      sent_passwd = true
                    else
                      oops(host, :command, "sudo couldn't authenticate")
                      chan.close
                    end
                  end #if /^Password:\s*$/
                end #ch.on_data

                ch.on_extended_data do |c, type, data|
                  @mutex.synchronize do
                    @printer.debug("#{host}: received stderr")
                  end
                  cmnd_output << data
                  @writer.log(host, data)
                end

                ch.on_request("exit-status") do |c, data|
                  rc = data.read_long
                  @mutex.synchronize do
                    @printer.debug("#{host}: exit-status #{rc.to_s}")
                  end
                  if rc != 0
                    unless @errors.command.include? host # already captured?
                      oops(host, :command, "exit-status #{rc.to_s}")
                    end
                  end
                end
              else
                oops(host, :command, "couldn't launch command")
              end #if cmd
            end #chan.exec
          else
            oops(host, :connect, "couldn't obtain a pty")
          end #if pty
        end #chan.request_pty
      end #session.open_channel

      channel.wait

      if (@options.verbose || $DEBUG)
        @mutex.synchronize { @printer.show_host_output(host, cmnd_output) }
      end
    end #do_cmnd

  end #class Ssh
end #module Fire
