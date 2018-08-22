require_relative '../../../tasks/build-binary-new/build_input'

describe 'BuildInput' do
  let(:build_file) do
    build_json = '{ "tracker_story_id": 159007394 }'
    build_file = File.join(FileUtils.mkdir_p(File.join(Dir.mktmpdir, 'builds', 'binary-builds-new', 'python')), '2.7.14.json')
    File.write(build_file, build_json)
    build_file
  end

  it 'loads from a json file' do
    build_input = BuildInput.from_file(build_file)
    expect(build_input.tracker_story_id).to eq 159007394
  end
end