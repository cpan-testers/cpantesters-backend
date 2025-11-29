FROM cpantesters/schema
# Load some modules that will always be required, to cut down on docker
# rebuild time
RUN --mount=type=cache,target=/root/.cpanm \
  cpanm -v --notest \
    Beam::Minion \
    Minion \
    Minion::Backend::mysql

# Load last version's modules, to again cut down on rebuild time
COPY ./cpanfile /app/cpanfile
RUN --mount=type=cache,target=/root/.cpanm \
  cpanm --installdeps --notest .

COPY ./ /app
RUN --mount=type=cache,target=/root/.cpanm \
  dzil authordeps --missing | cpanm -v --notest && \
  dzil listdeps --missing | cpanm -v --notest && \
  dzil install --install-command "cpanm -v --notest ."

COPY ./etc/container /app/etc/container
RUN mkdir -p ~/var/run/report
ENV BEAM_PATH=/app/etc/container \
    BEAM_MINION=mysql+dsn+dbi:mysql:mysql_read_default_file=/run/secrets/mysql_cnf;mysql_read_default_group=backend \
    MOJO_PUBSUB_EXPERIMENTAL=1 \
    MOJO_MAX_MESSAGE_SIZE=33554432
CMD [ "beam", "minion", "worker" ]
