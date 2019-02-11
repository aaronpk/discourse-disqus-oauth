# name: discourse-disqus
# about: Log in to Discourse with your Disqus account
# version: 1.0
# author: Aaron Parecki <https://aaronparecki.com>
# url: https://github.com/aaronpk/discourse-disqus-oauth

require 'auth/oauth2_authenticator'

enabled_site_setting :disqus_login_enabled

PLUGIN_NAME = 'discourse-disqus'.freeze

register_asset 'stylesheets/disqus.scss'

after_initialize do

  module ::Disqus
    PLUGIN_NAME = 'discourse-disqus'.freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace Disqus
    end

    def self.store
      @store ||= PluginStore.new(PLUGIN_NAME)
    end

    def self.get(key)
      store.get(key)
    end

    def self.set(key, value)
      store.set(key, value)
    end

  end

  class ::OmniAuth::Strategies::Disqus
    option :name, 'disqus'
    option :scope, 'read,email'

    option :client_options, {
      :site          => 'https://disqus.com',
      :authorize_url => '/api/oauth/2.0/authorize/',
      :token_url     => '/api/oauth/2.0/access_token/'
      }

    option :authorize_params, response_type: 'code'

    uid {
      access_token.params['user_id']
    }

    info do
      {
        :name        => raw_info['username'],
        :nickname    => raw_info['username'],
        :email       => raw_info['email'],
        :location    => raw_info['location'],
        :description => raw_info['about'],
        :image       => raw_info['avatar']['small']['permalink'],
        :urls        => {
          'profileUrl' => raw_info['profileUrl']
        }
      }
    end

    extra do
      {
        :raw_info => raw_info
      }
    end

    def callback_url
      full_host + script_name + callback_path
    end

    def raw_info
      url    = '/api/3.0/users/details.json'
      params = {
        'api_key'      => access_token.client.id,
        'access_token' => access_token.token
      }

      @raw_info ||= access_token.get(url, :params => params).parsed['response']
    end
  end

end

class OmniAuth::Strategies::Disqus < OmniAuth::Strategies::OAuth2
end

class Auth::DisqusAuthenticator < Auth::OAuth2Authenticator
  def register_middleware(omniauth)
    omniauth.provider :disqus,
                      setup: lambda { |env|
                        strategy = env['omniauth.strategy']
                        strategy.options[:client_id] = SiteSetting.disqus_client_id
                        strategy.options[:client_secret] = SiteSetting.disqus_client_secret
                        strategy.options[:redirect_uri] = "#{Discourse.base_url}/auth/disqus/callback"
                      }
  end

  def enabled?
    SiteSetting.disqus_login_enabled
  end
end

auth_provider pretty_name: 'Disqus',
              title: 'with Disqus',
              message: 'Authentication with Disqus (make sure pop up blockers are not enabled)',
              frame_width: 840,
              frame_height: 570,
              authenticator: Auth::DisqusAuthenticator.new('disqus', trusted: true),
              enabled_setting: 'disqus_login_enabled'

