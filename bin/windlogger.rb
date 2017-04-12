require 'rubygems'
require 'pathname'

require_relative '../lib/base'
require_relative '../lib/db'
require_relative '../lib/mailer'
require_relative '../lib/zipper'
require_relative '../lib/finder'

# TODO:
# database backup
# fix log rotation
# test cases:
# - broken db
# - broken files

db = DB.new

finder = Finder.new(db)
new_files = finder.find

fcount = new_files.values.map(&:size).inject(:+)
if fcount > 0
  LOG.info("Found #{fcount} new files")

  Zipper.zip_files(ZIP_NAME, new_files)

  body = "New files in archive: #{fcount}"
  begin
    Mailer.new(body, ZIP_NAME).mail
  ensure
    File.delete(ZIP_NAME)
  end

  new_files.each { |dir, fhash| db.add(dir, fhash) }
else
  msg = 'New files not found'
  LOG.warn(msg)

  Mailer.new(msg).mail
end
