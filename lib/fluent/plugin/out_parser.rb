require_relative './fixed_parser'

class Fluent::ParserOutput < Fluent::Output
  Fluent::Plugin.register_output('parser', self)

  config_param :tag, :string, :default => nil
  config_param :remove_prefix, :string, :default => nil
  config_param :add_prefix, :string, :default => nil
  config_param :key_name, :string
  config_param :reserve_data, :bool, :default => false
  config_param :inject_key_prefix, :string, :default => nil
  config_param :replace_invalid_sequence, :bool, :default => false
  config_param :hash_value_field, :string, :default => nil

  attr_reader :parser

  def initialize
    super
    require 'time'
  end

  # Define `log` method for v0.10.42 or earlier
  unless method_defined?(:log)
    define_method("log") { $log }
  end

  def configure(conf)
    super

    if not @tag and not @remove_prefix and not @add_prefix
      raise Fluent::ConfigError, "missing both of remove_prefix and add_prefix"
    end
    if @tag and (@remove_prefix or @add_prefix)
      raise Fluent::ConfigError, "both of tag and remove_prefix/add_prefix must not be specified"
    end
    if @remove_prefix
      @removed_prefix_string = @remove_prefix + '.'
      @removed_length = @removed_prefix_string.length
    end
    if @add_prefix
      @added_prefix_string = @add_prefix + '.'
    end

    @parser = FluentExt::TextParser.new(log())
    @parser.configure(conf)
  end

  def emit(tag, es, chain)
    tag = if @tag
            @tag
          else
            if @remove_prefix and
                ( (tag.start_with?(@removed_prefix_string) and tag.length > @removed_length) or tag == @remove_prefix)
              tag = tag[@removed_length..-1]
            end
            if @add_prefix
              tag = if tag and tag.length > 0
                      @added_prefix_string + tag
                    else
                      @add_prefix
                    end
            end
            tag
          end
    es.each do |time,record|
      raw_value = record[@key_name]
      t,values = raw_value ? parse(raw_value) : [nil, nil]
      t ||= time

      if values && @inject_key_prefix
        values = Hash[values.map{|k,v| [ @inject_key_prefix + k, v ]}]
      end
      r = @hash_value_field ? {@hash_value_field => values} : values
      if @reserve_data
        r = r ? record.merge(r) : record
      end
      if r
        Fluent::Engine.emit(tag, t, r)
      end
    end

    chain.next
  end

  private

  def parse(string)
    return @parser.parse(string) unless @replace_invalid_sequence

    begin
      @parser.parse(string)
    rescue ArgumentError => e
      unless e.message.index("invalid byte sequence in") == 0
        raise
      end
      replaced_string = replace_invalid_byte(string)
      @parser.parse(replaced_string)
    end
  end

  def replace_invalid_byte(string)
    replace_options = { invalid: :replace, undef: :replace, replace: '?' }
    original_encoding = string.encoding
    temporal_encoding = (original_encoding == Encoding::UTF_8 ? Encoding::UTF_16BE : Encoding::UTF_8)
    string.encode(temporal_encoding, original_encoding, replace_options).encode(original_encoding)
  end
end
