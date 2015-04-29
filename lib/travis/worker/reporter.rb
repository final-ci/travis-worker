require 'travis/support/logging'
require 'travis/worker/utils/serialization'

module Travis
  module Worker
    # Reporter that streams build logs. Because workers now support multiple types of
    # projects (e.g. Ruby, Clojure) as long as VMs provide all the necessary, log streaming
    # picks routing key dynamically for each build.
    class Reporter
      include Logging
      include Utils::Serialization

      log_header { "#{name}:log_streamer" }

      attr_reader :name

      def initialize(name, state_publisher, log_publisher, test_result_publisher)
        @name = name
        @state_publisher = state_publisher
        @log_publisher = log_publisher
        @test_result_publisher = test_result_publisher
        reset
      end

      def reset
        @logs_part_number = 0
      end

      def notify(event, data)
        message(event, data)
      end

      def message(event, data)
        unless publisher_for(event).channel.open?
          warn "trying to publish '#{data}' to closed channel for '#{event}' event"
          return
        end
        data = data.merge(uuid: Travis.uuid)
        options = {
          properties: { type: event },
        }
        publisher_for(event).publish(data, options)
      end
      # log :message, :as => :debug, :only => :before
      # this has been disabled as logging is also logged as debug, making the
      # logs super verbose, this can be turned on as needed

      def publisher_for(event)
        event.to_s =~ /log/ ? @log_publisher : @state_publisher
        return @log_publisher if event.to_s =~ /log/
        return @test_result_publisher if event.to_s =~ /test_result/
        @state_publisher
      end

      def close
        @state_publisher.close
        @log_publisher.close
      end

      # simple helpers
      def send_log(job_id, output, last_message = false)
        @logs_part_number += 1
        message = { id: job_id, log: output, number: @logs_part_number }
        message[:final] = true if last_message
        notify('job:test:log', message)
      end

      def send_last_log(job_id)
        send_log(job_id, "", true)
      end

      def send_tresult(job_id, payload)
        notify('job:test:test_result', payload)
      end

      def send_tresult_update(job_id, id, payload)
        notify('job:test:test_result', payload)
      end

      def notify_job_received(job_id)
        notify('job:test:receive', id: job_id, state: 'received', received_at: Time.now.utc, worker: Travis::Worker.config.hostname)
      end

      def notify_job_started(job_id)
        notify('job:test:start', id: job_id, state: 'started', started_at: Time.now.utc)
      end

      def notify_job_finished(job_id, result)
        notify('job:test:finish', id: job_id, state: normalized_state(result), finished_at: Time.now.utc)
      end

      def restart(job_id)
        notify('job:test:reset', id: job_id, state: 'reset')
      end

      def normalized_state(result)
        return result if result.is_a?(String)
        case result
        when 0; 'passed'
        when 1; 'failed'
        when 2; 'errored'
        else    'errored'
        end
      end
    end
  end
end
