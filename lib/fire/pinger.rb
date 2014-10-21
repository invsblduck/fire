require 'pathname'
$:.unshift(Pathname.new(__FILE__).parent.parent.to_s)

require 'fire/printer'

require 'ping'
require 'resolv-replace'

module Fire
  class Pinger

    attr_reader :hosts_up
    attr_reader :hosts_down
    attr_reader :hosts_all

    def initialize(host_list, timeout=2)
      @hosts_up   = []
      @hosts_down = []
      @hosts_all  = host_list
      @timeout    = timeout
    end

    def scan
      @hosts_all.each do |host|
        (Ping.pingecho(host, @timeout, 22) ? @hosts_up : @hosts_down) << host
      end
    end

  end #class Pinger
end #module Fire
