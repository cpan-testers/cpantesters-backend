FROM cpantesters/schema
# Load some modules that will always be required, to cut down on docker
# rebuild time
RUN cpanm -v \
    Beam::Minion \
    Minion \
    Minion::Backend::mysql

# Load last version's modules, to again cut down on rebuild time
COPY ./cpanfile /app/cpanfile
RUN cpanm --installdeps .

COPY ./ /app/
RUN dzil authordeps --missing | cpanm -v --notest
RUN dzil listdeps --missing | cpanm -v --notest
RUN dzil install --install-command "cpanm -v ."

COPY ./etc/docker/backend/my.cnf /root/.cpanstats.cnf
COPY ./etc/container /app/etc/container
RUN mkdir -p ~/var/run/report
ENV BEAM_PATH=/app/etc/container \
    BEAM_MINION='mysql+dsn+dbi:mysql:mysql_read_default_file=~/.cpanstats.cnf;mysql_read_default_group=application' \
    MOJO_PUBSUB_EXPERIMENTAL=1 \
    MOJO_MAX_MESSAGE_SIZE=33554432
CMD [ "beam", "minion", "worker" ]
