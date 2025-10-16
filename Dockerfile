FROM nginx

COPY nginx.conf /etc/nginx/conf.d/default.conf
RUN rm /usr/share/nginx/html/*

EXPOSE 8000
