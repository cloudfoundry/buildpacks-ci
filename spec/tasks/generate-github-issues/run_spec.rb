require_relative '../../../lib/github-issue-generator'

context 'Generate Github Issues' do
  it 'creates an issue in every specified buildpack' do
    ci_path = Dir.pwd
    test_path = File.join(ci_path, '/spec/tasks/generate-github-issues')

    msg_file_path = File.join(test_path, 'message.txt')
    buildpacks_list_path = File.join(test_path, 'buildpacks.txt')
    title = "Some Title"

    mock = double("octokit")
    expect(mock).to receive(:create_issue).with("cloudfoundry/buildpackA", title, "Some issue message.\nMore info.")
    expect(mock).to receive(:create_issue).with("cloudfoundry/buildpackB", title, "Some issue message.\nMore info.")

    generator = GithubIssueGenerator.new mock
    generator.run(title, msg_file_path, buildpacks_list_path)
  end
end