# base image
FROM ubuntu:20.04
#define work directory
RUN apt-get update -y && \
    apt-get install -y python3-pip python-dev
COPY ./requirements.txt /app/requirements.txt
WORKDIR /app

RUN pip install -r requirements.txt
COPY . /app
ENTRYPOINT [ "python" ]
# run pip to install the dependencies of the flask app

#define the command to initiate the container
CMD [ "main.py" ] 
