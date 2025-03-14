require "./base"
require "./semver"
require "./github_releases"
require "./github_tags"

module Depwatcher
  class DotnetBase < Base
    class DotnetReleasesIndex
      JSON.mapping(
        releases_index: { type: Array(DotnetReleases), key: "releases-index" },
      )

      class DotnetReleases
        JSON.mapping(
          channel_version: { type: String, key: "channel-version" },
          support_phase: { type: String, key: "support-phase" },
        )
      end
    end

    class DotnetReleasesJSON
      JSON.mapping(
        releases: Array(Release),
      )

      class Release
        JSON.mapping(
          sdk: { type: Sdk, nilable: true },
          runtime: { type: Runtime, nilable: true },
          aspnetcore_runtime: { type: Aspnetcore, nilable: true, key: "aspnetcore-runtime" },
        )
      end

      class Sdk
        JSON.mapping(
          files: Array(File),
          version: String,
        )
      end

      class Runtime
        JSON.mapping(
          files: Array(File),
          version: String,
        )
      end

      class Aspnetcore
        JSON.mapping(
          files: Array(File),
          version: String,
        )
      end

      class File
        JSON.mapping(
          name: String,
          url: String,
          hash: String,
        )
      end
    end

    class DotnetRelease
      JSON.mapping(
        ref: String,
        url: String,
        sha512: String,
      )

      def initialize(
        @ref : String,
        @url : String,
        @sha512 : String
      )
      end
    end

    def get_versions(releases)
      raise "Not implemented, implement in child class"
    end

    def get_newest_files(releases)
      raise "Not implemented, implement in child class"
    end

    def check(version : String) : Array(Internal)
      if version == "latest"
        version = get_latest_version()
      end

      channel_version = version.split('.')[0..1].join('.')
      # mirror for "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/#{channel_version}/releases.json"
      releases_url = "https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/#{channel_version}/releases.json"
      releases = DotnetReleasesJSON.from_json(client.get(releases_url).body).releases
      get_versions(releases, version).select do |v|
        Semver.new(v).is_final_release?
      end.uniq.map { |v| Internal.new(v) }.reverse
    end

    def in(ref : String, output_dir : String) : DotnetRelease | Nil
      channel_version = ref.split('.')[0..1].join('.')
      # mirror for "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/#{channel_version}/releases.json"
      releases_url = "https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/#{channel_version}/releases.json"
      releases = DotnetReleasesJSON.from_json(client.get(releases_url).body).releases
      file = get_newest_file(releases, ref)
      if file
        file.hash = file.hash.downcase
        download_file(file.url, output_dir, file.hash)
        version = get_runtime_version(releases, ref)
        File.write("#{output_dir}/runtime_version", version)
        DotnetRelease.new(ref, file.url, file.hash)
      end
    end

    private def get_latest_version() : String
      # mirror for
      # "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/releases-index.json"
      # as we seem to have issues downloading from here in TPE concourse
      releases_url = "https://raw.githubusercontent.com/dotnet/core/refs/heads/main/release-notes/releases-index.json"
      releases = DotnetReleasesIndex.from_json(client.get(releases_url).body).releases_index
      releases.reject { |r| r.support_phase == "preview" }.[0].channel_version
    end

    private def download_file(download_url : String, dest_dir : String, expected_hash : String) : Nil
      hash = OpenSSL::Digest.new("SHA512")
      resp = client.get(download_url, HTTP::Headers{"Accept" => "application/octet-stream"})
      hash.update(IO::Memory.new(resp.body))

      File.write(File.join(dest_dir, File.basename(download_url)), resp.body)
      got_hash = hash.hexdigest
      raise "Expected hash: #{expected_hash} : Got hash: #{got_hash}" unless got_hash == expected_hash
    end
  end

  class DotnetSdk < DotnetBase
    def get_versions(releases, version_filter)
      version_filter = version_filter.chomp("X")
      releases.reject { |r| r.sdk.nil? }.map { |r| r.sdk.not_nil!.version }.select { |version| version.starts_with? version_filter }
    end

    def get_newest_file(releases, version)
      releases.find { |r| !r.sdk.nil? && r.sdk.not_nil!.version == version }.not_nil!.sdk.not_nil!.files.find { |f| f.name == "dotnet-sdk-linux-x64.tar.gz" }
    end

    def get_runtime_version(releases, version)
      releases.find { |r| !r.sdk.nil? && r.sdk.not_nil!.version == version }.not_nil!.runtime.not_nil!.version
    end
  end

  class DotnetRuntime < DotnetBase
    def get_versions(releases, version)
      releases.reject { |r| r.runtime.nil? }.map { |r| r.runtime.not_nil!.version }
    end

    def get_newest_file(releases, version)
      releases.find { |r| !r.runtime.nil? && r.runtime.not_nil!.version == version }.not_nil!.runtime.not_nil!.files.find { |f| f.name == "dotnet-runtime-linux-x64.tar.gz" }
    end

    def get_runtime_version(releases, version)
      version
    end
  end

  class AspnetcoreRuntime < DotnetBase
    def get_versions(releases, version)
      releases.reject { |r| r.aspnetcore_runtime.nil? }.map { |r| r.aspnetcore_runtime.not_nil!.version }
    end

    def get_newest_file(releases, version)
      releases.find { |r| !r.aspnetcore_runtime.nil? && r.aspnetcore_runtime.not_nil!.version == version }.not_nil!.aspnetcore_runtime.not_nil!.files.find { |f| f.name == "aspnetcore-runtime-linux-x64.tar.gz" }
    end

    def get_runtime_version(releases, version)
      version
    end
  end
end
