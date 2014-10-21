require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/printer'  # for debugging messages

module Fire
  class Writer
    FIREDIR = ENV['HOME'] + "/.fire"
    FIRELOG = FIREDIR + "/" + Time.now.strftime("%Y%m%d_%H%M%S.log")

    attr_accessor :log_file
    attr_accessor :writable

    def initialize(log_file=nil)
      @log_file = log_file || FIRELOG
      @writable = true
      @printer  = Printer.new
    end

    def create_dot_dir()
      if ! File.directory? FIREDIR
        begin
          @printer.debug("creating #{FIREDIR}")
          Dir.mkdir FIREDIR
        rescue SystemCallError => e
          @writable = false
        end
      end
      return @writable
    end

    def check_log_file()
      @printer.debug("checking for #{@log_file}")

      # check that directory exists and is writable
      dirname = File.dirname(@log_file)
      if File.directory? dirname
        if ! File.writable? dirname
          @printer.warn("#{dirname}: Permission denied")
          @writable = false
        end
      else
          @printer.warn("#{dirname} isn't a directory")
          @writable = false
      end

      # see if log_file already exists
      if File.exists? @log_file
        if File.file? @log_file
          if ! File.writable? @log_file
            @printer.warn("#{@log_file}: Permission denied")
            @writable = false
          end
        else
          @printer.warn("#{@log_file} exists and isn't a regular file")
          @writable = false
        end
      end #if File.exists?
      @writable
    end

    def log(host, data)
      return unless @writable
      file = "#{FIREDIR}/#{host}.#{$$}.tmp"
      @printer.debug("writing to #{file}")
      begin
        File.open(file, "a") { |f| f.print data }
      rescue Exception => e
        $stderr.puts e.message
        exit(1)
      end
    end

    def coalesce_logs()
      return unless @writable
      sorted = Dir["#{FIREDIR}/*.#{$$}.tmp"].sort_by { |f| test(?M, f) }
      begin
        File.open(@log_file, "w") do |f|
          yield f if block_given?

          sorted.each do |file|
            host = file[/^.*\/(.*)\.#{$$}\.tmp$/ ,1]
            time = File.new(file).mtime.strftime "%H:%M:%S"

            banner = "===========[ #{host} (#{time}) ]"
            filler = (79 - banner.length)
            banner += '='*filler

            f.puts "#{banner}\n\n"
            File.readlines(file).each do |line|
              f.print "[#{host.gsub(/\.hellajdm\.com/, "")}] #{line}"
            end
            f.puts
            File.delete file
          end
        end
      rescue Exception => e
        $stderr.puts e.message
        # XXX the ~/.fire/*.tmp file will be orphaned
        exit(1)
      end
      @printer.info("output saved to #{@log_file}")
    end

    def draw_logo(fh)
      begin
        File.readlines(Printer::LOGO_TXT).each do |x|
          fh.print x
        end
      rescue Exception => e
        puts e.message
      end
    end

  end #class Writer
end #module Fire
