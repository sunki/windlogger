class Finder
  def initialize(db)
    @db = db
  end

  def find
    new_files = {}
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
      new_files[dir] = files
    end
    new_files
  end
end
