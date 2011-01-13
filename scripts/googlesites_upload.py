#!/usr/bin/python
#
# Copyright 2009 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

SOURCE_APP_NAME = 'votca.org-updater'
__author__ = 'ruehle@votca.org (Victor Ruehle)'

import gdata.sites.client
import gdata.sites.data
import getpass

def main():
  page_path="/tmp"
  site_name = 'main'
  site_domain = 'votca.org'
  
  from optparse import OptionParser
  usage = "usage: %prog [options] arg"
  parser = OptionParser(usage)
  parser.add_option("-u", "--user", dest="user", help="username for login")
  parser.add_option("-p", "--passwd", dest="password", help="password for login")

  #parser.add_option("-v", "--verbose",
  #                   action="store_true", dest="verbose", default=True)
  # parser.add_option("-q", "--quiet",
#                     action="store_false", dest="verbose")

  (options, args) = parser.parse_args()

  if(options.user == None):
    login_name=raw_input("username: ")
  else:
    login_name=options.user

  if(options.password == None):
    login_password=getpass.getpass("password: ")
  else:
    login_password=options.password

  debug = False
  ssl = True
    
  # create Sitesclient
  print "logging in as " + login_name
  
  client = gdata.sites.client.SitesClient(
    source=SOURCE_APP_NAME, site=site_name, domain=site_domain)
  client.http_client.debug = debug
  client.ssl = ssl

  # login to google sites
  try:
    client.ClientLogin(login_name, login_password, client.source);    
  except gdata.client.BadAuthentication:
    exit('Invalid user credentials given.')
  except gdata.client.Error:
    exit('Login Error')

  # try to update page
  try:
    print "updating  " + page_path
    # try to fetch site
    uri = '%s?path=%s' % (client.MakeContentFeedUri(),page_path)
    feed = client.GetContentFeed(uri=uri)
    entry = feed.entry[0]

    # update content
    entry.content = gdata.atom.data.Content("YOUR <b>NEW</b> HTML again")
    client.Update(entry)
    
    print "pushed update to  " + entry.GetAlternateLink().href
  except gdata.client.RequestError, error:
    print error
  except KeyboardInterrupt:
    return

if __name__ == '__main__':
  main()
