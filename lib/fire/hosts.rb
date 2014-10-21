require 'fcntl'

module Fire
  class Hosts
    attr_accessor :names

    def initialize()
      @names = []
    end

    def remove(hosts)
      @names.delete_if { |x| hosts.include? x }
    end

    def read_stdin()
      if STDIN.fcntl(Fcntl::F_GETFL, 0) == 0
        # read from stdin
        STDIN.readlines.each do |line|
          next if (line =~ /^\s*#/)  # skip comments
          @names << line.strip
        end
        @names.uniq!

        # reopen stdin so it's usable again
        STDIN.reopen("/dev/tty") rescue IO.for_fd(2)
      end
    end

    def read_file(file)
      begin
        File.readlines(file).each do |line|
          next if (line =~ /^\s*#/)  # skip comments
          @names << line.strip
        end
      rescue Exception => e
        $stderr.puts e.message
        exit(1)
      end
      @names.uniq!
    end

  end #class Hosts
end #module Fire
