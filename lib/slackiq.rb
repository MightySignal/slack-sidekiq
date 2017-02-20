require 'slackiq/version'

require 'net/http'
require 'json'
require 'httparty'

require 'slackiq/time_helper'

require 'active_support' #for Hash#except

module Slackiq
  
  class << self
    # Configure all of the webhook URLs you're going to use
    # @author Jason Lew
    def configure(webhook_urls={}, proxy_opts={})
      raise 'Arguments must be a Hash' unless webhook_urls.class == Hash && proxy_opts.class == Hash
      @@webhook_urls = webhook_urls
      @@proxy_opts = proxy_opts
    end
    
    # Send a notification to Slack with Sidekiq info about the batch
    # @author Jason Lew
    def notify(options={})  
      url = @@webhook_urls[options[:webhook_name]]
      title = options[:title]
      #description = options[:description]
      status = options[:status]
      
      if (bid = options[:bid]) && status.nil?
        raise "Sidekiq::Batch::Status is not defined. Are you sure Sidekiq Pro is set up correctly?" unless defined?(Sidekiq::Batch::Status)
        
        status = Sidekiq::Batch::Status.new(bid)
      end
      
      extra_fields = options.except(:webhook_name, :title, :description, :status)

      fields = []
      
      if status
        created_at = status.created_at
      
        if created_at
          time_now = Time.now
          duration = Slackiq::TimeHelper.elapsed_time_humanized(created_at, time_now)
          time_now_title = (status.complete? ? 'Completed' : 'Now')
        end
      
        total_jobs = status.total
        failures = status.failures
        jobs_run = total_jobs - status.pending

        completion_percentage = (jobs_run/total_jobs.to_f)*100
        failure_percentage = (failures/total_jobs.to_f)*100 if total_jobs && failures

        # round to two decimal places
        decimal_places = 2
        completion_percentage = completion_percentage.round(decimal_places)
        failure_percentage = failure_percentage.round(decimal_places)
        
        description = status.description

        fields += [
                    {
                      'title' => 'Created',
                      'value' => Slackiq::TimeHelper.format(created_at),
                      'short' => true
                    },
                    {
                      'title' => time_now_title,
                      'value' => Slackiq::TimeHelper.format(time_now),
                      'short' => true
                    },
                    {
                      'title' => "Duration",
                      'value' => duration,
                      'short' => true
                    },
                    {
                      'title' => "Total Jobs",
                      'value' => total_jobs,
                      'short' => true
                    },
                    {
                      'title' => "Jobs Run",
                      'value' => jobs_run,
                      'short' => true
                    },
                    {
                      'title' => "Completion %",
                      'value' => "#{completion_percentage}%",
                      'short' => true
                    },
                    {
                      'title' => "Failures",
                      'value' => status.failures,
                      'short' => true
                    },
                    {
                      'title' => "Failure %",
                      'value' => "#{failure_percentage}%",
                      'short' => true
                    },
                  ]
      end
      
      
      
      # add extra fields
      fields += extra_fields.map do |title, value|
        {
          'title' => title,
          'value' => value,
          'short' => false
        }
      end
                
      attachments = 
      [
        {
          'fallback' => title,

          'color' => '#00ff66',

          'title' => title,

          'text' => description,

          'fields' => fields,
        }
    ]
    
      body = {attachments: attachments}.to_json

      HTTParty.post(url, body: body,
                    http_proxyaddr: @@proxy_opts[:url],
                    http_proxyport: @@proxy_opts[:port],
                    http_proxyuser: @@proxy_opts[:user],
                    http_proxypass: @@proxy_opts[:password]
      )
    end

    # Send a notification without Sidekiq batch info
    # @author Jason Lew
    def message(text, options)
      url = @@webhook_urls[options[:webhook_name]]

      body = { 'text' => text }.to_json

      HTTParty.post(url, body: body,
                    http_proxyaddr: @@proxy_opts[:url],
                    http_proxyport: @@proxy_opts[:port],
                    http_proxyuser: @@proxy_opts[:user],
                    http_proxypass: @@proxy_opts[:password]
      )
    end
    
  end
  
end