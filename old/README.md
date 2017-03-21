
# CPAN Testers Legacy Backend

This is the backend as it currently is from the CPAN Testers server.
This backend is split up into multiple, smaller parts.

The `crontab` file is the crontab for the "barbie" user and schedules
all the `*.sh` files in this directory. These files execute the scripts
located in the subdirectories in this directory.

For more documentation about the legacy backend, see [the CPAN Testers
Backend Wiki](https://github.com/cpan-testers/cpantesters-backend/wiki).

