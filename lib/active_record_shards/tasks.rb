require 'active_record_shards'

%w[db:drop db:create db:abort_if_pending_migrations db:reset].each do |name|
  Rake.application.instance_variable_get(:@tasks).delete(name) || warn("could not delete #{name} task, potential load-order problem")
end

namespace :db do
  desc 'Drops the database for the current RAILS_ENV including shards and slaves'
  task :drop => :load_config do
    env_name = defined?(Rails.env) ? Rails.env : RAILS_ENV || 'development'
    ActiveRecord::Base.configurations.each do |key, conf|
      if key.starts_with?(env_name) && !key.ends_with?("_slave")
        begin
          drop_database(conf)
        rescue Exception => e
          puts "Couldn't drop #{conf['database']} : #{e.inspect}"
        end
      end
    end
  end

  task :reset => :load_config do
    Rake::Task["db:drop"].invoke rescue nil
    Rake::Task["db:setup"].invoke
  end

  desc "Create the database defined in config/database.yml for the current RAILS_ENV including shards and slaves"
  task :create => :load_config do
    env_name = defined?(Rails.env) ? Rails.env : RAILS_ENV || 'development'
    ActiveRecord::Base.configurations.each do |key, conf|
      if key.starts_with?(env_name) && !key.ends_with?("_slave")
        create_database(conf)
      end
    end
  end

  desc "Raises an error if there are pending migrations"
  task :abort_if_pending_migrations => :environment do
    if defined? ActiveRecord
      pending_migrations = ActiveRecord::Base.on_shard(nil) { ActiveRecord::Migrator.new(:up, 'db/migrate').pending_migrations }

      if pending_migrations.any?
        puts "You have #{pending_migrations.size} pending migrations:"
        pending_migrations.each do |pending_migration|
          puts '  %4d %s' % [pending_migration.version, pending_migration.name]
        end
        abort %{Run "rake db:migrate" to update your database then try again.}
      end
    end
  end
end
