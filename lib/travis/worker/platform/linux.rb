class Platform
  class Linux < Platform
    def platform_name
      'linux'
    end

    def user_data?
      true
    end
  end
end
