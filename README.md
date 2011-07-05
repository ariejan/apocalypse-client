# Apocalypse Client

Apocalypse Client is a ruby gem that can be installed on a remote
server.

## Installation

Apocalypse Client currently focusses on Debian/Ubuntu systems only.

There is only one dependency to the operating system, namely the
`sysstat` package. This package is used to gather information about disk
utilisation and performance.

    sudo apt-get install sysstat

Next install the ruby gem.

    sudo gem install apocalypse-client

Now you can create the file `/etc/cron.d/apocalypse` with the following
content:

    * * * * * root PATH=$PATH:/sbin:/usr/sbin /usr/bin/env apocalypse-client report --server SERVER --port PORT --hostid HOSTID > /dev/null

This will send metrics data every minute to your Apocalypse server. If
you require different intervals, refer to `man 5 crontab` for details on
how to schedule reporting.

You need to replace the placeholders with actual data:

 * `SERVER` - The ip or hostname for your Apocalypse server. E.g.
   apocalyse.example.org
 * `PORT` - The port number the Apocalypse server is listening on.
   Default: 80
 * `HOSTID` - An ID identifying this server. You are free to choose
   whatever you want. But be careful not to chose a duplicate hostid,
because it will mess up you statistics. 

## Choosing a proper hostid

Choosing a proper hostid is important, because it can be arbitrarily
chosen. There are several options:

 * Use the format `appname-role-number`. E.g. `ariejannet-db-01` or
   `reddis-memcached-42`.
 * IP Address of the server, this guarantees some level of uniqueness

Note: at this time, there is not convention for picking hostids.
However, the first method is likely to become the convention and will
allow logical grouping of servers by role and application.
