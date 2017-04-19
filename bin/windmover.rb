require 'rubygems'
require 'pathname'
require 'fileutils'

require_relative '../lib/base'
require_relative '../lib/db'
require_relative '../lib/zipper'
require_relative '../lib/finder'

db = DB.new

finder = Finder.new(db)
new_files = finder.find(skip_changed: true)

fcount = new_files.values.map(&:size).inject(0, :+)
if fcount > 0
  LOG.info("Found #{fcount} new files")

  Zipper.zip_files(ZIP_NAME, new_files)
  FileUtils.cp(ZIP_NAME, CFG['destination'])
  File.delete(ZIP_NAME)

  new_files.each { |dir, fhash| db.add(dir, fhash) }
else
  LOG.warn('New files not found')
end
