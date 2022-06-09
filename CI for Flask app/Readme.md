Flask app, containerized it using Docker, set the CI pipeline for the app. 

docker build -t app:latest /path/to/Dockerfile
docker run -d -p 5000:5000 app
