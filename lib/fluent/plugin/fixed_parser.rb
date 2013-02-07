#
# This module is copied from fluentd/lib/fluent/parser.rb and
# fixed not to overwrite 'time' (reserve nil) when time not found in parsed string.
module FluentExt; end

class FluentExt::TextParser
  class RegexpParser
    include Fluent::Configurable

    config_param :time_format, :string, :default => nil

    def initialize(regexp, conf={})
      super()
      @regexp = regexp
      unless conf.empty?
        configure(conf)
      end
    end

    def call(text)
      m = @regexp.match(text)
      unless m
        $log.warn "pattern not match: #{text}"
        return nil, nil
      end

      time = nil
      record = {}

      m.names.each {|name|
        if value = m[name]
          case name
          when "time"
            if @time_format
              time = Time.strptime(value, @time_format).to_i
            else
              time = Time.parse(value).to_i
            end
          else
            record[name] = value
          end
        end
      }

      return time, record
    end
  end

  class GenericParser
    include Fluent::Configurable

    config_param :time_key, :string, :default => 'time'
    config_param :time_format, :string, :default => nil

    def parse_time(record)
      time = nil
      if value = record.delete(@time_key)
        time = if @time_format
                 Time.strptime(value, @time_format).to_i
               else
                 Time.parse(value).to_i
               end
      end
      return time, record
    end
  end

  class JSONParser < GenericParser
    def call(text)
      record = Yajl.load(text)
      return parse_time(record)
    rescue Yajl::ParseError
      $log.warn "pattern not match(json): #{text.inspect}: #{$!}"
      return nil, nil
    end
  end

  class LabeledTSVParser < GenericParser
    def call(text)
      record = Hash[text.split("\t").map{|p| p.split(":", 2)}]
      parse_time(record)
    end
  end

  class ValuesParser < GenericParser
    config_param :keys, :string

    def configure(conf)
      super
      @keys = @keys.split(",")
    end

    def values_map(values)
      Hash[@keys.zip(values)]
    end
  end

  class TSVParser < ValuesParser
    config_param :delimiter, :string, :default => "\t"

    def call(text)
      return parse_time(values_map(text.split(@delimiter)))
    end
  end

  class CSVParser < ValuesParser
    def initialize
      super
      require 'csv'
    end

    def call(text)
      return parse_time(values_map(CSV.parse_line(text)))
    end
  end

  class ApacheParser
    include Fluent::Configurable

    REGEXP = /^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$/

    def call(text)
      m = REGEXP.match(text)
      unless m
        $log.warn "pattern not match: #{text.inspect}"
        return nil, nil
      end

      host = m['host']
      host = (host == '-') ? nil : host

      user = m['user']
      user = (user == '-') ? nil : user
      
      time = m['time']
      time = Time.strptime(time, "%d/%b/%Y:%H:%M:%S %z").to_i
      
      method = m['method']
      path = m['path']
      
      code = m['code'].to_i 
      code = nil if code == 0

      size = m['size']
      size = (size == '-') ? nil : size.to_i
      
      referer = m['referer']
      referer = (referer == '-') ? nil : referer
      
      agent = m['agent']
      agent = (agent == '-') ? nil : agent
      
      record = {
        "host" => host,
        "user" => user,
        "method" => method,
        "path" => path,
        "code" => code,
        "size" => size,
        "referer" => referer,
        "agent" => agent,
      } 

      return time, record
    end
  end

  TEMPLATE_FACTORIES = {
    'apache' => Proc.new { RegexpParser.new(/^(?<host>[^ ]*) [^ ]* (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$/, {'time_format'=>"%d/%b/%Y:%H:%M:%S %z"}) },
    'apache2' => Proc.new { ApacheParser.new },
    'nginx' => Proc.new { RegexpParser.new(/^(?<remote>[^ ]*) (?<host>[^ ]*) (?<user>[^ ]*) \[(?<time>[^\]]*)\] "(?<method>\S+)(?: +(?<path>[^ ]*) +\S*)?" (?<code>[^ ]*) (?<size>[^ ]*)(?: "(?<referer>[^\"]*)" "(?<agent>[^\"]*)")?$/,  {'time_format'=>"%d/%b/%Y:%H:%M:%S %z"}) },
    'syslog' => Proc.new { RegexpParser.new(/^(?<time>[^ ]*\s*[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]+)\])?[^\:]*\: *(?<message>.*)$/, {'time_format'=>"%b %d %H:%M:%S"}) },
    'json' => Proc.new { JSONParser.new },
    'csv' => Proc.new { CSVParser.new },
    'tsv' => Proc.new { TSVParser.new },
    'ltsv' => Proc.new { LabeledTSVParser.new },
  }

  def self.register_template(name, regexp_or_proc, time_format=nil)
    
    factory = if regexp_or_proc.is_a?(Regexp)
                regexp = regexp_or_proc
                Proc.new { RegexpParser.new(regexp, {'time_format'=>time_format}) }
              else
                Proc.new { proc }
              end
    TEMPLATE_FACTORIES[name] = factory
  end

  def initialize
    @parser = nil
  end

  def configure(conf, required=true)
    format = conf['format']

    if format == nil
      if required
        raise Fluent::ConfigError, "'format' parameter is required"
      else
        return nil
      end
    end

    if format[0] == ?/ && format[format.length-1] == ?/
      # regexp
      begin
        regexp = Regexp.new(format[1..-2])
        if regexp.named_captures.empty?
          raise "No named captures"
        end
      rescue
        raise Fluent::ConfigError, "Invalid regexp '#{format[1..-2]}': #{$!}"
      end
      @parser = RegexpParser.new(regexp)

    else
      # built-in template
      factory = TEMPLATE_FACTORIES[format]
      unless factory
        raise ConfigError, "Unknown format template '#{format}'"
      end
      @parser = factory.call

    end

    if @parser.respond_to?(:configure)
      @parser.configure(conf)
    end

    return true
  end

  def parse(text)
    return @parser.call(text)
  end
end
