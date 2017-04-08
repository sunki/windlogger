require 'rubygems'
require 'pathname'
require 'fileutils'

require_relative '../lib/base'
require_relative '../lib/db'
require_relative '../lib/zipper'

@db = DB.new
@new_files = {}

CFG['dirs'].each do |dir|
  sent_files = @db.get(dir) || {}

  file = Pathname.glob(File.join(dir, '*')).sort[-2]
  next unless file

  mtime = File.mtime(file)
  bname = file.basename.to_s

  sfile = sent_files[bname]
  @new_files[dir] = { bname => mtime } unless sfile
end

fcount = @new_files.values.map(&:size).inject(0, :+)
if fcount > 0
  LOG.info("Found #{fcount} new files")

  Zipper.zip_files(ZIP_NAME, @new_files)
  FileUtils.cp(ZIP_NAME, CFG['destination'])
  File.delete(ZIP_NAME)

  @new_files.each { |dir, fhash| @db.add(dir, fhash) }
else
  LOG.warn('New files not found')
end
