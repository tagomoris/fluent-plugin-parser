class Fluent::DeparserFilter < Fluent::Filter
  Fluent::Plugin.register_filter('deparser', self)

  config_param :format, :string
  config_param :format_key_names, :string
  config_param :key_name, :string, default: 'message'
  config_param :reserve_data, :bool, default: false

  def configure(conf)
    super

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
        new_record = {@key_name => (@format % @format_key_names.map{|k| record[k]})}
        new_es.add(time, record.merge(new_record))
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
