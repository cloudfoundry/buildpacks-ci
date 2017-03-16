# require 'fileutils'
# require 'tmpdir'
# require 'yaml'
require 'json'
require 'webmock/rspec'

require_relative '../../../tasks/delete-unaffected-stories/delete-unaffected-stories'

describe DeleteUnaffectedStories do
  let(:stories_file) { Tempfile.new }
  let(:stack_receipt) { Tempfile.new }
  let(:output_file) { Tempfile.new }
  subject { DeleteUnaffectedStories.new(stories_file.path, stack_receipt.path, output_file.path) }

  it "marks any stories unrelated to rootfs for deletion" do
    stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "blah\n**Trusty Packages:**\nbison 1.2\n\n"}, {ref: "456", description: "blah\n**Trusty Packages:**\napt 2.1\n\n"}]) }}))
    stories_file.close
    stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
    stack_receipt.close

    subject.run

    output = JSON.parse(File.read(output_file.path))
    expect(output["123"]).to eq("delete")
    expect(output["456"]).to eq("affected")
  end

  it "finds all affected packages from the usn for our distribution" do
    stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "blah\n**Trusty Packages:**\nadduser   3.113+nmu3ubuntu3\napt    1.0.1ubuntu2.17\n\n"}]) }}))
    stories_file.close
    stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
    stack_receipt.close
    stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd><dd><a>adduser</a></dd></body></html>")

    subject.run

    output = JSON.parse(File.read(output_file.path))
    expect(output["123"]).to eq("affected")
  end

  context "a package in our stack is affected for a different distribution" do
    it "deletes the story" do
      stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "blah\n**Trusty Packages:**\nbison   3.113+nmu3ubuntu3\n\n**Xenial Packages:**\napt    1.0.1ubuntu2.17\n\n"}]) }}))
      stories_file.close
      stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
      stack_receipt.close

      subject.run

      output = JSON.parse(File.read(output_file.path))
      expect(output["123"]).to eq("delete")
    end
  end
end

