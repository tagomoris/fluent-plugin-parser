class Fluent::DeparserFilter < Fluent::Output
  Fluent::Plugin.register_filter('deparser', self)

  config_param :tag, :string, :default => nil
  config_param :format, :string
  config_param :format_key_names, :string
  config_param :key_name, :string, :default => 'message'
  config_param :reserve_data, :bool, :default => false

  def april_fool_filter_stream(tag, es)
    new_es = Fluent::MultiEventStream.new
    es.each {|time,record|
      keys = record.keys.shuffle
      new_record = {@key_name => keys.map{|k| record[k]}.join(' ')}
      new_es.add(time, new_record)
    }
    new_es
  end

  def configure(conf)
    if conf['tag'] == 'april.fool'
      conf['format'] = '%s'
      conf['format_key_names'] = 'x'
    end

    super

    if @tag == 'april.fool'
      m = method(:april_fool_filter_stream)
      (class << self; self; end).module_eval do
        define_method(:filter_stream, m)
      end
      return
    end

    @format_key_names = @format_key_names.split(',')
    begin
      dummy = @format % (["x"] * @format_key_names.length)
    rescue ArgumentError
      raise Fluent::ConfigError, "mismatch between placeholder of format and format_key_names"
    end
  end

  def filter_stream(tag, es)
    new_es = Fluent::MultiEventStream.new
    if @reserve_data
      es.each {|time,record|
        record.update({@key_name => (@format % @format_key_names.map{|k| record[k]})})
        new_es.add(time, record)
      }
    else
      es.each {|time,record|
        new_record = {@key_name => (@format % @format_key_names.map{|k| record[k]})}
        new_es.add(time, new_record)
      }
    end
    new_es
  end
end
