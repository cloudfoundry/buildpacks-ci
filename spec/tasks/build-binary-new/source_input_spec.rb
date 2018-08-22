require_relative '../../../tasks/build-binary-new/source_input'

describe 'SourceInput' do
  let(:source_file) do
    source_json =
      <<~SOURCE_JSON
        {
            "version": {
              "md5_digest": "cee2e4b33ad3750da77b2e85f2f8b724",
              "url": "https://www.python.org/ftp/python/2.7.14/Python-2.7.14.tgz",
              "ref": "2.7.14"
            },
            "source": {
              "version_filter": "2.7.X",
              "type": "python",
              "name": "python"
            }
         }
    SOURCE_JSON
    source_file = File.join(Dir.mktmpdir, 'data.json')
    File.write(source_file, source_json)
    source_file
  end

  it 'loads from a json file' do
    source = SourceInput.from_file(source_file)
    expect(source.name).to eq 'python'
    expect(source.url).to eq 'https://www.python.org/ftp/python/2.7.14/Python-2.7.14.tgz'
    expect(source.version).to eq '2.7.14'
    expect(source.md5).to eq 'cee2e4b33ad3750da77b2e85f2f8b724'
    expect(source.sha256).to eq nil
  end
end