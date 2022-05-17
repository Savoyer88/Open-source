# base image
FROM ubuntu:18.04

# Install python 3.7
RUN apt update 

# Install pip
RUN apt install python3-pip -y

# RUN apt-get update -y && \
 #   apt-get install -y python3-pip python-dev 

#creating work directory
WORKDIR /opt/webapp

#installing app dependencies
COPY requirements.txt .
RUN pip3 install -r requirements.txt 
   
#copy the source code
COPY ./webapp ./opt/webapp/

#telling Docker to expose port 5000 to the host
#EXPOSE 5000

#define the command to initiate the container
CMD ["python", "./webapp/app.py"] 
