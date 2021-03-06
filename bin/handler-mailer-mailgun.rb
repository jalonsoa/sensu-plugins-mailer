#! /usr/bin/env ruby
#  encoding: UTF-8
#   mailer-mailgun.rb
#
# DESCRIPTION:
#   This handler formats alerts as mail and sends them off to a pre-defined recipient
#   using the Rackspace Mailgun service (http://www.rackspace.com/mailgun).
#
# OUTPUT:
#   Delivers email for events.
#
# PLATFORMS:
#   All
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mailgun-ruby
#
# USAGE:
#   In mailer-mailgun.json, set the following values:
#   * mail_from: The from address that will appear in the email
#   * mail_to: The address of the recipent
#   * mg_apikey: The apikey of the Mailgun account
#   * mg_domain: The domain name that you have configured Mailgun to use
#
# LICENSE:
#   Chris Powell powellchristoph@gmail.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-handler'
require 'mailgun'
require 'timeout'

class Mailer < Sensu::Handler
  option :json_config,
         description: 'Config Name',
         short: '-j JsonConfig',
         long: '--json_config JsonConfig',
         required: false,
         default: 'mailer-mailgun'

  def json_config
    @json_config ||= config[:json_config]
  end

  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def handle
    params = {
      mail_to: settings[json_config]['mail_to'],
      mail_from: settings[json_config]['mail_from'],
      mg_apikey: settings[json_config]['mg_apikey'],
      mg_domain: settings[json_config]['mg_domain'],
      subject_prefix: settings[json_config]['subject_prefix']
    }

    body = <<-BODY.gsub(/^ {14}/, '')
            #{@event['check']['output']}
            Host: #{@event['client']['name']}
            Timestamp: #{Time.at(@event['check']['issued'])}
            Address:  #{@event['client']['address']}
            Check Name:  #{@event['check']['name']}
            Command:  #{@event['check']['command']}
            Status:  #{@event['check']['status']}
            Occurrences:  #{@event['occurrences']}
          BODY
    prefix_subject = params[:subject_prefix] + ' ' if params[:subject_prefix]
    subject = "#{prefix_subject}#{action_to_string} - #{short_name}: #{@event['check']['notification']}"

    mg_client = Mailgun::Client.new params[:mg_apikey]

    begin
      Timeout.timeout 10 do
        message_params = {
          from:     params[:mail_from],
          to:       params[:mail_to],
          subject:  subject,
          text:     body
        }

        mg_client.send_message params[:mg_domain], message_params

        puts 'mail -- sent alert for ' + short_name + ' to ' + params[:mail_to]
      end
    rescue Timeout::Error
      puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
    end
  end
end
