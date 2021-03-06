class ActiveRecord::Base

  def self.establish_connection(spec = ENV["DATABASE_URL"])
    resolver = ConnectionSpecification::Resolver.new spec, configurations
    spec = resolver.spec

    unless respond_to?(spec.adapter_method)
      raise AdapterNotFound, "database configuration specifies nonexistent #{spec.config[:adapter]} adapter"
    end

    remove_connection
    specification_cache[connection_pool_name] = spec
    connection_handler.establish_connection connection_pool_name, spec
  end
end
