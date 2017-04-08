require 'logger'

# Cannot use __dir__ or something due to ocra gem temp folder issues
app_dir = Dir.pwd

NOW = Time.now
ZIP_NAME = "windlogger_#{NOW.strftime('%Y-%m-%d-%H-%M-%S')}.zip"
ZIP_PATH = File.join(app_dir, ZIP_NAME)
LOG_FILE = File.join(app_dir, 'windlogger.log')
CONFIG   = File.join(app_dir, 'config/windlogger.ini')

log_fd = File.new(LOG_FILE, 'a')
LOG = Logger.new(log_fd, 10, 10_000_000)
$stderr.reopen(log_fd)

LOG.info('Started')

cfg_content = File.read(CONFIG)
cfg_content = cfg_content.split("\n").map(&:strip).reject(&:empty?)
CFG = cfg_content.inject({}) do |res, line|
  k, v = line.split('=').map(&:strip)
  res[k] = v
  res
end

def normalize_path(path)
  path.strip.gsub(/\\/, '/')
end

CFG['dirs'] = CFG['dirs'].split(',').map{ |d| normalize_path(d) }
CFG['destination'] = normalize_path(CFG['destination'])

%w(port smtp_timeout smtp_attempts smtp_attempts_delay created_delay_hours changed_delay_hours).each{ |key| CFG[key] = CFG[key].to_i }
