# encoding: utf-8

class S3DependencyUploader
  def initialize(dependency, bucket_name, artifacts_dir)
    @dependency = dependency
    @bucket_name = bucket_name
    @artifacts_dir = artifacts_dir
  end

  def run
    if file_to_upload
      if file_on_s3?
        puts "File #{file_name} has already been detected on S3. Skipping upload."
      else
        upload_file
      end
    else
      puts 'No files detected for upload.'
    end
  end

  private

  def file_to_upload
    Dir.glob("#{@artifacts_dir}/#{@dependency}*.{tar.gz,tgz,phar}").first
  end

  def file_name
    File.basename(file_to_upload)
  end

  def aws_s3_dir
    "s3://#{@bucket_name}/dependencies/#{@dependency}"
  end

  def file_on_s3?
    `aws s3 ls #{aws_s3_dir}/`.include? file_name
  end

  def upload_file
    system("aws s3 cp #{file_to_upload} #{aws_s3_dir}/#{file_name}")
  end

end

