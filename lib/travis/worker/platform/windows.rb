class Platform
  class Windows < Platform

    def wrapper_script(job_runner)
      {
        '~/build_wrapper.sh'  => template('build_wrapper.sh', job_runner),
        '~/run_pswrapper.ps1' => template('run_pswrapper.ps1', job_runner)
      }
    end

    # return "bash" command which is executed on MV
    def command(job_runner)
      "GUEST_API_URL=%s bash --login ~/build_wrapper.sh" % job_runner.guest_api_url
    end

  end
end
