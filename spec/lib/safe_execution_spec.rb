require 'spec_helper'
require_relative '../../lib/safe_execution'

describe SafeExecution do
  include SafeExecution

  before do
    allow(SafeExecution::Exiter).to receive(:exit_now)
  end

  describe '#exit_with_message' do
    it 'prints a message' do
      expect { exit_with_message 'Oh noooo' }.to output("Oh noooo\n").to_stdout
    end

    context 'default exit code' do
      it 'exits with default error code' do
        expect { exit_with_message 'Oh nooooo' }.to output("Oh nooooo\n").to_stdout
        expect(SafeExecution::Exiter).to have_received(:exit_now).with(1)
      end
    end

    context 'user-defined exit code' do
      it 'returns specified error code' do
        expect { exit_with_message 'Oh nooooo', 5 }.to output("Oh nooooo\n").to_stdout
        expect(SafeExecution::Exiter).to have_received(:exit_now).with(5)
      end
    end
  end

  describe '#execute_with_console_logging!' do
    context 'is passed a logger object' do
      let(:logger) { Logger.new(STDOUT) }

      it 'uses the logger to print messages' do
        expect(logger).to receive(:info).with('Output from command { echo quack }:')
        expect(logger).to receive(:info).with('quack')
        execute_with_console_logging!('echo quack', logger)
      end
    end

    context 'is not passed a logger object' do
      it 'prints stdout of executed command' do
        expect { execute_with_console_logging! 'echo quack', nil }.to output("quack\n").to_stdout
      end

      it 'prints stderr of executed command' do
        expect { execute_with_console_logging! 'echo quack 1>&2', nil }.to output("quack\n").to_stdout
      end

      describe 'success exit code' do
        it 'returns nil' do
          expect do
            expect(execute_with_console_logging! 'echo quack', nil).to eq nil
          end.to output("quack\n").to_stdout
        end

        it 'does not exit' do
          expect do
            execute_with_console_logging! 'echo quack', nil
          end.to output("quack\n").to_stdout
          expect(SafeExecution::Exiter).to_not have_received(:exit_now)
        end
      end

      describe 'failure exit code' do
        it 'exits with the status code of the command' do
          expect do
            execute_with_console_logging! 'exit 2', nil
          end.to output("exit 2 failed\n").to_stdout
          expect(SafeExecution::Exiter).to have_received(:exit_now).with(2)
        end
      end
    end
  end

  describe '#stdout_capture_with_console_logging!' do
    context 'is passed a logger object' do
      let(:logger) { Logger.new(STDOUT) }

      it 'uses the logger to print messages' do
        expect(logger).to receive(:info).with('Output from command { echo quack }:')
        expect(logger).to receive(:info).with('quack')
        expect do
          expect(stdout_capture_with_console_logging!('echo quack', logger)).to eq ['quack']
        end.to output("quack\n").to_stdout
      end
    end

    context 'is not passed a logger object' do
      describe 'successful execution' do
        it 'returns the command output' do
          expect do
            expect(stdout_capture_with_console_logging! 'echo quack', nil).to eq ['quack']
          end.to output("quack\n").to_stdout
          expect(SafeExecution::Exiter).to_not have_received(:exit_now)
        end
      end

      describe 'failed execution' do
        it 'exits with the status code of the command' do
          expect do
            stdout_capture_with_console_logging! 'exit 2', nil
          end.to output("exit 2 failed\n").to_stdout
          expect(SafeExecution::Exiter).to have_received(:exit_now).with(2)
        end

        it 'returns nil' do
          expect do
            result = stdout_capture_with_console_logging! 'echo quack; echo quack; exit 2', nil
            expect(result).to eq nil
          end.to output("quack\nquack\necho quack; echo quack; exit 2 failed\n").to_stdout_from_any_process
        end
      end
    end
  end
end
