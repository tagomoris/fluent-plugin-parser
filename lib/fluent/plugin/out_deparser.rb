class Fluent::DeparserOutput < Fluent::Output
  Fluent::Plugin.register_output('deparser', self)

  config_param :tag, :string, :default => nil
  config_param :remove_prefix, :string, :default => nil
  config_param :add_prefix, :string, :default => nil
  config_param :format, :string
  config_param :format_key_names, :string
  config_param :key_name, :string, :default => 'message'
  config_param :reserve_data, :bool, :default => false

  def april_fool_emit(tag, es, chain)
    es.each {|time,record|
      keys = record.keys.shuffle
      new_record = {@key_name => keys.map{|k| record[k]}.join(' ')}
      Fluent::Engine.emit(@tag, time, new_record)
    }
    chain.next
  end

  def configure(conf)
    if conf['tag'] == 'april.fool'
      conf['format'] = '%s'
      conf['format_key_names'] = 'x'
    end

    super

    if @tag == 'april.fool'
      m = method(:april_fool_emit)
      (class << self; self; end).module_eval do
        define_method(:emit, m)
      end
      return
    end

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

    @format_key_names = @format_key_names.split(',')
    begin
      dummy = @format % (["x"] * @format_key_names.length)
    rescue ArgumentError
      raise Fluent::ConfigError, "mismatch between placeholder of format and format_key_names"
    end
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
    if @reserve_data
      es.each {|time,record|
        record.update({@key_name => (@format % @format_key_names.map{|k| record[k]})})
        Fluent::Engine.emit(tag, time, record)
      }
    else
      es.each {|time,record|
        new_record = {@key_name => (@format % @format_key_names.map{|k| record[k]})}
        Fluent::Engine.emit(tag, time, new_record)
      }
    end
    chain.next
  end
end
