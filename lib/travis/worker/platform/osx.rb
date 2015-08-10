class Platform
  class Osx < Platform

    def wrapper_script(job_runner)
      {
        '~/wrapper.sh' => template('wrapper.sh', job_runner)
      }
    end

    # return "bash" command which is executed on MV
    def command(job_runner)
      "GUEST_API_URL=%s bash ~/wrapper.sh" % job_runner.guest_api_url
    end

  end
end
