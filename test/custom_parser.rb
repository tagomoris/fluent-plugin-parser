module Fluent
  class TextParser
    class KVPairParser < Parser
      Plugin.register_parser('kv_pair', self)

      # key<delim1>value is pair and <pair><delim2><pair> ...
      # newline splits records
      include Configurable

      config_param :delim1, :string
      config_param :delim2, :string

      config_param :time_key, :string, :default => "time"
      config_param :time_format, :string, :default => nil # time_format is configurable

      def configure(conf)
        super
        @time_parser = TimeParser.new(@time_format)
      end

      def parse(text)
        text.split("\n").each do |line|
          pairs = text.split(@delim2)
          record = {}
          time = nil
          pairs.each do |pair|
            k, v = pair.split(@delim1, 2)
            if k == @time_key
              time = @time_parser.parse(v)
            else
              record[k] = v
            end
          end
          yield time, record
        end
      end
    end
  end
end
