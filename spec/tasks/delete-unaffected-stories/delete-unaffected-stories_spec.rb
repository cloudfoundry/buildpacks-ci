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
  before { allow_any_instance_of(DeleteUnaffectedStories).to receive(:puts) }

  it "loops over stories and finds USN info" do
    stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd></body></html>")
    stub_request(:get, "https://usn-data/21").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>apt</a></dd></body></html>")

    stories_file.write(JSON.dump({version: { ref: JSON.dump([{description: "**USN:** https://usn-data/1"}, {description: "**USN:** https://usn-data/21"}]) }}))
    stories_file.close
    subject.run

    assert_requested :get, "https://usn-data/1", times: 1
    assert_requested :get, "https://usn-data/21", times: 1
  end

  it "marks any stories unrelated to rootfs for deletion" do
    stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "**USN:** https://usn-data/1"}, {ref: "456", description: "**USN:** https://usn-data/21"}]) }}))
    stories_file.close
    stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
    stack_receipt.close
    stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd></body></html>")
    stub_request(:get, "https://usn-data/21").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>apt</a></dd></body></html>")

    subject.run

    output = JSON.parse(File.read(output_file.path))
    expect(output["123"]).to eq("delete")
    expect(output["456"]).to eq("affected")
  end

  it "finds all affected packages from the usn for our distribution" do
    stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "**USN:** https://usn-data/1"}]) }}))
    stories_file.close
    stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
    stack_receipt.close
    stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd><dd><a>adduser</a></dd></body></html>")

    subject.run

    output = JSON.parse(File.read(output_file.path))
    expect(output["123"]).to eq("affected")
  end

  it "converts usn http uri to https" do
    stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "**USN:** http://usn-data/1"}]) }}))
    stories_file.close
    stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
    stack_receipt.close
    stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd><dd><a>adduser</a></dd></body></html>")

    subject.run

    output = JSON.parse(File.read(output_file.path))
    expect(output["123"]).to eq("affected")
  end

  context "the usn does not affect our distribution of Ubuntu" do
    it "deletes the story" do
      stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "**USN:** https://usn-data/1"}]) }}))
      stories_file.close
      stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
      stack_receipt.close
      stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 12.04 LTS:</dt><dd><a>adduser</a></dd></body></html>")

      subject.run

      output = JSON.parse(File.read(output_file.path))
      expect(output["123"]).to eq("delete")
    end
  end

  context "a package in our stack is affected for a different distribution" do
    it "deletes the story" do
      stories_file.write(JSON.dump({version: { ref: JSON.dump([{ref:"123", description: "**USN:** https://usn-data/1"}]) }}))
      stories_file.close
      stack_receipt.write("ii  adduser   3.113+nmu3ubuntu3\nii  apt    1.0.1ubuntu2.17\n")
      stack_receipt.close
      stub_request(:get, "https://usn-data/1").to_return(status: 200, body: "<html><body><dt>Ubuntu 14.04 LTS:</dt><dd><a>bison</a></dd><dt>Ubuntu 16.04 LTS:</dt><dd><a>adduser</a></dd></body></html>")

      subject.run

      output = JSON.parse(File.read(output_file.path))
      expect(output["123"]).to eq("delete")
    end
  end

  context "story is malformed" do
    it "loops over stories and finds USN info" do
      stub_request(:get, "https://usn-data/21").to_return(status: 200, body: "")

      stories_file.write(JSON.dump({version: { ref: JSON.dump([{description: "**USN** https://usn-data/1"}, {description: "**USN:** https://usn-data/21"}]) }}))
      stories_file.close

      expect { subject.run }.to raise_error("Some stories failed")

      assert_requested :get, "https://usn-data/1", times: 0
      assert_requested :get, "https://usn-data/21", times: 1
    end
  end
end

