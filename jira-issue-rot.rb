#!/usr/bin/env ruby
require 'rubygems'
require 'date'
require 'net/http'
require 'net/smtp'
require 'nokogiri'
require 'json'
gem 'soap4r'
require 'soap/wsdlDriver'

require 'config.rb'

def search_for_rotten_issues
  req = Net::HTTP::Get.new(URI.escape($jira_search_url))

  req.basic_auth($jira_username, $jira_password)
  response = Net::HTTP.new($jira_server, $jira_port).request(req)

  if response.code =~ /20[0-9]{1}/
    issues_xpath = Nokogiri::XML(response.body).xpath('//rss/channel/item')

    if issues_xpath.length == 0
      puts 'No issues to expire found'
      send_email(0, "No issues to expire found")
    end

    rotting_issues = Array.new
    for issue in issues_xpath
      issue_id = issue.xpath('key').text
      puts "#{issue_id} (#{issue.xpath('priority').text}) - #{issue.xpath('summary').text}\nhttp://#{$jira_server}/browse/#{issue_id}\n\n"
      if expire_issue(issue_id)
        rotting_issues.push("#{issue_id} (#{issue.xpath('priority').text}) - #{issue.xpath('summary').text}\nhttp://#{$jira_server}/browse/#{issue_id}\n")
      end
    end

    send_email(rotting_issues.length, rotting_issues.sort.join("\n"))

  else
    puts 'Jira error'
    send_email(-1, "There seems to have been a non-standard Jira response. Is Jira sick?\n\nError code:#{response.code}\nError message:#{response.message}")
  end
end

def send_email(count, message)
  today = Date.today
  from = "jira-issue-rot@#{Socket.gethostname}"
  msg = <<END_OF_MESSAGE
From: Jira Compost <#{from}>
To: Jira Issue Rot Notifcations <#{$email_to}>
Subject: Jira Rot Report #{today.day}/#{today.month}/#{today.year} (Expired:#{count})

#{message}
END_OF_MESSAGE

  Net::SMTP.start($smtp_server) do |smtp|
    smtp.send_message msg, from, $email_to
  end

  puts "\tEmail sent to #{$email_to}"
end

def expire_issue(issue_id)
# Courtesy of https://developer.atlassian.com/display/JIRADEV/Remote+API+%28SOAP%29+Examples
  soap = SOAP::WSDLDriverFactory.new("http://#{$jira_server}:#{$jira_port}#{$jira_soap_url}").create_rpc_driver
  token = soap.login($jira_username, $jira_password)

  begin
    case soap.getIssue(token, issue_id).status
    when '1', '3' # open or in-progress
      soap.progressWorkflowAction(token, issue_id, '2', [{ :id => "resolution", :values => '6' }])
    when '5' # verify
      # First we fail the ticket to make it closable
      soap.progressWorkflowAction(token, issue_id, '3', [{ :id => "resolution", :values => '6' }])
      soap.progressWorkflowAction(token, issue_id, '2', [{ :id => "resolution", :values => '6' }])
    else
      $stderr.puts "!!! expire_issue(#{issue_id}) has an invalid issue state - neither open, in-progress, or verify. Investigate!"
      return false
    end

    return true
  rescue
    $stderr.puts "There was a problem with transitioning issue #{issue_id}. Please investigate/transition manually."
    return false
  end
end

# Start here.
search_for_rotten_issues
