#!/bin/bash
# Taken and adapted from:
# https://www.techrepublic.com/article/how-to-run-cleanup-tasks-with-docker-using-these-4-tips/
#
# In order for this docker_clean script to work, it must have the proper permissions. Issue the command:
#
# ```
# chmod 755 ~/docker_clean.sh
# ```
#
# Next place the script in /usr/local/bin.
#
# Whichever user will be cronning the job, must be in the Docker group. To add that user, issue the command:
#
# ```
# sudo usermod -aG docker USER
# ```
#
# Where USER is the actual username.
#
# That user will need to logout and log back in. Now we create the cron job by issuing the command (as the user in question):
#
# ```
# crontab -e
# ```
#
# At the bottom of the crontab file, add the following:
#
# 0 0 * * 1 ~/docker_clean.sh > /dev/null 2>&1
#
# Save and close the crontab file. At this point, every midnight the Docker cleanup task will run and you'll always enjoy a fresh and clean Docker experience.
docker ps -aqf "status=exited" --no-trunc | xargs docker rm
# Remove dangling images
docker rmi $(docker images -q -f dangling=true)
# Remove dangling volumes
docker volume rm $(docker volume ls -qf dangling=true)
