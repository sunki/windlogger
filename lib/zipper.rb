require 'zip'

class Zipper
  def self.zip_files(fname, files)
    Zip::File.open(fname, Zip::File::CREATE) do |zip|
      files.each do |dir, fhash|
        fhash.keys.each do |file|
          zip.add(file, File.join(dir, file))
        end
      end
    end
  end
end
