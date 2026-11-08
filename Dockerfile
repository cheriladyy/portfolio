#declare the base image
FROM nginx:alpine

#set a work directory
WORKDIR /usr/share/nginx/html

#copy files
COPY . .

#expose nginx port
EXPOSE 80

#command
CMD [ "nginx", "-g", "daemon off;" ]