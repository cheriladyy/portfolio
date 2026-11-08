#declare the base image
FROM nginx:alpine

#set a work directory
WORKDIR /usr/share/nginx/html

#copy files
COPY index.html style.css mediaqueries.css script.js ./
COPY assets ./assets

COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --chmod=755 nginx/40-basic-auth.sh /docker-entrypoint.d/40-basic-auth.sh

ENV APP_ENV=dev

#expose nginx port
EXPOSE 80

#command
CMD [ "nginx", "-g", "daemon off;" ]