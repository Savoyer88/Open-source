Tasks 5 and 6.

Directory /opt contains Python app with Dockerfile which does the following:
Pulls ubuntu 18.04 image - Installs Python - Installs Python requirements defined in a requirements.txt file. The file should be in the same directory as Dockerfile - Deploys a python web application that is located under /opt/webapp - The web applicaiton runs on port 5000 - Makes sure the web applicaiton starts when a container is run.
requirements.txt are in the same directory as Dockerfile
command file contains information on how to:

Build a docker image based on the Dockerfile written in the previous task.
Provide a command that start the docker container with the image built running interactively in the detached mode.
