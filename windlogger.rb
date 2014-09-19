require 'rubygems'
require 'yaml'
require 'pathname'
require 'net/smtp'
require 'zip'
require 'logger'

# TODO:
# database backup
# fix log rotation
# test cases:
# - broken db
# - broken files

@now = Time.now
app_dir = Dir.pwd
ZIP_NAME = "windlogger_#{@now.strftime('%Y-%m-%d-%H-%M-%S')}.zip"
ZIP_PATH = File.join(app_dir, ZIP_NAME)
STORAGE  = File.join(app_dir, 'windlogger.yml')
CONFIG   = File.join(app_dir, 'windlogger.ini')
LOG_FILE = File.join(app_dir, 'windlogger.log')

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
CFG['dirs'] = CFG['dirs'].split(',').map{ |d| d.strip.gsub(/\\/, '/') }

%w(port smtp_timeout smtp_attempts smtp_attempts_delay created_delay_hours changed_delay_hours).each{ |key| CFG[key] = CFG[key].to_i }

class DB

  def get(dir)
    data[dir]
  end

  def set(dir, files)
    data[dir] = files
    save
  end

  def add(dir, files)
    old_files = data[dir] || {}
    set(dir, old_files.merge(files))
  end

  def data
    @data ||= YAML.load(open)
  end

  def open
    self.class.save({}) unless File.exists?(STORAGE)
    File.read(STORAGE)
  end

  def save
    self.class.save(data)
  end

  def self.save(data)
    File.open(STORAGE, 'w'){ |f| f.write(YAML.dump(data)) }
  end
end

class Mailer

  MARKER = '%%MSG_PART%%'

  class SmtpMaxAttemptsReached < StandardError; end

  def initialize(body, attach_path=nil)
    @attempts = 0
    @body = body
    @attach_path = attach_path
  end

  def mail
    @msg = <<-MSG
From: #{CFG['email']}
To: #{CFG['email']}
Subject: windlogger daily data
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary=#{MARKER}\n
--#{MARKER}
Content-Type: text/plain; charset=ISO-8859-1\n
#{@body}
MSG

    if @attach_path
      attach = File.binread(@attach_path)
      attach = [attach].pack('m')
      @msg << <<-MSG
--#{MARKER}
Content-Type: application/zip; name="#{ZIP_NAME}"
Content-Transfer-Encoding:base64
Content-Disposition: attachment; filename="#{ZIP_NAME}"\n
#{attach}
MSG
    end

    @msg << "\n--#{MARKER}--"
    process
  end

  def process
    begin
      Timeout.timeout(CFG['smtp_timeout']) do
        net = Net::SMTP.new(CFG['server'], CFG['port'])
        net.enable_ssl
        net.start('localhost.localdomain', CFG['email'], CFG['pass']) do |smtp|
          LOG.info "sending mail (attempt: #{@attempts})"
          #puts @msg
          smtp.send_message(@msg, CFG['email'], CFG['email'])
        end
      end
    rescue => err
      LOG.error "#{err.message}\n#{err.backtrace.join("\n")}"
      @attempts += 1
      raise SmtpMaxAttemptsReached if @attempts >= CFG['smtp_attempts']
      sleep(CFG['smtp_attempts_delay'])
      process
    end
  end
end

def zip_files(fname, files)
  Zip::File.open(fname, Zip::File::CREATE) do |zip|
    files.each do |dir, fhash|
      fhash.keys.each do |file|
        zip.add(file, File.join(dir, file))
      end
    end
  end
end

@db = DB.new
@new_files = {}

CFG['dirs'].each do |dir|
  sent_files = @db.get(dir) || {}

  files = Pathname.glob(File.join(dir, '*')).inject({}) do |res, f|
    mtime = File.mtime(f)
    bname = f.basename.to_s

    stime = sent_files[bname]

    next res if stime && stime == mtime
    next res if @now - mtime < CFG['changed_delay_hours'] * 60 * 60
    ctime = File.ctime(f)
    next res if @now - ctime < CFG['created_delay_hours'] * 60 * 60

    res[bname] = mtime
    res
  end
  @new_files[dir] = files
end

fcount = @new_files.values.map(&:size).inject(:+)
if fcount > 0
  LOG.info("Found #{fcount} new files")
  zip_files(ZIP_NAME, @new_files)
  body = "New files in archive: #{fcount}"
  begin
    Mailer.new(body, ZIP_NAME).mail
  ensure
    File.delete(ZIP_NAME)
  end
  @new_files.each{ |dir, fhash| @db.add(dir, fhash) }
else
  msg = 'New files not found'
  LOG.warn(msg)
  Mailer.new(msg).mail
end
