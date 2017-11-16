# encoding: utf-8

class S3DependencyUploader
  def initialize(dependency, bucket_name, artifacts_dir)
    @dependency = dependency
    @bucket_name = bucket_name
    @artifacts_dir = artifacts_dir
  end

  def run
    if files_to_upload.empty?
      puts 'No files detected for upload.'
    else
      files_to_upload.each do |path|
        if file_on_s3?(path)
          puts "File #{File.basename(path)} has already been detected on S3. Skipping upload."
        else
          upload_file(path)
        end
      end
    end
  end

  private

  def files_to_upload
    @files_to_upload ||= Dir.glob("#{@artifacts_dir}/#{@dependency}*.{tar.gz,tar.xz,tgz,phar,zip}")
  end

  def aws_s3_dir
    "s3://#{@bucket_name}/dependencies/#{@dependency}"
  end

  def file_on_s3?(path)
    file_name = File.basename(path)
    `aws s3 ls #{aws_s3_dir}/`.include? file_name
  end

  def upload_file(path)
    file_name = File.basename(path)
    system("aws s3 cp #{path} #{aws_s3_dir}/#{file_name}")
  end
end
