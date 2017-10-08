# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
set :output, "#{Whenever.path}/logs/cron.log"

env "POGOMAP_DB_PASS", ENV["POGOMAP_DB_PASS"]
env "POGOMAP_CAPTCHA_KEY", ENV["POGOMAP_CAPTCHA_KEY"]
env "POGOMAP_GMAPS_KEY", ENV["POGOMAP_GMAPS_KEY"]
env "DYNAMO_SOURCEDB_MONOCLE", ENV["DYNAMO_SOURCEDB_MONOCLE"]

job_type :cleanup, "cd :path && ./:task :output"
job_type :cleanup_python, "cd :path && /opt/python3.6/bin/python3.6 :path/:task :output"

every 1.minute, roles: [:db] do
  cleanup_python "cleanup.py --light"
end

every "5 * * * *", roles: [:db] do
  cleanup_python "cleanup.py --heavy"
end

every "30 * * * *", roles: [:db] do
  cleanup "cleanup_clusters.sh"
end
