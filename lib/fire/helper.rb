module Fire
  class Helper
    def array_to_s(ary)
      '["' + ary.join('", "') + '"]'
    end

    def convert_seconds(s)
      case
      when s < 60
        "#{s}s"
      when s < 3600
        "#{s/60}m#{s%60}s"
      when s >= 3600
        hrs = s/60/60
        s/=60
        "#{hrs}h#{s/60}m#{s%60}s"
      end
    end
  end #class
end #module
