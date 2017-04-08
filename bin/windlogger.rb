require 'rubygems'
require 'pathname'

require_relative '../lib/base'
require_relative '../lib/db'
require_relative '../lib/mailer'
require_relative '../lib/zipper'

# TODO:
# database backup
# fix log rotation
# test cases:
# - broken db
# - broken files

@db = DB.new
@new_files = {}

CFG['dirs'].each do |dir|
  sent_files = @db.get(dir) || {}

  files = Pathname.glob(File.join(dir, '*')).inject({}) do |res, f|
    mtime = File.mtime(f)
    bname = f.basename.to_s

    stime = sent_files[bname]

    next res if stime && stime == mtime
    next res if NOW - mtime < CFG['changed_delay_hours'] * 60 * 60
    ctime = File.ctime(f)
    next res if NOW - ctime < CFG['created_delay_hours'] * 60 * 60

    res[bname] = mtime
    res
  end
  @new_files[dir] = files
end

fcount = @new_files.values.map(&:size).inject(:+)
if fcount > 0
  LOG.info("Found #{fcount} new files")

  Zipper.zip_files(ZIP_NAME, @new_files)

  body = "New files in archive: #{fcount}"
  begin
    Mailer.new(body, ZIP_NAME).mail
  ensure
    File.delete(ZIP_NAME)
  end

  @new_files.each { |dir, fhash| @db.add(dir, fhash) }
else
  msg = 'New files not found'
  LOG.warn(msg)

  Mailer.new(msg).mail
end
