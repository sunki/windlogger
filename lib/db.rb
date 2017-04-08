require 'yaml'

# Cannot use __dir__ or something due to ocra gem temp folder issues
STORAGE  = File.join(Dir.pwd, 'windmover.yml')

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
    File.open(STORAGE, 'w') { |f| f.write(YAML.dump(data)) }
  end
end
