# encoding: utf-8
require 'spec_helper'
require_relative '../../lib/buildpack-dependency'

describe BuildpackDependency do
  describe '.for' do
    let(:ruby_buildpack_yaml) do
      {
        'dependencies' => [
          { 'name' => 'newrelic' },
          { 'name' => 'httpd' }
        ]
      }.to_yaml
    end
    let(:python_buildpack_yaml) do
      {
        'dependencies' => [
          { 'name' => 'snake' },
          { 'name' => 'dog' }
        ]
      }.to_yaml
    end
    let(:php_buildpack_yaml) do
      {
        'dependencies' => [
          { 'name' => 'newrelic' },
          { 'name' => 'snake' }
        ]
      }.to_yaml
    end

    before do
      allow(described_class).to receive(:open).and_return({ 'dependencies' => [] }.to_yaml)
      allow(described_class).to receive(:open).with('https://raw.githubusercontent.com/cloudfoundry/ruby-buildpack/develop/manifest.yml').and_return(ruby_buildpack_yaml)
      allow(described_class).to receive(:open).with('https://raw.githubusercontent.com/cloudfoundry/python-buildpack/develop/manifest.yml').and_return(python_buildpack_yaml)
      allow(described_class).to receive(:open).with('https://raw.githubusercontent.com/cloudfoundry/php-buildpack/develop/manifest.yml').and_return(php_buildpack_yaml)
    end

    it 'returns the buildpacks which include this dependency' do
      expect(described_class.for(:snake)).to eq([:php, :python])
    end
  end
end
