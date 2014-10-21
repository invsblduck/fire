require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/options'
require 'fire/threader'
require 'fire/printer'
require 'fire/writer'
require 'fire/errors'
require 'fire/pinger'
require 'fire/helper'
require 'fire/hosts'
require 'fire/ssh'

module Fire
  class Runner
    def initialize(argv)
      @argv     = argv.clone
      @options  = Options.new(argv)
      @printer  = Printer.new
      @writer   = Writer.new(@options.log_file)
      @errors   = Errors.new
      @helper   = Helper.new
      @started  = false
      @threader = nil
      @ssh_errs = []
    end

    def start()
      setup_signal_traps
      setup_host_list
      setup_logging
      @printer.draw_logo($COLOR)
      ping_hosts
      get_passwd
      do_ssh
      finish
    end

  private
    def setup_signal_traps()
      trap_ctrl_c
      trap_other_sigs
      trap_exit
    end

    def trap_ctrl_c()
      trap "SIGINT" do
        puts "\n", @printer.magenta("punt!")
        system("stty echo")
        if @threader
          @printer.info("Cleaning up threads...")
          Thread.list.each { |t| t.exit unless t == Thread.main }
        end
        exit(2)
      end
    end

    def trap_other_sigs()
      %w(SIGQUIT SIGUSR1).each do |sig|
        trap(sig) { (puts; show_status) if @started }
      end
      trap("SIGHUP") { $DEBUG = $DEBUG ? false : true }
    end

    def trap_exit()
      trap "EXIT" do
        if @started
          @ssh_errs.each do |e|
            @errors.connect += e.connect
            @errors.command += e.command
            @errors.sftp    += e.sftp
          end

          unless ((@hosts.names.size <= 10 && ! @options.verbose) ||
                  (@hosts.names.size == 1  &&   @options.verbose))
            @errors.summarize(@printer)
          end

          puts
          @writer.coalesce_logs do |fh|
            fh.puts "# #{$0} " + @argv.join(" ")
            @writer.draw_logo(fh)

            fh.puts "# Host list: " + @hosts_all.join(' ')

            summary = @errors.summarize(@writer)
            if (summary.length > 0)
              fh.puts summary
            end
            fh.puts
          end #@writer.coalesce_logs
        end #if @started
      end #trap "EXIT"
    end

    def setup_host_list()
      @hosts = Hosts.new
      @hosts.read_stdin
      @hosts.read_file(@options.hosts_file) if (@options.hosts_file)

      if @hosts.names.empty?
        @printer.err("you must supply some host names (see --help)")
        exit(1)
      end

      # save complete list of hosts for logging purposes
      @hosts_all = @hosts.names.clone
      @printer.debug("hosts: " + @helper.array_to_s(@hosts.names) )

      # do we have more threads than hosts?
      if @options.jobs > @hosts_all.length
        @options.jobs = @hosts_all.length
      end
    end

    def setup_logging()
      # create ~/.fire
      if ! @writer.create_dot_dir
        @printer.warn("Couldn't create #{FIREDIR}: #{e.message}")
        @printer.warn("All output will go to stdout!")
        @options.verbose = true
      end

      # ensure we can write to our log
      if ! @writer.check_log_file
        if @options.log_file
          # can't write user's log
          puts @printer.magenta("exiting.")
          exit(1)
        end
        # just ignore default log
        @options.verbose = true
      end
    end

    def ping_hosts()
      @printer.info("Ping scanning #{@hosts.names.size} hosts...")
      ping_threader = Threader.new(@options.jobs)
      unreachable = []
      @hosts.names.each do |host|
        ping_threader.dispatch do
          pinger = Pinger.new(host, @options.timeout)
          pinger.scan
          unreachable += pinger.hosts_down
        end
      end
      ping_threader.wait
      sort_unreachable_hosts(unreachable)

      # do we have more threads than alive hosts?
      if @options.jobs > @hosts.names.length
        @options.jobs = @hosts.names.length
      end
    end

    def sort_unreachable_hosts(downers)
      if downers.any?
        @printer.warn("Couldn't connect port 22 on:\n\n")
        downers.sort.each do |host|
          $stderr.puts "            #{host}"
        end
        puts
        @printer.user("Continue? [Y/n]: ")
        answer = gets.strip
        exit(1) unless (answer.empty? || answer =~ /^\s*y/i)
        @hosts.remove(downers)
        @errors.ping += downers
      end
    end

    def get_passwd()
      if @options.do_password
        ENV['PATH'] += ":/usr/kerberos/bin"
        while true
          @printer.user("Enter your password: ")
          system("stty -echo")
          @password = gets.strip
          puts; system("stty echo")

          # get out unless user wants kinit
          break unless @options.do_kinit
          # don't verify root user against kdc
          break if @options.user == "root"

          @printer.debug("proceeding with kinit")
          IO.popen("kinit #{@options.user}", 'r+') do |pipe|
            pipe << "#{@password}\n"
            pipe.close_write
            pipe.read
          end
          break if $?.success?
          puts
        end #while true
        puts
      end #if @options.do_password
    end

    def do_ssh()
      @threader = Threader.new(@options.jobs)
      @started  = Time.now.to_i # seconds

      if @threader.max_jobs > 1
        @printer.info "Starting #{@threader.max_jobs} concurrent sessions ..."
      end

      @hosts.names.each do |host|
        @threader.dispatch do |mutex|
          ssh = Ssh.new(@options, @password, @writer, mutex)
          ssh.run(host)
          @ssh_errs << ssh.errors
        end
      end
      @threader.wait
    end

    def finish()
      time = @helper.convert_seconds(Time.now.to_i - @started)
      @printer.info(@printer.green("completed in #{time}"))
    end

    def show_status()
      num_total  = @hosts.names.size
      num_remain = Thread.list.size - 1  # don't count main thread
      #num_active = @threader.active.size

      num_finished = num_total - num_remain
      quotient = num_finished.to_f / num_total.to_f

      percent = quotient.to_s
      percent = percent[2..3]
      percent.gsub!(/^0/, '')   # remove leading zero (if any)

      time = @helper.convert_seconds(Time.now.to_i - @started)
      hdr  = @printer.yellow(">>>>>> STATUS: #{percent}% complete", 1)

      @printer.info(nil)
      @printer.info("#{hdr} (#{num_finished} of #{num_total} hosts " +
        "finished, #{time} elapsed)")
      @printer.info(nil)
    end

  end #class Run
end #module Fire
