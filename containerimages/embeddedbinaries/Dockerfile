FROM debian

RUN apt-get update && \
  apt-get install -y \
  supervisor \
  curl

COPY --from=ollypom/pdig:latest /pdig /vendor/falco/bin/pdig
COPY --from=falcosecurity/falco:0.32.2-slim      /usr/bin/falco         /vendor/falco/bin/falco
COPY --from=falcosecurity/falco:0.32.2-slim      /etc/falco/            /vendor/falco/etc/falco/
COPY ./myscript.sh             /vendor/falco/scripts/myscript.sh
COPY ./supervisord.conf        /vendor/falco/scripts/supervisord.conf

CMD [ "/usr/bin/supervisord", "-c", "/vendor/falco/scripts/supervisord.conf" ]