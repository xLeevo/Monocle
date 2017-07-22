# config valid only for current version of Capistrano
lock "3.8.1"

set :application, "Monocle"
set :repo_url, "git@github.com:cam-inc/Monocle.git"

# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp
set :branch, :develop #`git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/#{fetch(:application)}-#{ENV["SERVER_PORT"]}"

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
# set :keep_releases, 5

set :default_env, { 
  "POGOMAP_DB_PASS"=> ENV["POGOMAP_DB_PASS"],
  "POGOMAP_CAPTCHA_KEY"=> ENV["POGOMAP_CAPTCHA_KEY"],
  "POGOMAP_GMAPS_KEY"=> ENV["POGOMAP_GMAPS_KEY"],
}

set :rbenv_type, :system # :user or :system, depends on your rbenv setup
set :rbenv_ruby, File.read('.ruby-version').strip
set :rbenv_prefix, "RBENV_ROOT=#{fetch(:rbenv_path)} RBENV_VERSION=#{fetch(:rbenv_ruby)} #{fetch(:rbenv_path)}/bin/rbenv exec"
set :rbenv_map_bins, %w{rake gem bundle ruby whenever}
set :rbenv_roles, :all # default value

set :whenever_roles, %{app}
set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }

namespace :deploy do
  desc "Install pip requirements"
  task :pip_requirements do
    on roles(:app), in: :parallel do |host|
      within fetch(:release_path) do
        execute "/opt/python3-venv/bin/pip3", :install, "-r", "requirements.txt", "--upgrade"
        execute "/opt/python3-venv/bin/pip3", :install, "-r", "optional-requirements.txt", "--upgrade"
        info "Host #{host.hostname}: pip3 requirements/optional-requirements updated."
      end
    end
  end

  desc "Export monocle/config.py"
  task :export_config do
    on roles(:app), in: :parallel do |host|
      within fetch(:release_path) do
        upload! StringIO.new(host.properties.config_file), "#{fetch(:release_path)}/monocle/config.py"
        info "Host #{host.hostname}: written `monocle/config.py`"
      end
    end
  end

  desc "Export supervisor/monocle_worker.ini"
  task :export_supervisor do
    on roles(:app), in: :parallel do |host|
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
    on roles(:app) do |host|
      within fetch(:release_path) do
        execute :supervisorctl, :stop, host.properties.worker_name
        info "Host #{host.hostname}: stopped supervisor"
      end
    end
  end

  desc "Start supervisor"
  task :start_supervisor => [:deploy] do
    on roles(:app) do |host|
      within fetch(:release_path) do
        execute :rm, "-f", "#{fetch(:release_path)}/monocle.sock" 
        execute :supervisorctl, :reread
        execute :supervisorctl, :update
        execute :supervisorctl, :start, host.properties.worker_name
        execute :supervisorctl, :restart, "#{host.properties.worker_name}_web"
        info "Host #{host.hostname}: started supervisor"
        info "Host #{host.hostname}: restarted web supervisor"
      end
    end
  end
end

before "deploy:started", "deploy:stop_supervisor"
before "deploy:published", "deploy:pip_requirements"
after "deploy:pip_requirements", "deploy:export_config"
after "deploy:export_config", "deploy:export_supervisor"
after "deploy:finished", "deploy:start_supervisor"
