require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/printer'
require 'optparse'

module Fire
  class Options

    attr_reader :hosts_file
    attr_reader :remote_cmd
    attr_reader :scp_files
    attr_reader :user
    attr_reader :rsa_key
    attr_reader :do_password
    attr_reader :skip_password
    attr_reader :skip_pubkey
    attr_reader :do_kinit
    attr_reader :log_file
    attr_reader :timeout
    attr_reader :debug
    attr_reader :color

    attr_accessor :verbose
    attr_accessor :jobs

    def initialize(argv)
      @hosts_file  = nil
      @remote_cmd  = ""
      @scp_files   = []
      @jobs        = 2
      @user        = ENV['USER'] || ENV['USERNAME'] || "root"
      @rsa_key     = ""
      @do_password = false
      @skip_password = false
      @skip_pubkey = false
      @do_kinit    = false
      @log_file    = nil
      @timeout     = 2
      @verbose     = false
      @debug       = false
      @color       = STDOUT.isatty
      $COLOR       = @color
      $DEBUG       = @debug
      @printer     = Printer.new
      parse(argv)
    end

  private
    def parse(args)
      # '25' is num cols allowed for option synopsis
      # (meaning the rest are used for summary/description)
      OptionParser.new(nil, 25) do |opts|

        opts.banner = <<'BANNER'
 Usage: fire [options] <CMD>

 For short-hand, "--command" may be omitted from the CMD argument. Hostnames
 are read from stdin unless the --file option is used. In-flight status can be
 shown with Ctrl+\ (SIGQUIT) and debugging output can be toggled by sending
 SIGHUP. Your password is verified agianst Kerberos.

BANNER

        opts.on('-c', '--command CMD',
            "Remote command to execute on each host") do |str|
          @remote_cmd = str
        end

        opts.on('-f', '--file FILE',
            "File containing hosts, one per line") do |str|
          @hosts_file = str
        end

        opts.on('-s', '--scp FILE,...', Array,
            "Files to scp ~home/ before running CMD") do |arr|
          @scp_files += arr
        end

        opts.on('-j', '--jobs NUM', Integer,
            "Number of simultaneous threads to spawn (default: 2)") do |int|
          @jobs = int
        end

        opts.on('-u', '-l', '--user USER',
            "User to ssh as (default: $USER)") do |str|
          @user = str
        end

        opts.on('-i', '--identity FILE', "RSA key to use") do |key|
          @rsa_key = key
        end

        opts.on('-p', '--password', "Prompt for user password") do
          @do_password = true
        end

        opts.on('-P', '--no-password', "Don't use passwords at all") do
          @skip_password = true
        end

        opts.on('--no-pubkey', "Don't try pubkey authentication") do
          @skip_pubkey = true
          @do_password = true
        end

        opts.on('-k', '--kinit', "Prompt for user password using kinit(1)") do
          @do_kinit = true
          @do_password = true
        end

        opts.on('-o', '--output FILE',
            "Where to log all output (default: ~/.fire/XXX.log)") do |str|
          @log_file = str
        end

        opts.on('-w', '--wait TIMEOUT', Integer,
            "Seconds to wait for initial connect (default: 2)") do |int|
          @timeout = int
        end

        opts.on('-v', '--verbose',
            "Print command output to screen in addition to log") do
          @verbose = true
        end

        opts.on('-d', '--debug', "Print debugging information") do
          @debug = true
          $DEBUG = true
        end

        opts.on('-n', '--no-color', "Your life is boring") do
          @color = false
          $COLOR = false
        end

        opts.on('-h', '--help', "This useless garbage") do
          @printer.draw_logo($COLOR)
          puts opts, <<'EOF'

 Examples:

 fire --command "/sbin/ifconfig bond0" --file hosts
 fire --scp /tmp/script.sh -c ./script.sh -f hosts --verbose
 grep foo list.txt | fire -vj30 uptime

EOF
          exit
        end

        begin
          args = ['-h'] if args.empty?
          opts.parse!(args)
        rescue OptionParser::ParseError => e
          $stderr.puts e.message, "\n", opts
          exit(-1)
        end
      end #OptionParser block

      if @remote_cmd.empty? && args.any?
        @remote_cmd = args.shift
      end

      if @remote_cmd.empty? && @scp_files.empty?
        raise ArgumentError.new("Missing argument `--command' or `--scp' " +
          "(see --help).")
        exit(-1)
      end

      if @skip_password
        if @skip_pubkey
          raise ArgumentError.new("Bad options: Can't skip both pubkey and " +
            "password auth.")
          exit(-1)
        end
        if @do_kinit or @do_password 
          raise ArgumentError.new("Invalid combination of password options;" +
            " do you require a password or not? :-)")
          exit(-1)
        end
      end

      if @remote_cmd =~ /sudo /
        @do_password = true unless @skip_password
      end
    end #def parse

  end #class Options
end #module Fire
