Directory /opt contains Python app with Dockerfile which does the following: 
Pulls ubuntu 18.04 image - Installs Python - Installs Python requirements defined in a requirements.txt file. 
Deploys a python web application that is located under /opt/webapp - The web applicaiton runs on port 5000 - 
Makes sure the web applicaiton starts when a container is run. 
requirements.txt are in the same directory as Dockerfile 
command file contains information on how to: Build a docker image based on the Dockerfile - image is built running interactively in the detached mode.
