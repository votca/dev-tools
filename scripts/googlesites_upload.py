#!/usr/bin/env python
# -*- coding: iso-8859-1 -*-
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
  site_domain = 'votca.org'
  
  from optparse import OptionParser
  usage = "usage: %prog [options] arg"
  parser = OptionParser(usage)
  parser.add_option("-u", "--user", dest="user", help="username for login")
  parser.add_option("-p", "--passwd", dest="password", help="password for login")
  parser.add_option("-s", "--site", dest="site", help="site to upload [default='main']")
  parser.add_option("-d", "--dir", dest="directory", help="path to site")
  parser.add_option("-f", "--file", dest="filename", help="local file to upload to the site")
  parser.add_option("-a", "--attach", dest="attachment", help="add a file as attachment")
  #parser.add_option("-v", "--verbose", action="store_true", dest="verbose", default=True)
  #parser.add_option("-q", "--quiet", action="store_false", dest="verbose")

  (options, args) = parser.parse_args()


  # parse options
  if(options.user == None):
    login_name=raw_input("username: ")
  else:
    login_name=options.user

  if(options.password == None):
    login_password=getpass.getpass("password: ")
  else:
    login_password=options.password

  if(options.site == None):
    site_name = 'main'
  else:
    site_name = options.site

  if(options.directory == None):
    exit("Error: Path to site is missing")
  else:
    page_path = options.directory

  if(options.filename != None):
    filename = options.filename


  # proceed to upload
  debug = False
  ssl = True
    
  # create Sitesclient
  print "Logging in as " + login_name
  
  client = gdata.sites.client.SitesClient(source=SOURCE_APP_NAME, site=site_name, domain=site_domain)
  client.http_client.debug = debug
  client.ssl = ssl

  # login to google sites
  try:
    client.ClientLogin(login_name, login_password, client.source);    
  except gdata.client.BadAuthentication:
    exit('Error: Invalid user credentials given.')
  except gdata.client.Error:
    exit('Error: Login Error')

  # try to update page
  try:
    print "Updating content on site: " + page_path
    # try to fetch site
    uri = '%s?path=%s' % (client.MakeContentFeedUri(),page_path)
    feed = client.GetContentFeed(uri=uri)
    entry = feed.entry[0]
    entry_copy = entry

    # update site content
    if(options.filename != None):
      f = open(filename,'r')
      entry.content = gdata.atom.data.Content(f.read())
      f.close()
      client.Update(entry)
      print "Website updated from file: " + options.filename
    else:
      print "Note: No file given. Website content remains unchanged."

    # update attachment
    if(options.attachment != None):
      ms = gdata.data.MediaSource(file_path=options.attachment, content_type="text/ascii")

      # find attachment
      uri = "%s?kind=%s" % (client.MakeContentFeedUri(), "attachment")
      feed = client.GetContentFeed(uri=uri)
      existing_attachment = None
      for entry in feed.entry:
        if entry.title.text == options.attachment:
          existing_attachment = entry
      
      if existing_attachment is not None:
        existing_attachment.summary.text = options.attachment
        updated = client.Update(existing_attachment, media_source=ms)
        print "New attachment uploaded: " + updated.GetAlternateLink().href
      else:
        # find cabinet
        #uri = "%s?kind=%s" % (client.MakeContentFeedUri(), "filecabinet")
        #feed = client.GetContentFeed(uri=uri)
        #cabinet = None
        #for entry in feed.entry:
        #  if entry.title.text == options.attachment:
        #    cabinet = entry
        cabinet = entry_copy
        if cabinet is None:
          exit("Error: Cabinet does not exist.")
        attachment = client.UploadAttachment(ms, cabinet, title=options.attachment)
        print "Existing attachment has been updated: ", attachment.GetAlternateLink().href      
    #print "pushed update to  " + entry.GetAlternateLink().href
    print "Done."
  except gdata.client.RequestError, error:
    print error
  except KeyboardInterrupt:
    return

if __name__ == '__main__':
  main()
