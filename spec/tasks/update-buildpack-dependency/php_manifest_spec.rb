require 'spec_helper'
require_relative '../../../tasks/update-buildpack-dependency/php_manifest'

describe PHPManifest do
  describe "#update_defaults" do

    let(:manifest) do
      {
          'default_versions' => [
              {'name' => 'php', 'version' => '123'},
              {'name' => 'xdebug', 'version' => '127.2'},
              {'name' => 'libsump', 'version' => '3333'}
          ]
      }
    end
    it 'sets the php default version to the resource version passed in' do
      updated_dependencies = PHPManifest.update_defaults(manifest, '2.3.6')
      expect(updated_dependencies).to eq([
                                                 {'name' => 'php', 'version' => '2.3.6'},
                                                 {'name' => 'xdebug', 'version' => '127.2'},
                                                 {'name' => 'libsump', 'version' => '3333'}
                                             ])

    end
  end
end