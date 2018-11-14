#!/usr/bin/env ruby

env = ENV.fetch('ENVIRONMENT')
locks = ENV.fetch('NUMBER_OF_LOCKS').to_i - 1
output_dir = 'environment-locks'

for i in 0..locks do
  Dir.mkdir(File.join(output_dir, env + i.to_s))
  File.write(File.join(output_dir, env + i.to_s, 'name'), env + i.to_s)
  File.write(File.join(output_dir, env + i.to_s, 'metadata'), '')
end
