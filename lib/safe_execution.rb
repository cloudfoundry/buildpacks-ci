# encoding: utf-8
require 'open3'
require 'logger'

module SafeExecution
  def exit_with_message(message, code = 1)
    puts message
    Exiter.exit_now code
  end

  def execute_with_console_logging!(command, logger = Logger.new($stdout))
    Open3.popen2e(command) do |_, stdouterr, wait_thr|
      logger.info("Output from command { #{command} }:") if logger
      while stdouterr.gets
        if logger
          logger.info($LAST_READ_LINE.chomp) unless $LAST_READ_LINE.nil?
        else
          puts $LAST_READ_LINE
        end
        $stdout.flush
      end
      exit_with_message("#{command} failed", wait_thr.value.exitstatus) unless wait_thr.value.success?
    end
  end

  def stdout_capture_with_console_logging!(command, logger = Logger.new($stdout))
    Open3.popen3(command) do |_, stdout, stderr, wait_thr|
      logger.info("Output from command { #{command} }:") if logger
      stdout_capture = []

      stdout.each do |tag|
        stdout_capture.push(tag.chomp)
        logger.info(tag.chomp) if logger
        puts tag
      end

      _.close
      stdout.close
      stderr.close

      if wait_thr.value.success?
        stdout_capture
      else
        exit_with_message("#{command} failed", wait_thr.value.exitstatus)
      end
    end
  end

  class Exiter
    def self.exit_now(code)
      exit code
    end
  end
end
