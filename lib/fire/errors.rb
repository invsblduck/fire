require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/printer'

module Fire
  class Errors
    attr_accessor :ping
    attr_accessor :connect
    attr_accessor :command
    attr_accessor :sftp

    def initialize()
      @ping    = []
      @connect = []
      @command = []
      @sftp    = []
      @printer = Printer.new
    end

    def any?()
      @ping.any? || @connect.any? || @command.any? || @sftp.any?
    end

    def summarize(how)
      sum = ""
      sum << s(how, "The following hosts weren't pingable on port 22", @ping)
      sum << s(how, "The following hosts had ssh problems", @connect)
      sum << s(how, "Could not upload files to these hosts", @sftp)
      sum << s(how, "Your command failed on these hosts", @command)
      return sum
    end

  private
    def s(how, header, hosts)
      data = ""
      if hosts.any?
        if how.class.to_s == "Fire::Printer"
          puts
          @printer.info("#{header}:")
          hosts.each { |h| @printer.warn(h) }
        else
          data  = "#\n"
          data += "# #{header}:\n"
          hosts.each { |h| data += "#   #{h}\n" }
        end
      end
      return data
    end

  end #class
end #module
