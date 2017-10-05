# config valid only for current version of Capistrano
lock "3.8.1"

set :application, "Monocle"
set :repo_url, "git@github.com:cam-inc/Monocle.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, :develop #`git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/#{fetch(:application)}-#{ENV["SERVER_PORT"] || "10000"}"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", "config/secrets.yml"

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system"
append :linked_dirs, "logs", "pickles", "tmp"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for keep_releases is 5
set :keep_releases, 2 

set :default_env, { 
  "POGOMAP_DB_PASS"=> ENV["POGOMAP_DB_PASS"],
  "POGOMAP_CAPTCHA_KEY"=> ENV["POGOMAP_CAPTCHA_KEY"],
  "POGOMAP_GMAPS_KEY"=> ENV["POGOMAP_GMAPS_KEY"],
  "DYNAMO_SOURCEDB_MONOCLE" => ENV["DYNAMO_SOURCEDB_MONOCLE"],
}

set :rbenv_type, :system # :user or :system, depends on your rbenv setup
set :rbenv_ruby, File.read('.ruby-version').strip
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby whenever}
set :rbenv_roles, :all # default value

set :whenever_roles, %{db}
set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }

namespace :pip do
  desc "Install pip requirements"
  task :requirements do
    on roles(:maintenance), in: :parallel do |host|
      within fetch(:release_path) do
        execute "/opt/python3.6/bin/pip3.6", :install, "-r", "requirements.txt", "--upgrade"
        execute "/opt/python3.6/bin/pip3.6", :install, "-r", "optional-requirements.txt", "--upgrade"
        info "Host #{host.hostname}: pip3.6 requirements/optional-requirements updated."
      end
    end

    on roles(:db), in: :parallel do |host|
      within fetch(:release_path) do
        file = File.read(".env.production")
        upload! StringIO.new(file), "#{fetch(:release_path)}/.env"

        execute :npm, :install, "--silent"
        info "#{host.hostname}: npm install --silent"

        execute :slc, :ctl, :shutdown, :monocle, "&&", :slc, :start, "."
        info "#{host.hostname}: slc ctl shutdown monocle && slc start ."
      end
    end
  end
end

namespace :deploy do
  desc "Export monocle/config.py"
  task :export_config do
    on roles(:worker), in: :parallel do |host|
      within fetch(:release_path) do
        upload! StringIO.new(host.properties.config_file), "#{fetch(:release_path)}/monocle/config.py"
        info "Host #{host.hostname}: written `monocle/config.py`"
      end
    end
  end

  desc "Export monocle/config.py to cron"
  task :export_config_cron do
    on roles(:db), in: :parallel do |host|
      within fetch(:release_path) do
        file = File.read(".cron.config.py")
        upload! StringIO.new(file), "#{fetch(:release_path)}/monocle/config.py"
        info "Host #{host.hostname}: written `monocle/config.py`"
      end
    end
  end

  desc "Export supervisor/monocle_worker.ini"
  task :export_supervisor do
    on roles(:worker), in: :parallel do |host|
      within fetch(:release_path) do
        execute "rm", "-f", "/etc/supervisor/workers/#{host.properties.worker_name}.ini"
        execute "mkdir", "-p", "#{fetch(:release_path)}/supervisor"

        file = File.read("templates/monocle_worker.ini")
          .gsub(/%{WORKER_NAME}/, host.properties.worker_name)
          .gsub(/%{SN}/, host.properties.sn)
          .gsub(/%{BOOTSTRAP}/, host.properties.bootstrap)
          .gsub(/%{NO_PICKLE}/, host.properties.no_pickle)
          .gsub(/%{SERVER_PORT}/, host.properties.server_port)

        upload! StringIO.new(file), "#{fetch(:release_path)}/supervisor/#{host.properties.worker_name}.ini"

        execute "ln", "-s", "#{fetch(:release_path)}/supervisor/#{host.properties.worker_name}.ini", "/etc/supervisor/workers/#{host.properties.worker_name}.ini"

        info "Host #{host.hostname}: written `supervisor/#{host.properties.worker_name}.ini`"
      end
    end
  end

  desc "Stop supervisor"
  task :stop_supervisor => [:deploy] do
    on roles(:worker) do |host|
      within fetch(:release_path) do
        execute :supervisorctl, :stop, host.properties.worker_name
        info "Host #{host.hostname}: stopped supervisor"
      end
    end
  end

  desc "Restart supervisor"
  task :restart_supervisor => [:deploy] do
    on roles(:worker) do |host|
      within fetch(:release_path) do
        execute :rm, "-f", "#{fetch(:release_path)}/monocle.sock" 
        execute :supervisorctl, :reread, "&&",
          :supervisorctl, :update, "&&",
          :supervisorctl, :start, host.properties.worker_name, "&&",
          :supervisorctl, :restart, "#{host.properties.worker_name}_web"
        info "Host #{host.hostname}: started supervisor"
        info "Host #{host.hostname}: restarted web supervisor"
      end
    end
  end
end

before "deploy:started", "deploy:stop_supervisor"
before "deploy:published", "pip:requirements"
before "deploy:published", "deploy:export_config"
before "deploy:published", "deploy:export_config_cron"
after "deploy:export_config", "deploy:export_supervisor"
after "deploy:finished", "deploy:restart_supervisor"
