FROM nginx:1.27-alpine

RUN apk add --no-cache openssl

COPY index.html styles.css app.js config.js /usr/share/nginx/html/
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 80
ENTRYPOINT ["/docker-entrypoint.sh"]
