require 'yaml'
require 'pry'

#TODO: lets try to load this without require relative
require_relative '../../../tasks/build-binary-new/merge-extensions'

describe 'PhpExtensions' do
  before(:each) do
    @testdata = File.join(__dir__,'testdata')
    path = File.join(@testdata, 'php-base-extensions-test.yml')
    @base_obj = BaseExtensions.new(File.absolute_path(path))
  end
  it 'correctly adds new extensions' do
    expect(@base_obj.patch!(File.join(@testdata, 'php-patch-extensions-test.yml'))).to eq true
    expect(@base_obj.find_ext_index('solr')).not_to be_nil
  end

  it 'patches existing extensions' do
    expect(@base_obj.find_ext('apcu')['version']).to eq '5.1.17'
    expect(@base_obj.patch!(File.join(@testdata, 'php-patch-extensions-test.yml'))).to eq true
    expect(@base_obj.find_ext('apcu')['version']).to eq '99.99.99'
  end

  it 'deletes excluded extensions' do
    expect(@base_obj.find_ext_index('libsodium','native_modules')).not_to be_nil
    expect(@base_obj.find_ext_index('sodium')).not_to be_nil
    expect(@base_obj.patch!(File.join(@testdata, 'php-patch-extensions-test.yml'))).to eq true
    expect(@base_obj.find_ext_index('libsodium','native_modules')).to be_nil
    expect(@base_obj.find_ext_index('sodium')).to be_nil
  end

  it 'does nothing when merging an empty patch.yml' do
    previous_obj = Marshal.load(Marshal.dump(@base_obj.base_yml))
    expect(@base_obj.patch!(File.join(@testdata, 'php-empty-patch-test.yml'))). to eq false
    expect(@base_obj.base_yml).to eq previous_obj
  end

  it 'does nothing when attempting to delete a missing extension' do
    previous_obj = Marshal.load(Marshal.dump(@base_obj.base_yml))
    expect(@base_obj.patch!(File.join(@testdata, 'php-patch-missing-extension-test.yml'))). to eq true
    expect(@base_obj.base_yml).to eq previous_obj
  end
end
