 module ActiveRecordShards
   module DefaultSlavePatches
    #CLASS_SLAVE_METHODS = [ :find_by_sql, :count_by_sql, :calculate, :find_one, :find_some, :find_every, :quote_value, :sanitize_sql_hash_for_conditions ]
    CLASS_SLAVE_METHODS = [ ]
    def self.extended(base)
      base_methods = (base.methods | base.private_methods).map(&:to_sym)
      (CLASS_SLAVE_METHODS & base_methods).each do |slave_method|
        base.class_eval <<-RUBY, __FILE__, __LINE__ + 1
          class << self
            def #{slave_method}_with_default_slave(*args, &block)
              on_slave_unless_tx do
                #{slave_method}_without_default_slave(*args, &block)
              end
            end

            alias_method_chain :#{slave_method}, :default_slave
          end
        RUBY
      end

      base.class_eval do
        # fix ActiveRecord to do the right thing, and use our aliased quote_value
        # def quote_value(*args, &block)
        #   self.class.quote_value(*args, &block)
        # end

        def reload_with_slave_off(*args, &block)
          self.class.on_master { reload_without_slave_off(*args, &block) }
        end
        alias_method_chain :reload, :slave_off

        class << self
          def columns_with_default_slave(*args, &block)
            if on_slave_by_default? && !Thread.current[:_active_record_shards_slave_off]
              read_columns_from = :slave
            else
              read_columns_form = :master
            end

            on_cx_switch_block(read_columns_from, :construct_ro_scope => false) { columns_without_default_slave(*args, &block) }
          end
          alias_method_chain :columns, :default_slave
        end

        class << self
        #   def transaction_with_slave_off(*args, &block)
        #     if on_slave_by_default?
        #       old_val = Thread.current[:_active_record_shards_slave_off]
        #       Thread.current[:_active_record_shards_slave_off] = true
        #     end

        #     transaction_without_slave_off(*args, &block)
        #   ensure
        #     if on_slave_by_default?
        #       Thread.current[:_active_record_shards_slave_off] = old_val
        #     end
        #   end

        #   alias_method_chain :transaction, :slave_off


        #   def table_exists_with_default_slave?(*args)
        #     on_slave_unless_tx(*args) { table_exists_without_default_slave?(*args) }
        #   end

        #   alias_method_chain :table_exists?, :default_slave
         end
      end


      
    end

    def on_slave_unless_tx(&block)
      if on_slave_by_default? && !Thread.current[:_active_record_shards_slave_off]
        on_slave { yield }
      else
        yield
      end
    end
  end
 end
