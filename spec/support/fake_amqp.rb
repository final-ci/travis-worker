class FakerPusher

  attr_reader :io

  def initialize(name, io = STDOUT)
    @name = name
    @io = io
  end

  def publish(data, options)
    io.puts "#{@name} publish: #{data}"
  end

  def close
    io.puts "#{@name}: --close--"
  end

  def reset
    io.puts "#{@name}: --reset--"
  end

  def restart
    io.puts "#{@name}: --restart--"
  end

  def send_log(job_id, msg)
    io.puts "#{@name} send_log #{id}: #{msg}"
  end

  def notify_job_finished(job_id, msg)
    io.puts "#{@name} notify_job_finished #{id}: #{msg}"
  end

  def notify_job_received(job_id)
    io.puts "#{@name} notify_job_finished #{id}"
  end

  def channel
    a = nil
    def a.open?
      true
    end
    a
  end

end
