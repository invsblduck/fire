require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/printer' # for debugging msgs
require 'thread'

module Fire
  class Threader
    MAX_THREADS = 100
    attr_reader :active
    attr_reader :max_jobs

    def initialize(max_jobs)
      @active = []
      @max_jobs = max_jobs < MAX_THREADS ? max_jobs : MAX_THREADS
      @mutex = Mutex.new
      @cv = ConditionVariable.new
      @printer = Printer.new
    end

    def dispatch
      Thread.new do
        @mutex.synchronize do
          while @active.size >= @max_jobs
            @cv.wait(@mutex)
          end
        end

        #@mutex.synchronize { @printer.debug("creating #{Thread.current}") }
        @active << Thread.current

        begin
          yield @mutex
        rescue => e
          @printer.err(
            "Fire::Threader#dispatch: exception in yield(): #{e.inspect}")
        ensure
          @mutex.synchronize do
            @active.delete(Thread.current)
            @cv.signal
          end
        end
      end #Thread.new
    end

    def wait()
      @mutex.synchronize { @cv.wait(@mutex) until @active.empty? }
    end

  end #class
end #module Fire
