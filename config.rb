$jira_username = ''
$jira_password = ''
$jira_server = 'jira.company.com'
$jira_port = '8080'

$jira_search_url = '/sr/jira.issueviews:searchrequest-xml/temp/SearchRequest.xml?field=key&field=priority&field=summary&jqlQuery=updated<=-100d AND status!=closed&tempMax=1000'
$jira_soap_url = '/rpc/soap/jirasoapservice-v2?wsdl'
$email_to = 'issuerot@company.com'
$smtp_server = 'localhost'
