require 'pathname'

module Fire
  class Printer

    LOGO_TXT  = Pathname.new(__FILE__).parent.to_s + "/logo.txt"
    LOGO_ANSI = Pathname.new(__FILE__).parent.to_s + "/logo.ansi"

    def debug(msg)
      if $DEBUG
        tag = "[_debug]"
        if $COLOR # two-tone cyan
          tag = cyan(tag,1)
          msg = cyan(msg)
        end
        puts "#{tag} #{msg}"
      end
    end

    def info(msg)
      tag = "[ info ]"
      tag = green(tag,1) if $COLOR
      puts "#{tag} #{msg}"
    end

    def warn(msg)
      tag = "[ warn ]"
      tag = yellow(tag,1) if $COLOR
      $stderr.puts "#{tag} #{msg}"
    end

    def err(msg)
      tag = "[ FAIL ]"
      str = "#{tag} #{msg}" # color whole line
      $stderr.puts $COLOR ? magenta(str,1) : str
    end

    def user(msg)
      tag = "[ user ]"
      if $COLOR
        tag = green("[",1) + blue(" user ",1) + green("]",1)
      end
      print "#{tag} #{msg}" #no newline
    end

    def show_host_output(host, data)
      data.split(/\n/).each do |line|
        tag = "[#{host}]"
        tag = white(tag, 1) if $COLOR
        puts "#{tag} #{line}"
      end
    end

    def draw_logo(color)
      begin
        File.readlines(color ? LOGO_ANSI : LOGO_TXT).each do |x|
          print x
        end
      rescue Exception => e
        puts e.message
      end
    end

    def escape(string)
      "\e[" + string + "\e[0m"
    end

    def black   (msg, bold=0); escape(bold.to_s + ";30m" + msg); end
    def red     (msg, bold=0); escape(bold.to_s + ";31m" + msg); end
    def green   (msg, bold=0); escape(bold.to_s + ";32m" + msg); end
    def yellow  (msg, bold=0); escape(bold.to_s + ";33m" + msg); end
    def blue    (msg, bold=0); escape(bold.to_s + ";34m" + msg); end
    def magenta (msg, bold=0); escape(bold.to_s + ";35m" + msg); end
    def cyan    (msg, bold=0); escape(bold.to_s + ";36m" + msg); end
    def white   (msg, bold=0); escape(bold.to_s + ";37m" + msg); end

  end #class Printer
end #module Fire
