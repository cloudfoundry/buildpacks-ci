require "spec2"
require "./httpclient_mock"
require "../../src/depwatcher/dotnet"

Spec2.describe Depwatcher::DotnetBase do
  let(dirname) { File.join(Dir.tempdir, "github_releases_spec-" + Random.new.urlsafe_base64) }
  let(client) { HTTPClientMock.new }

  before do
    Dir.mkdir dirname
    client.stub_get(
      "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/2.1/releases.json",
      nil,
      HTTP::Client::Response.new(200, File.read(__DIR__ + "/../fixtures/dotnet-2.1_releases.json"))
    )
  end

  after do
    FileUtils.rm_rf dirname
  end

  context "DotnetSdk" do
    subject { Depwatcher::DotnetSdk.new.tap { |s| s.client = client } }

    describe "#check" do
      it "returns dotnet sdk release versions sorted" do
        checked_deps = subject.check("2.1.7X")
        expect(checked_deps.map(&.ref)).to eq ["2.1.701", "2.1.700"]
      end
    end

    describe "#in" do
      before do
        client.stub_get(
          "https://download.visualstudio.microsoft.com/download/pr/4609998f-2a88-403e-9273-c0d0529cab86/83bd75418eac15dd751c124ad624f1d7/dotnet-sdk-2.1.701-linux-x64.tar.gz",
          HTTP::Headers{"Accept" => "application/octet-stream"},
          HTTP::Client::Response.new(200, body: "dummy sdk data")
        )
      end

      it "returns a release object for the version" do
        obj = subject.in("2.1.701", dirname).not_nil!
        expect(obj.ref).to eq "2.1.701"
        expect(obj.url).to eq "https://download.visualstudio.microsoft.com/download/pr/4609998f-2a88-403e-9273-c0d0529cab86/83bd75418eac15dd751c124ad624f1d7/dotnet-sdk-2.1.701-linux-x64.tar.gz"
        expect(obj.sha512).to eq "238b5049593ae6aa9a5f34473ad890b84487ae1cd2129a9878e074b0217f1ebe7b849d7e3376a437941437b918ab3990cea5fe3fb0305e9e76bc5da0e33aafac"
      end

      it "downloads the file" do
        obj = subject.in("2.1.701", dirname).not_nil!
        hash = OpenSSL::Digest.new("SHA512")
        hash.update(File.read(File.join(dirname, "dotnet-sdk-2.1.701-linux-x64.tar.gz")))
        expect(hash.hexdigest).to eq obj.sha512
      end

      context "bad hash" do
        before do
          client.stub_get(
            "https://download.visualstudio.microsoft.com/download/pr/4609998f-2a88-403e-9273-c0d0529cab86/83bd75418eac15dd751c124ad624f1d7/dotnet-sdk-2.1.701-linux-x64.tar.gz",
            HTTP::Headers{"Accept" => "application/octet-stream"},
            HTTP::Client::Response.new(200, body: "corrupt sdk data")
          )
        end

        it "raises an error" do
          expect { subject.in("2.1.701", dirname) }.to raise_error(Exception, "Expected hash: 238b5049593ae6aa9a5f34473ad890b84487ae1cd2129a9878e074b0217f1ebe7b849d7e3376a437941437b918ab3990cea5fe3fb0305e9e76bc5da0e33aafac : Got hash: 3b81200d7e61008fbe5ebc62cb88ce65f88efb1fca2b39329d6daec2e7dd213dc516a099f24486dfec32112844ec57d0b2e7a98a146468654233c98b8245956a")
        end
      end
    end
  end

  context "DotnetRuntime" do
    subject { Depwatcher::DotnetRuntime.new.tap { |s| s.client = client } }

    describe "#check" do
      it "returns dotnet runtime release versions sorted" do
        checked_deps = subject.check("2.1.X")
        expect(checked_deps.map(&.ref)).to eq ["2.1.13", "2.1.12", "2.1.11", "2.1.10", "2.1.9", "2.1.8", "2.1.7", "2.1.6", "2.1.5", "2.1.4", "2.1.3", "2.1.2", "2.1.1", "2.1.0"]
      end
    end

    describe "#in" do
      before do
        client.stub_get(
          "https://download.visualstudio.microsoft.com/download/pr/2c78594a-dd2c-488e-b201-b7fd9b78ab00/5f2169b20fc704e069c336114ec653c5/dotnet-runtime-2.1.12-linux-x64.tar.gz",
          HTTP::Headers{"Accept" => "application/octet-stream"},
          HTTP::Client::Response.new(200, body: "dummy dotnet runtime data")
        )
      end

      it "returns a release object for the version" do
        obj = subject.in("2.1.12", dirname).not_nil!
        expect(obj.ref).to eq "2.1.12"
        expect(obj.url).to eq "https://download.visualstudio.microsoft.com/download/pr/2c78594a-dd2c-488e-b201-b7fd9b78ab00/5f2169b20fc704e069c336114ec653c5/dotnet-runtime-2.1.12-linux-x64.tar.gz"
        expect(obj.sha512).to eq "cbf2e9d45ae7f275e3b75091f36a95411129d703df856c17f9758673e04a6282eae8dfacea5cc55ab718eb63a8f467c9e3c4ca6c6277a1a3bbddf00b63cebb6c"
      end

      it "downloads the file" do
        obj = subject.in("2.1.12", dirname).not_nil!
        hash = OpenSSL::Digest.new("SHA512")
        hash.update(File.read(File.join(dirname, "dotnet-runtime-2.1.12-linux-x64.tar.gz")))
        expect(hash.hexdigest).to eq obj.sha512
      end

      context "bad hash" do
        before do
          client.stub_get(
            "https://download.visualstudio.microsoft.com/download/pr/2c78594a-dd2c-488e-b201-b7fd9b78ab00/5f2169b20fc704e069c336114ec653c5/dotnet-runtime-2.1.12-linux-x64.tar.gz",
            HTTP::Headers{"Accept" => "application/octet-stream"},
            HTTP::Client::Response.new(200, body: "corrupt dotnet runtime data")
          )
        end

        it "raises an error" do
          expect { subject.in("2.1.12", dirname) }.to raise_error(Exception, "Expected hash: cbf2e9d45ae7f275e3b75091f36a95411129d703df856c17f9758673e04a6282eae8dfacea5cc55ab718eb63a8f467c9e3c4ca6c6277a1a3bbddf00b63cebb6c : Got hash: 273b7fb6dfa81fbdc46e7509fd69f6c47717f05d91e76da6d7ed857b925a3edafd3df01c21a78aae55336d834d188f1a3103e25d6a75f18d6090c5797409f60e")
        end
      end
    end
  end

  context "AspnetcoreRuntime" do
    subject { Depwatcher::AspnetcoreRuntime.new.tap { |s| s.client = client } }

    describe "#check" do
      it "returns dotnet sdk release versions sorted" do
        checked_deps = subject.check("2.1.X")
        expect(checked_deps.map(&.ref)).to eq ["2.1.13", "2.1.12", "2.1.11", "2.1.10", "2.1.9", "2.1.8", "2.1.7", "2.1.6", "2.1.5", "2.1.4", "2.1.3", "2.1.2", "2.1.1", "2.1.0"]
      end
    end

    describe "#in" do
      before do
        client.stub_get(
          "https://download.visualstudio.microsoft.com/download/pr/c1b620fe-7d8e-4685-b6ae-82b444dbc7a7/3d5610f0607da49ee014c61c6cd4e9af/aspnetcore-runtime-2.1.12-linux-x64.tar.gz",
          HTTP::Headers{"Accept" => "application/octet-stream"},
          HTTP::Client::Response.new(200, body: "dummy aspnetcore runtime data")
        )
      end

      it "returns a release object for the version" do
        obj = subject.in("2.1.12", dirname).not_nil!
        expect(obj.ref).to eq "2.1.12"
        expect(obj.url).to eq "https://download.visualstudio.microsoft.com/download/pr/c1b620fe-7d8e-4685-b6ae-82b444dbc7a7/3d5610f0607da49ee014c61c6cd4e9af/aspnetcore-runtime-2.1.12-linux-x64.tar.gz"
        expect(obj.sha512).to eq "138bbc69b94303fa2f151b32ef60873917090949a8e70bcf538765bb813fa015aadf7ef8c59f708166bb812e0e05fc64c73a70885a7cae7a0c1182e50c896f9b"
      end

      it "downloads the file" do
        obj = subject.in("2.1.12", dirname).not_nil!
        hash = OpenSSL::Digest.new("SHA512")
        hash.update(File.read(File.join(dirname, "aspnetcore-runtime-2.1.12-linux-x64.tar.gz")))
        expect(hash.hexdigest).to eq obj.sha512
      end

      context "bad hash" do
        before do
          client.stub_get(
            "https://download.visualstudio.microsoft.com/download/pr/c1b620fe-7d8e-4685-b6ae-82b444dbc7a7/3d5610f0607da49ee014c61c6cd4e9af/aspnetcore-runtime-2.1.12-linux-x64.tar.gz",
            HTTP::Headers{"Accept" => "application/octet-stream"},
            HTTP::Client::Response.new(200, body: "corrupt aspnetcore runtime data")
          )
        end

        it "raises an error" do
          expect { subject.in("2.1.12", dirname) }.to raise_error(Exception, "Expected hash: 138bbc69b94303fa2f151b32ef60873917090949a8e70bcf538765bb813fa015aadf7ef8c59f708166bb812e0e05fc64c73a70885a7cae7a0c1182e50c896f9b : Got hash: 1a10e26187fee5a2c30a8a6d93c392f1ca8e0b6e954dcea2deefe51e6f16f75480f830aeb645590b9f83442e2f2843a7c5febf43357d484a55c777f6e232e532")
        end
      end
    end
  end
end
